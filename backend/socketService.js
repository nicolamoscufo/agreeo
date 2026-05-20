const socketIo = require('socket.io');

let io = null;

function init(server) {
  io = socketIo(server, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST', 'PATCH', 'DELETE']
    }
  });

  io.on('connection', (socket) => {
    console.log(`[Socket] New connection: ${socket.id}`);

    socket.on('authenticate', (data) => {
      if (data && data.userId) {
        const userId = data.userId;
        console.log(`[Socket] User authenticated: ${userId} on socket ${socket.id}`);
        socket.join(`user_${userId}`);
      } else {
        console.log(`[Socket] Authentication failed: missing userId in data`);
      }
    });

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
};
