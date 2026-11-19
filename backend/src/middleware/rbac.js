/**
 * SentinelX - Role-Based Access Control (RBAC) Middleware
 *
 * Role Hierarchy:
 *   admin    → full access (all routes)
 *   analyst  → read + ML detect + acknowledge logs
 *   user     → read-only (own data + dashboard)
 *
 * Usage: router.get('/route', authenticate, requireRole('admin', 'analyst'), handler)
 */

/**
 * Role permission levels (higher = more access).
 */
const ROLE_LEVELS = {
  user: 1,
  analyst: 2,
  police: 2,
  admin: 3,
};

/**
 * requireRole(...allowedRoles) — Middleware factory.
 * Pass one or more roles that are permitted to access the route.
 */
const requireRole = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required before role check.',
      });
    }

    const userRole = req.user.role;

    if (!allowedRoles.includes(userRole)) {
      return res.status(403).json({
        success: false,
        error: `Access denied. Required roles: [${allowedRoles.join(', ')}]. Your role: ${userRole}.`,
      });
    }

    next();
  };
};

/**
 * requireMinRole(minRole) — Middleware factory.
 * Permits the given role AND any role with higher privilege level.
 */
const requireMinRole = (minRole) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required before role check.',
      });
    }

    const userLevel = ROLE_LEVELS[req.user.role] || 0;
    const requiredLevel = ROLE_LEVELS[minRole] || 999;

    if (userLevel < requiredLevel) {
      return res.status(403).json({
        success: false,
        error: `Access denied. Minimum required role: ${minRole}.`,
      });
    }

    next();
  };
};

module.exports = { requireRole, requireMinRole, ROLE_LEVELS };
