{{flutter_js}}
{{flutter_build_config}}

// Pas de service worker : il gardait d'anciennes versions en cache (surtout
// sur iPhone, écran d'accueil). On désinstalle aussi celui des anciennes
// versions, pour que chaque ouverture charge la dernière publication.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then((regs) => {
    for (const reg of regs) reg.unregister();
  });
  if ('caches' in window) {
    caches.keys().then((keys) => {
      for (const key of keys) caches.delete(key);
    });
  }
}

_flutter.loader.load();
