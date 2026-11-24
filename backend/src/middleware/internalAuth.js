/**
 * SentinelX - Internal Service Authentication & Provenance Middleware
 * 
 * Enforces cryptographic service identity, HMAC signature verification,
 * request binding (HTTP method, request path, request-body digest),
 * timestamp tolerance window, and replay protection.
 * 
 * Rules:
 * 1. Remove hardcoded production fallback secrets.
 * 2. Fail closed when production credentials are absent or insecure (< 32 chars).
 * 3. Never trust plain marker headers (e.g. x-sentinelx-internal-source).
 * 4. Never derive req.isServerVerifiedAudio from client input.
 * 5. Replay attack protection with sliding nonce cache.
 * 6. Timestamp window check (+/- 60 seconds) to prevent stale/future requests.
 * 7. Cryptographic binding to HTTP method, path, and request-body digest (v2 protocol).
 * 8. Constant-time signature comparison via crypto.timingSafeEqual.
 */

const crypto = require('crypto');

const INSECURE_DEFAULT_SERVICE_KEYS = [
  'sentinelx_internal_audio_token_secure',
  'sentinelx_internal_default_secret_key',
  'sentinelx_default_internal_service_key',
  'sentinelx_internal_key_development_only',
  'change_this_to_a_secure_service_key_in_production',
  'sentinelx_internal_dev_test_key_32_chars_min',
  'internal_service_key',
  'default_internal_key',
  'secret',
  'changeme',
  'password',
  'test_secret',
];

// Sliding memory cache for replay attack prevention (nonce -> expiresAt)
const globalNonceCache = new Map();

// Periodic cleanup of expired nonces (every 60s)
const cleanupTimer = setInterval(() => {
  const now = Date.now();
  for (const [nonce, expiresAt] of globalNonceCache.entries()) {
    if (now > expiresAt) {
      globalNonceCache.delete(nonce);
    }
  }
}, 60000);
if (cleanupTimer.unref) cleanupTimer.unref();

/**
 * Canonical JSON serialization with deterministically sorted keys.
 */
function canonicalizeObject(obj) {
  if (obj === null || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) return obj.map(canonicalizeObject);
  const sorted = {};
  for (const key of Object.keys(obj).sort()) {
    sorted[key] = canonicalizeObject(obj[key]);
  }
  return sorted;
}

/**
 * Compute SHA-256 digest of request body.
 * Empty body / null / undefined / empty object returns sha256("").
 */
function computeBodyDigest(body) {
  if (!body || (typeof body === 'object' && Object.keys(body).length === 0)) {
    return crypto.createHash('sha256').update('').digest('hex');
  }
  if (Buffer.isBuffer(body) || typeof body === 'string') {
    return crypto.createHash('sha256').update(body).digest('hex');
  }
  return crypto.createHash('sha256').update(JSON.stringify(canonicalizeObject(body))).digest('hex');
}

/**
 * Normalize URL path (strip query params, trailing slashes).
 */
function normalizePath(rawPath) {
  if (!rawPath || typeof rawPath !== 'string') return '/';
  const withoutQuery = rawPath.split('?')[0];
  const normalized = withoutQuery.replace(/\/+$/, '') || '/';
  return normalized;
}

/**
 * Validate INTERNAL_SERVICE_KEY configuration.
 * In production: fails closed if missing, < 32 chars, or in INSECURE_DEFAULT_SERVICE_KEYS.
 */
const validateInternalServiceConfig = (envKey = null, nodeEnv = null) => {
  const isProd = (nodeEnv || process.env.NODE_ENV) === 'production';
  const key = envKey !== null ? envKey : process.env.INTERNAL_SERVICE_KEY;

  if (isProd) {
    if (!key || key.trim().length < 32) {
      throw new Error('[Internal Auth Fatal] Production environment requires INTERNAL_SERVICE_KEY with minimum 32 characters.');
    }
    if (INSECURE_DEFAULT_SERVICE_KEYS.includes(key.trim())) {
      throw new Error('[Internal Auth Fatal] Insecure default INTERNAL_SERVICE_KEY detected in production environment.');
    }
  } else {
    if (!key || INSECURE_DEFAULT_SERVICE_KEYS.includes(key)) {
      if (process.env.NODE_ENV !== 'test') {
        console.warn('[Internal Auth Warning] INTERNAL_SERVICE_KEY is unset or using a default key in non-production environment.');
      }
    }
  }
};

try {
  validateInternalServiceConfig();
} catch (err) {
  if (process.env.NODE_ENV === 'production') {
    throw err;
  }
}

/**
 * Generate an authenticated internal service token.
 * 
 * Supports:
 * - Object syntax: generateInternalServiceToken({ serviceId, method, path, body, customKey, timestamp, nonce })
 * - Positional syntax: generateInternalServiceToken(serviceId, customKey, reqOpts)
 * 
 * If method, path, or body is provided: produces v2 token bound to request.
 * Format v2: v2.<serviceId>.<timestamp>.<nonce>.<hmacSignature>
 * Signature is computed over `${method}:${path}:${serviceId}:${timestamp}:${nonce}:${bodyDigest}`.
 * 
 * If no request context is provided (legacy test mode): produces v1 token.
 * Format v1: v1.<serviceId>.<timestamp>.<nonce>.<hmacSignature>
 * Signature is computed over `${serviceId}:${timestamp}:${nonce}`.
 */
const generateInternalServiceToken = (serviceIdOrOpts = 'sentinelx-internal', customKey = null, reqOpts = null) => {
  let serviceId = 'sentinelx-internal';
  let method = null;
  let path = null;
  let body = undefined;
  let key = customKey;
  let timestamp = Date.now();
  let nonce = crypto.randomUUID();

  if (typeof serviceIdOrOpts === 'object' && serviceIdOrOpts !== null) {
    serviceId = serviceIdOrOpts.serviceId || 'sentinelx-internal';
    method = serviceIdOrOpts.method || null;
    path = serviceIdOrOpts.path || null;
    body = serviceIdOrOpts.body;
    key = serviceIdOrOpts.customKey || key;
    if (serviceIdOrOpts.timestamp) timestamp = serviceIdOrOpts.timestamp;
    if (serviceIdOrOpts.nonce) nonce = serviceIdOrOpts.nonce;
  } else if (typeof serviceIdOrOpts === 'string') {
    serviceId = serviceIdOrOpts;
    if (reqOpts && typeof reqOpts === 'object') {
      method = reqOpts.method || null;
      path = reqOpts.path || null;
      body = reqOpts.body;
      if (reqOpts.timestamp) timestamp = reqOpts.timestamp;
      if (reqOpts.nonce) nonce = reqOpts.nonce;
    }
  }

  const activeKey = key || process.env.INTERNAL_SERVICE_KEY || 'sentinelx_internal_dev_test_key_32_chars_min';

  if (method || path || body !== undefined) {
    // Generate v2 token bound to request
    const normMethod = (method || 'POST').toUpperCase();
    const normPath = normalizePath(path || '/api/logs');
    const bodyDigest = computeBodyDigest(body);
    const payload = `${normMethod}:${normPath}:${serviceId}:${timestamp}:${nonce}:${bodyDigest}`;
    const signature = crypto.createHmac('sha256', activeKey).update(payload).digest('hex');
    return `v2.${serviceId}.${timestamp}.${nonce}.${signature}`;
  }

  // Generate v1 token
  const payload = `${serviceId}:${timestamp}:${nonce}`;
  const signature = crypto.createHmac('sha256', activeKey).update(payload).digest('hex');
  return `v1.${serviceId}.${timestamp}.${nonce}.${signature}`;
};

/**
 * Verify an incoming internal service token with timestamp window, request binding, and replay protection.
 * @param {string} token - The raw token string (v1.* or v2.*)
 * @param {object|string|null} reqOrExpected - Request object / context OR expectedServiceId string
 * @param {string|null} expectedServiceId - Expected service identifier (optional constraint)
 * @param {string|null} customKey - Override key (used in tests)
 * @param {Map|null} customNonceCache - Override nonce cache (used in multi-instance tests)
 * @returns {{ valid: boolean, error?: string, serviceId?: string, timestamp?: number, version?: string, boundMethod?: string, boundPath?: string, boundBodyDigest?: string }}
 */
const verifyInternalServiceToken = (
  token,
  reqOrExpected = null,
  expectedServiceIdOrKey = null,
  customKey = null,
  customNonceCache = null
) => {
  let req = null;
  let targetServiceId = null;
  let activeKey = customKey;
  let cache = customNonceCache || globalNonceCache;

  // Options object pattern: verifyInternalServiceToken(token, { req, expectedServiceId, customKey, nonceCache })
  if (reqOrExpected && typeof reqOrExpected === 'object' && ('req' in reqOrExpected || 'expectedServiceId' in reqOrExpected || 'customKey' in reqOrExpected)) {
    req = reqOrExpected.req || null;
    targetServiceId = reqOrExpected.expectedServiceId || null;
    activeKey = reqOrExpected.customKey || activeKey;
    if (reqOrExpected.nonceCache) cache = reqOrExpected.nonceCache;
  } else if (reqOrExpected && typeof reqOrExpected === 'object' && ('method' in reqOrExpected || 'path' in reqOrExpected || 'headers' in reqOrExpected || 'originalUrl' in reqOrExpected)) {
    // 2nd arg is Express req object
    req = reqOrExpected;
    targetServiceId = expectedServiceIdOrKey;
  } else if (typeof reqOrExpected === 'string') {
    // 2nd arg is expectedServiceId
    targetServiceId = reqOrExpected;
    activeKey = expectedServiceIdOrKey || activeKey;
  } else if (reqOrExpected === null && expectedServiceIdOrKey) {
    // verifyInternalServiceToken(token, null, key) -> legacy 3-arg call where 3rd arg was key
    if (expectedServiceIdOrKey.length >= 32 || INSECURE_DEFAULT_SERVICE_KEYS.includes(expectedServiceIdOrKey)) {
      activeKey = expectedServiceIdOrKey;
    } else {
      targetServiceId = expectedServiceIdOrKey;
    }
  }

  const isProd = process.env.NODE_ENV === 'production';
  const key = activeKey || process.env.INTERNAL_SERVICE_KEY || (!isProd ? 'sentinelx_internal_dev_test_key_32_chars_min' : null);

  if (!key) {
    return { valid: false, error: 'Internal service key not configured on server.' };
  }

  if (isProd) {
    if (key.length < 32 || INSECURE_DEFAULT_SERVICE_KEYS.includes(key)) {
      return { valid: false, error: 'Production environment requires strong INTERNAL_SERVICE_KEY.' };
    }
  }

  if (!token || typeof token !== 'string') {
    return { valid: false, error: 'Missing or malformed internal service token.' };
  }

  const parts = token.trim().split('.');
  if (parts.length !== 5) {
    return { valid: false, error: 'Invalid internal service token format.' };
  }

  const [version, serviceId, timestampStr, nonce, signature] = parts;
  if (version !== 'v1' && version !== 'v2') {
    return { valid: false, error: `Unsupported internal service token protocol version: "${version}".` };
  }

  // Enforce Protocol v2 in production: Protocol v1 is strictly rejected in production environments
  if (isProd && version !== 'v2') {
    return {
      valid: false,
      error: 'Production environment strictly requires Protocol v2 request-bound tokens (Protocol v1 rejected).',
    };
  }

  const timestamp = parseInt(timestampStr, 10);
  if (isNaN(timestamp)) {
    return { valid: false, error: 'Invalid timestamp in internal service token.' };
  }

  if (targetServiceId && serviceId !== targetServiceId) {
    return { valid: false, error: `Service ID mismatch: expected "${targetServiceId}", got "${serviceId}".` };
  }

  // 1. Timestamp Freshness Check (+/- 60,000 ms)
  const now = Date.now();
  const MAX_CLOCK_SKEW_MS = 60 * 1000;
  if (Math.abs(now - timestamp) > MAX_CLOCK_SKEW_MS) {
    return { valid: false, error: 'Internal service token expired or clock skew exceeded 60 seconds.' };
  }

  // 2. Replay Protection: Check if nonce was already consumed
  if (cache.has(nonce)) {
    return { valid: false, error: 'Replay attack detected: internal service token nonce has already been used.' };
  }

  // 3. Cryptographic Signature Verification
  let expectedSig;
  let boundMethod = null;
  let boundPath = null;
  let boundBodyDigest = null;

  if (version === 'v2') {
    boundMethod = ((req && req.method) || 'POST').toUpperCase();
    boundPath = normalizePath((req && (req.originalUrl || req.path)) || '/');
    boundBodyDigest = computeBodyDigest(req && req.body);
    const payload = `${boundMethod}:${boundPath}:${serviceId}:${timestamp}:${nonce}:${boundBodyDigest}`;
    expectedSig = crypto.createHmac('sha256', key).update(payload).digest('hex');
  } else {
    // v1 legacy token
    const payload = `${serviceId}:${timestamp}:${nonce}`;
    expectedSig = crypto.createHmac('sha256', key).update(payload).digest('hex');
  }

  const sigBuffer = Buffer.from(signature, 'hex');
  const expectedBuffer = Buffer.from(expectedSig, 'hex');

  if (sigBuffer.length !== expectedBuffer.length || !crypto.timingSafeEqual(sigBuffer, expectedBuffer)) {
    return { valid: false, error: 'Invalid cryptographic signature in internal service token.' };
  }

  // Record nonce in replay cache with TTL equal to the remaining window
  cache.set(nonce, now + MAX_CLOCK_SKEW_MS);

  return {
    valid: true,
    serviceId,
    timestamp,
    version,
    boundMethod,
    boundPath,
    boundBodyDigest,
  };
};

/**
 * Express Middleware: Authenticates internal service requests.
 * Attaches verified, frozen service identity to req.internalService.
 * Explicitly rejects plain marker headers.
 */
const internalServiceAuthMiddleware = (req, res, next) => {
  // Clear any client-injected internal flags immediately
  req.isServerVerifiedAudio = false;
  req.internalService = null;

  const authHeader = req.headers && (req.headers['x-sentinelx-service-auth'] || req.headers['x-sentinelx-internal-token']);

  // Plain marker headers (e.g. x-sentinelx-internal-source) are explicitly rejected as authentication
  if (!authHeader) {
    return next();
  }

  const verification = verifyInternalServiceToken(authHeader, req);
  if (verification.valid) {
    req.internalService = Object.freeze({
      authenticated: true,
      serviceId: verification.serviceId,
      timestamp: verification.timestamp,
      version: verification.version,
      boundMethod: verification.boundMethod || req.method,
      boundPath: verification.boundPath || req.path,
    });
  }

  next();
};

module.exports = {
  validateInternalServiceConfig,
  generateInternalServiceToken,
  verifyInternalServiceToken,
  internalServiceAuthMiddleware,
  computeBodyDigest,
  normalizePath,
  INSECURE_DEFAULT_SERVICE_KEYS,
  _nonceCache: globalNonceCache,
};
