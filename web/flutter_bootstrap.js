{{flutter_js}}
{{flutter_build_config}}

// Service worker maison (sw.js) : ouverture sans connexion, sans jamais
// bloquer une ancienne version (réseau d'abord). On désinstalle tout autre
// service worker, notamment celui de Flutter des toutes premières versions,
// qui gardait d'anciennes versions en cache.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then((regs) => {
    for (const reg of regs) {
      const script = (reg.active || reg.waiting || reg.installing)?.scriptURL || '';
      if (!script.endsWith('/sw.js')) reg.unregister();
    }
  });
  navigator.serviceWorker.register('sw.js').catch((e) => {
    console.warn('Service worker MoniFlex non installé :', e);
  });
}

_flutter.loader.load();
