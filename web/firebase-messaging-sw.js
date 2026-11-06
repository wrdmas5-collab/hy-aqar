importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCxMtCMtFHlbDMBWZpHRzqwF0YDz_P9Yzo",
  authDomain: "hy-aqar.firebaseapp.com",
  projectId: "hy-aqar",
  storageBucket: "hy-aqar.firebasestorage.app",
  messagingSenderId: "960269964659",
  appId: "1:960269964659:web:10c758de7d84066f8fe106",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification?.title || 'إشعار جديد';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});
