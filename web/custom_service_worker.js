// Custom Service Worker Additions for iOS PWA Update Support
// This file is appended to flutter_service_worker.js after build

// Handle SKIP_WAITING message to activate new version immediately
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    console.log('[SW] Received SKIP_WAITING, activating new version...');
    self.skipWaiting();
  }
});

// Claim clients immediately on activation
self.addEventListener('activate', (event) => {
  console.log('[SW] Activated, claiming clients...');
  event.waitUntil(clients.claim());
});

// Log installation (skipWaiting is triggered via message)
self.addEventListener('install', (event) => {
  console.log('[SW] Installing new service worker...');
});

console.log('[SW] Custom service worker additions loaded');
