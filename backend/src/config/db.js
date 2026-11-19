/**
 * SentinelX - MongoDB Connection
 * Uses Mongoose with connection retry and graceful shutdown.
 */

const mongoose = require('mongoose');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/sentinelx';

let isConnected = false;

const connectDB = async () => {
  const options = {
    serverSelectionTimeoutMS: 3000,
    socketTimeoutMS: 45000,
  };

  try {
    const conn = await mongoose.connect(MONGODB_URI, options);
    isConnected = true;
    console.log(`[DB] MongoDB connected: ${conn.connection.host}`);
  } catch (err) {
    isConnected = false;
    console.warn(`[DB] Notice: MongoDB connection failed (${err.message}). Ensure mongod is running on ${MONGODB_URI}`);
    console.warn('[DB] App will continue in offline/mock DB mode while retrying in background.');
    // Schedule background retry
    setTimeout(connectDB, 10000);
  }
};

// Graceful shutdown
process.on('SIGINT', async () => {
  if (isConnected) {
    await mongoose.connection.close();
    console.log('[DB] MongoDB connection closed on app termination');
  }
  process.exit(0);
});

module.exports = connectDB;
