// Offline cache for the app shell only. Videos live in OPFS / IndexedDB and never pass through here.
const CACHE = 'drama-player-v5';
const SHELL = ['./', './index.html', './manifest.webmanifest', './icon-180.png', './icon-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return;
  const scope = new URL(self.registration.scope);
  const rel = './' + url.pathname.slice(scope.pathname.length);
  if (!SHELL.includes(rel) && req.mode !== 'navigate') return;
  // Network first so updates show up right away; fall back to the cache when offline.
  e.respondWith((async () => {
    try {
      const res = await Promise.race([fetch(req), new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), 4000))]);
      if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); }
      return res;
    } catch (err) {
      return (await caches.match(req, { ignoreSearch: true })) || (await caches.match('./index.html')) || Response.error();
    }
  })());
});
