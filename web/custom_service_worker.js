// Custom Service Worker Additions for iOS PWA Update Support
// This file is appended to flutter_service_worker.js after build

// SKIP_WAITING 메시지 수신 시 즉시 활성화
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    console.log('[SW] Received SKIP_WAITING, activating new version...');
    self.skipWaiting();
  }
});

// 활성화 시 즉시 제어권 획득
self.addEventListener('activate', (event) => {
  console.log('[SW] Activated, claiming clients...');
  event.waitUntil(clients.claim());
});

// 설치 시 즉시 활성화 (개발 모드에서 유용)
self.addEventListener('install', (event) => {
  console.log('[SW] Installing new service worker...');
  // skipWaiting은 메시지로 트리거하므로 여기서는 호출하지 않음
});

console.log('[SW] Custom service worker additions loaded');
