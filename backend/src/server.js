/**
 * SentinelX - HTTP Server Entry Point
 * Loads env, connects DB, and starts the Express server.
 */

require('dotenv').config();
const connectDB = require('./config/db');
const app = require('./app');
const User = require('./models/User');

const PORT = process.env.PORT || 3000;

const seedDefaultUsers = async () => {
  try {
    const seeds = [
      { name: 'Control Room Admin', email: 'admin@sentinelx.local', role: 'admin' },
      { name: 'Officer Vance (Unit 104)', email: 'police@sentinelx.local', role: 'police' },
      { name: 'Threat Analyst', email: 'analyst@sentinelx.local', role: 'analyst' },
      { name: 'Surveillance Operator', email: 'user@sentinelx.local', role: 'user' },
    ];

    for (const seed of seeds) {
      const exists = await User.findOne({ email: seed.email });
      if (!exists) {
        await User.create({
          ...seed,
          password: 'ChangeMe!2024',
        });
        console.log(`[Seed] Created default user: ${seed.email} (${seed.role})`);
      }
    }
  } catch (err) {
    console.warn(`[Seed] Seed users notice: ${err.message}`);
  }
};

const startServer = async () => {
  await connectDB();
  await seedDefaultUsers();

  const server = app.listen(PORT, () => {
    console.log(`
╔══════════════════════════════════════════════════╗
║          SentinelX Backend API v1.0.0            ║
╠══════════════════════════════════════════════════╣
║  Mode:     ${(process.env.NODE_ENV || 'development').padEnd(39)}║
║  Port:     ${String(PORT).padEnd(39)}║
║  DB:       MongoDB (Mongoose)                    ║
║  Auth:     JWT + Refresh Tokens                  ║
║  RBAC:     admin | analyst | police | user       ║
╚══════════════════════════════════════════════════╝
    `);
  });

  // Graceful shutdown on SIGTERM (Docker / systemd)
  process.on('SIGTERM', () => {
    console.log('[Server] SIGTERM received. Shutting down gracefully...');
    server.close(() => {
      console.log('[Server] HTTP server closed.');
      process.exit(0);
    });
  });
};

startServer().catch((err) => {
  console.error('[Server] Fatal startup error:', err);
  process.exit(1);
});
