// Remplace le service worker de Flutter au déploiement (voir
// .github/workflows/deploy-web.yml). Les appareils qui ont l'ancien le
// mettent à jour avec celui-ci, qui vide le cache, se désinstalle et
// recharge la page : l'app sert alors toujours la dernière version publiée.
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) await caches.delete(key);
    await self.registration.unregister();
    const windows = await self.clients.matchAll({ type: 'window' });
    for (const client of windows) client.navigate(client.url);
  })());
});
