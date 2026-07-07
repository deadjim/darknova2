// Kill-switch service worker.
//
// Earlier builds shipped Flutter's default offline-first service worker,
// which serves the cached app and only updates in the background — stale
// builds for playtesters. We now build with --pwa-strategy=none, and this
// file replaces the old worker at its registered URL: it installs
// immediately, wipes every cache, unregisters itself, and reloads open
// tabs so clients self-heal onto always-fresh HTTP.
self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.map((k) => caches.delete(k)));
    await self.registration.unregister();
    const clients = await self.clients.matchAll({ type: 'window' });
    clients.forEach((client) => client.navigate(client.url));
  })());
});
