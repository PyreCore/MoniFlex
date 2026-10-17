// Service worker MoniFlex : permet d'ouvrir l'app sans connexion.
//
// Stratégie « réseau d'abord » : en ligne, on charge toujours la dernière
// version publiée (pas de vieille version bloquée en cache, contrairement
// au service worker de Flutter) ; chaque fichier reçu est copié dans le
// cache. Hors ligne, on sert cette copie.
//
// Les appels aux API de taux ne passent pas par ce cache : l'app gère
// elle-même le hors-ligne (derniers taux enregistrés, taux de secours).
const CACHE = 'moniflex-v1';

// Hôtes dont les fichiers sont mis en cache : le site lui-même et les
// polices Google utilisées par Flutter.
const CACHED_HOSTS = [self.location.host, 'fonts.gstatic.com', 'fonts.googleapis.com'];

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key !== CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (!CACHED_HOSTS.includes(url.host)) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    try {
      const response = await fetch(request);
      if (response.ok || response.type === 'opaque') {
        // Les pages sont rangées sans paramètres (?x=…) pour être
        // retrouvées hors ligne quelle que soit l'adresse ouverte.
        const key = request.mode === 'navigate' ? new URL('./', self.registration.scope).href : request;
        cache.put(key, response.clone());
      }
      return response;
    } catch (error) {
      const cached = request.mode === 'navigate'
        ? await cache.match(new URL('./', self.registration.scope).href)
        : await cache.match(request, { ignoreSearch: true });
      if (cached) return cached;
      throw error;
    }
  })());
});
