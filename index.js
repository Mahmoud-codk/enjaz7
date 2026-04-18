const admin = require('firebase-admin');

let serviceAccount;
try {
  // Try to load the local file during development
  serviceAccount = require('./serviceAccountKey.json');
} catch (error) {
  // If not found, try to load from environment variable (Production/Render)
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  } else {
    console.error('❌ Missing FIREBASE_SERVICE_ACCOUNT environment variable and serviceAccountKey.json file.');
    process.exit(1);
  }
}

const PROJECT_ID = 'enjaz7-a49f2';

if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: `https://${PROJECT_ID}.firebaseio.com`
  });
}

console.log('Firebase Admin SDK initialized successfully.');

module.exports = admin;
