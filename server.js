const createError = require('http-errors');
const express = require('express');
const path = require('path');
const cookieParser = require('cookie-parser');
const logger = require('morgan');
const cors = require('cors');
const fs = require('fs');
const axios = require('axios');
const os = require('os');
const admin = require('firebase-admin');

require('./index'); // خليه فقط لو ما بيوقفش السيرفر (لو فيه مشاكل شيله)

const authMiddleware = require('./helpers/auth_middleware');

const app = express();

// ===== HTTP + Socket Server =====
const server = require('http').createServer(app);

const io = require('socket.io')(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

const PORT = process.env.PORT || 3001;

let user_socket_connect_list = [];

// ===== View Engine =====
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'ejs');

// ===== Middlewares =====
app.use(logger('dev'));
app.use(express.json({ limit: '100mb' }));
app.use(express.urlencoded({ extended: true, limit: '100mb' }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));

app.use(cors({
  origin: "*"
}));

// 📡 مراقب التتبع الحي: سيطبع الموقع ومعرف السائق في الـ Terminal فور وصول البيانات
app.post('/api/driver-location/:id?', (req, res, next) => {
  if (req.method === 'POST') {
    console.log(`\n🚍 [Tracking Update] Driver: ${req.params.id || 'Unknown'}`);
    console.log(`📍 Location: ${req.body.latitude}, ${req.body.longitude} | Speed: ${req.body.speed_mps} m/s | Accuracy: ${req.body.accuracy}m`);
  }
  next();
});

// 🗺️ بروكسي الخرائط لتجاوز قيود الـ API Key في الموبايل ولحل مشكلة REQUEST_DENIED
app.get('/api/proxy/directions', async (req, res) => {
  try {
    const params = new URLSearchParams(req.query);
    // إضافة المفتاح تلقائياً من السيرفر للأمان
    if (!params.has('key')) {
      params.append('key', 'AIzaSyAApGehTUv-AjNJO5ByNgBSKdHP25cVdPU');
    }
    const googleUrl = `https://maps.googleapis.com/maps/api/directions/json?${params.toString()}`;
    const response = await axios.get(googleUrl);
    res.json(response.data);
  } catch (error) {
    console.error('Proxy Error:', error.message);
    res.status(500).json({ status: 'PROXY_ERROR', message: error.message });
  }
});

//  الحل السريع (اختبار)
app.get('/api/driver-location/:id?', async (req, res) => {
  if (!req.params.id) {
    return res.status(400).json({ success: false, error: "Driver ID is required" });
  }

  try {
    const doc = await admin.firestore().collection('active_cars').doc(req.params.id).get();
    if (!doc.exists) {
      return res.json({ id: req.params.id, lat: 30.1, lng: 31.3, note: "Dummy data (Not found in DB)" });
    }
    const data = doc.data();
    res.json({ id: req.params.id, lat: data.lat, lng: data.long, degree: data.degree });
  } catch (error) {
    console.error("Error fetching driver location:", error);
    res.status(500).json({ success: false, error: "Internal Server Error" });
  }
});

// حماية API
app.use('/api', (req, res, next) => {
  // 🔓 السماح لطلبات تتبع الحافلات والخرائط بدون مصادقة للمعاينة الحية
  if (req.path.includes('driver-location') || req.path.includes('proxy/directions')) {
    return next();
  }
  authMiddleware(req, res, next);
});

// ===== Load Controllers =====
fs.readdirSync('./controllers').forEach((file) => {
  if (file.endsWith('.js')) {
    const route = require('./controllers/' + file);
    route.controller(app, io, user_socket_connect_list);
  }
});

// ===== Health Check =====
app.get('/', (req, res) => {
  res.send("🚀 Server is running successfully");
});

// ===== 404 =====
app.use((req, res, next) => {
  next(createError(404));
});

// ===== Error Handler =====
app.use((err, req, res, next) => {
  console.error("❌ Error:", err);

  res.status(err.status || 500).json({
    message: err.message,
    error: req.app.get('env') === 'development' ? err : {}
  });
});

// ===== START SERVER =====
server.on('error', (e) => {
  if (e.code === 'EADDRINUSE') {
    console.error(`❌ Port ${PORT} is already in use`);
  } else {
    console.error("❌ Server error:", e);
  }
  process.exit(1);
});

server.listen(PORT, "0.0.0.0", () => {
  const networkInterfaces = os.networkInterfaces();
  let localIp = 'localhost';

  Object.keys(networkInterfaces).forEach((interfaceName) => {
    networkInterfaces[interfaceName].forEach((iface) => {
      if (iface.family === 'IPv4' && !iface.internal) {
        localIp = iface.address;
      }
    });
  });

  console.log(`🚀 Server running on http://localhost:${PORT}`);
  console.log(`📱 Connect mobile app to: http://${localIp}:${PORT}`);
});