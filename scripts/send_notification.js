const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

/*
تعليمات الاستخدام المحدثة (Firebase Admin SDK):
1. استبدل PROJECT_ID بمعرف مشروعك
2. حمل ملف Service Account JSON من Firebase Console
3. ضع الملف في نفس مجلد السكريبت باسم firebase-service-account.json
4. شغل السكريبت بـ: node send_notification.js
*/

const SERVICE_ACCOUNT_FILE = path.join(__dirname, '../serviceAccountKey.json');

// التأكد من وجود ملف المفاتيح
if (!fs.existsSync(SERVICE_ACCOUNT_FILE)) {
  console.error(
    `❌ خطأ: ملف المفاتيح غير موجود في: ${SERVICE_ACCOUNT_FILE}\n` +
    `يرجى تحميله من Firebase Console ووضعه في المجلد الصحيح.`
  );
  process.exit(1);
}

// قراءة البيانات من ملف حساب الخدمة
const serviceAccount = JSON.parse(fs.readFileSync(SERVICE_ACCOUNT_FILE, 'utf8'));

// تهيئة Firebase Admin SDK
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: `https://${serviceAccount.project_id}.firebaseio.com`
  });
}

/**
 * دالة إرسال إشعار باستخدام Firebase Admin SDK
 * @param {Object} message - كائن الرسالة المتوافق مع FCM
 */
async function sendNotification(message) {
  try {
    // Admin SDK يتعامل مع التوكنات والتشفير تلقائياً
    const response = await admin.messaging().send(message);
    console.log('✅ FCM Success Message ID:', response);
    return response;
  } catch (error) {
    console.error('❌ FCM Error:', error.message);
    if (error.code === 'messaging/invalid-registration-token' ||
      error.code === 'messaging/registration-token-not-registered') {
      console.error('التحذير: توكن الجهاز غير صالح حالياً.');
    }
    throw error;
  }
}

// أمثلة لإرسال إشعارات مختلفة

// 1. إشعار عام للتحديثات
async function sendGeneralUpdate() {
  const message = {
    topic: 'general_updates',
    notification: {
      title: 'تحديث جديد!',
      body: 'تم تحديث دليل الحافلات بمعلومات جديدة'
    },
    data: {
      type: 'general_update',
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'line_status',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK'
      }
    }
  };
  await sendNotification(message);
}

// 2. إشعار وصول حافلة
async function sendBusArrival(lineNumber, stopName) {
  const message = {
    topic: 'bus_updates',
    notification: {
      title: 'الحافلة وصلت!',
      body: `وصلت الحافلة رقم ${lineNumber} إلى محطة ${stopName}`
    },
    data: {
      type: 'bus_arrival',
      line: lineNumber.toString(),
      stop: stopName,
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    android: {
      notification: {
        channelId: 'bus_arrival'
      }
    }
  };
  await sendNotification(message);
}

// 3. إشعار زحمة مرورية
async function sendTrafficAlert(description) {
  const message = {
    topic: 'bus_updates',
    notification: {
      title: 'تحذير زحمة',
      body: description
    },
    data: {
      type: 'traffic',
      description: description,
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    android: {
      notification: {
        channelId: 'traffic_alert'
      }
    }
  };
  await sendNotification(message);
}

// 4. إشعار عرض خاص
async function sendOfferNotification(offerText) {
  const message = {
    topic: 'general_updates',
    notification: {
      title: 'عرض خاص!',
      body: offerText
    },
    data: {
      type: 'offer',
      offer: offerText,
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    android: {
      notification: {
        channelId: 'offers'
      }
    }
  };
  await sendNotification(message);
}

// 5. إشعار فلسطين
async function sendPalestineNotification() {
  const message = {
    topic: 'general_updates',
    notification: {
      title: 'فلسطين حرة',
      body: 'من النهر إلى البحر... فلسطين حرة'
    },
    data: {
      type: 'palestine',
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    android: {
      notification: {
        channelId: 'palestine'
      }
    }
  };
  await sendNotification(message);
}

// اختبار الإشعارات
async function runTests() {
  console.log('🚀 بدء اختبارات الإشعارات (Admin SDK)...');

  try {
    console.log('1. اختبار إرسال إشعار عام...');
    await sendGeneralUpdate();

    setTimeout(async () => {
      console.log('2. اختبار إشعار وصول حافلة...');
      await sendBusArrival(111, 'ميدان التحرير');
    }, 2000);

    setTimeout(async () => {
      console.log('3. اختبار إشعار زحمة...');
      await sendTrafficAlert('زحمة مرورية شديدة على طريق صلاح سالم');
    }, 4000);

  } catch (err) {
    console.error('❌ فشل الاختبار:', err.message);
  }
}

if (require.main === module) {
  runTests();
}

module.exports = {
  admin,
  sendNotification,
  sendGeneralUpdate,
  sendBusArrival,
  sendTrafficAlert,
  sendOfferNotification,
  sendPalestineNotification
};
