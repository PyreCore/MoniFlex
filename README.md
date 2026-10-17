# MoniFlex

Convertisseur de devises développé par **PyreCore**.

👉 **Utiliser l'application : https://pyrecore.github.io/MoniFlex/**
(sur iPhone : Partager → « Sur l'écran d'accueil » pour l'installer)

## Fonctionnalités

- Conversion entre plus de 160 devises, taux du jour ([open.er-api.com](https://www.exchangerate-api.com)).
- Fonctionne hors ligne : derniers taux enregistrés, ou taux de référence livrés avec l'app au premier lancement.
- Historique sur 7, 30 ou 90 jours (graphique interactif) avec variation depuis la veille ([fawazahmed0/exchange-api](https://github.com/fawazahmed0/exchange-api)).
- Thème clair, sombre ou celui du téléphone.

## Développement

```sh
flutter pub get
flutter test
flutter run -d chrome
```

Avant chaque version, rafraîchir les taux de référence hors ligne :

```sh
dart run tool/update_fallback_rates.dart
```

Le logo est défini dans `tool/icon/logo.svg` ; après une modification,
régénérer les icônes de toutes les plateformes (web, Android, iOS, macOS,
Windows ; nécessite Google Chrome) :

```sh
node tool/icon/render_icons.mjs
```

Chaque push sur `main` est testé puis publié automatiquement sur GitHub Pages
(`.github/workflows/deploy-web.yml`).
