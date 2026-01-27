// Firebase Messaging Service Worker for Web
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

// Firebase 설정 (firebase_options.dart와 동일)
firebase.initializeApp({
  apiKey: "AIzaSyBODFoaNlf9uPJ3AN1EdoBW1I50A9vRF3M",
  authDomain: "bible-speak.firebaseapp.com",
  projectId: "bible-speak",
  storageBucket: "bible-speak.firebasestorage.app",
  messagingSenderId: "438057570983",
  appId: "1:438057570983:web:b81e23c3c36da802004182",
});

const messaging = firebase.messaging();

// 백그라운드 메시지 핸들러
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);

  const notificationTitle = payload.notification?.title || '바이블 스픽';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.data?.type || 'default',
    data: payload.data,
    requireInteraction: payload.data?.priority === 'high',
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// 알림 클릭 핸들러
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification clicked:', event);

  event.notification.close();

  // 앱 열기 또는 포커스
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});
