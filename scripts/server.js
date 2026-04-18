const express = require('express');
const bodyParser = require('body-parser');
const {
    sendGeneralUpdate,
    sendBusArrival,
    sendTrafficAlert
} = require('./send_notification');

const app = express();
const authMiddleware = require('../helpers/auth_middleware');
const PORT = process.env.PORT || 3005;

app.use(bodyParser.json());
app.use('/api', authMiddleware); // Protect all /api endpoints

// رابط لاختبار السيرفر
app.get('/', (req, res) => {
    res.send('سيرفر إشعارات إنجاز ٧ يعمل بنجاح! 🚀');
});

// رابط لإرسال تحديث عام
app.post('/api/notify/general', async (req, res) => {
    try {
        await sendGeneralUpdate();
        res.status(200).json({ success: true, message: 'تم إرسال التحديث العام' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// رابط لإرسال وصول حافلة
app.post('/api/notify/bus-arrival', async (req, res) => {
    const { lineNumber, stopName } = req.body;
    if (!lineNumber || !stopName) {
        return res.status(400).json({ error: 'يرجى إرسال رقم الخط واسم المحطة' });
    }

    try {
        await sendBusArrival(lineNumber, stopName);
        res.status(200).json({ success: true, message: `تم إرسال إشعار وصول الخط ${lineNumber}` });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

const server = app.listen(PORT, () => {
    console.log(`------------------------------------------`);
    console.log(`🚀 السيرفر شغال على الرابط: http://localhost:${PORT}`);
    console.log(`------------------------------------------`);
    console.log(`Endpoints المتاحة:`);
    console.log(`1. POST /api/notify/general`);
    console.log(`2. POST /api/notify/bus-arrival (Body: { "lineNumber": "105", "stopName": "رمسيس" \})`);
}).on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
        console.error(`❌ الخطأ: المنفذ ${PORT} مشغول حالياً. جرب تغيير المنفذ في كود server.js`);
    }
});