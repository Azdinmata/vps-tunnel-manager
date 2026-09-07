const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const path = require('path');
const QRCode = require('qrcode');

// Import Utility & Service Modules
const { getArchitecture } = require('./src/utils/arch.detector');
const TelemetryService = require('./src/services/telemetry.service');
const UserService = require('./src/services/user.service');
const { requireAuth, isValidToken } = require('./src/utils/auth');

// Import Route Handlers
const telemetryRoutes = require('./src/routes/telemetry.routes');
const usersRoutes = require('./src/routes/users.routes');
const servicesRoutes = require('./src/routes/services.routes');
const authRoutes = require('./src/routes/auth.routes');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: { origin: "*", methods: ["GET", "POST"] }
});

app.set('io', io);
app.use(cors());
app.use(express.json());

// Serve Static Frontend Assets from /public or root
app.use(express.static(path.join(__dirname, 'public')));
app.use(express.static(__dirname));

// Register Modular REST Routes
app.use('/api/auth', authRoutes);
app.use('/api', requireAuth); // Protect all other /api endpoints behind admin token
app.use('/api/telemetry', telemetryRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/service', servicesRoutes);

// Protocol Config Endpoint
let protocolConfig = require('./config/default_protocols.json');
app.get('/api/protocols/config', (req, res) => res.json(protocolConfig));
app.post('/api/protocols/config', (req, res) => {
  protocolConfig = { ...protocolConfig, ...req.body };
  io.emit('protocol_config', protocolConfig);
  res.json({ success: true, config: protocolConfig });
});

// QR Code Generator Endpoint
app.get('/api/qrcode', async (req, res) => {
  const text = req.query.text || '';
  try {
    const qrDataUrl = await QRCode.toDataURL(text);
    res.json({ success: true, qrcode: qrDataUrl });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Socket.io Real-Time Telemetry & Sync (requires valid admin token)
io.use((socket, next) => {
  const token = socket.handshake.auth && socket.handshake.auth.token;
  if (isValidToken(token)) return next();
  next(new Error('unauthorized'));
});

io.on('connection', (socket) => {
  console.log('Client connected to VPS Telemetry Monitor:', socket.id);
  
  socket.emit('telemetry', TelemetryService.getMetrics(UserService.getAllUsers().length));
  socket.emit('users_list', UserService.getAllUsers());
  socket.emit('protocol_config', protocolConfig);

  const interval = setInterval(() => {
    socket.emit('telemetry', TelemetryService.getMetrics(UserService.getAllUsers().length));
  }, 2000);

  socket.on('disconnect', () => clearInterval(interval));
});

// Start Server
const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`=======================================================`);
  console.log(`🚀 Ultra VPS SSH & Multi-Protocol Tunnel Manager`);
  console.log(`🌐 Server running on http://0.0.0.0:${PORT}`);
  console.log(`💻 Architecture Detected: ${getArchitecture()}`);
  console.log(`=======================================================`);
});
