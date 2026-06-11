const socketIo = require('socket.io');
const { verify } = require('./jwtUtils');

let io = null;

function extractToken(socket) {
  const authToken = socket.handshake.auth && socket.handshake.auth.token;
  if (authToken) {
    return authToken;
  }

  const header = socket.handshake.headers && socket.handshake.headers.authorization;
  if (header && header.startsWith('Bearer ')) {
    return header.substring(7);
  }

  return null;
}

function authMiddleware(socket, next) {
  const token = extractToken(socket);
  const payload = token ? verify(token) : null;

  if (!payload) {
    return next(new Error('unauthorized'));
  }

  socket.data.userId = payload.uid || payload.sub;
  next();
}

function init(server, { corsOrigins = [] } = {}) {
  io = socketIo(server, {
    cors: {
      origin: corsOrigins.length > 0 ? corsOrigins : true,
      methods: ['GET', 'POST', 'PATCH', 'DELETE'],
    },
  });

  io.use(authMiddleware);

  io.on('connection', (socket) => {
    console.log(`[Socket] New connection: ${socket.id} (user ${socket.data.userId})`);
    socket.join(`user_${socket.data.userId}`);

    // Legacy no-op: older clients emitted `authenticate` with a raw userId.
    // The room is now derived from the verified JWT in the handshake.
    socket.on('authenticate', () => {});

    socket.on('disconnect', () => {
      console.log(`[Socket] Disconnected: ${socket.id}`);
    });
  });

  return io;
}

function getIo() {
  return io;
}

function emitToUser(userId, event, data) {
  if (io) {
    console.log(`[Socket] Emitting ${event} to user_${userId}`);
    io.to(`user_${userId}`).emit(event, data);
  } else {
    console.warn(`[Socket] Cannot emit: io is not initialized`);
  }
}

function emitToUsers(userIds, event, data) {
  if (io) {
    userIds.forEach((userId) => {
      console.log(`[Socket] Emitting ${event} to user_${userId}`);
      io.to(`user_${userId}`).emit(event, data);
    });
  } else {
    console.warn(`[Socket] Cannot emit: io is not initialized`);
  }
}

module.exports = {
  init,
  getIo,
  emitToUser,
  emitToUsers,
  authMiddleware,
};
