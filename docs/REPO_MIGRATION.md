# 🗂 Repository Migration

Detta dokument sammanfattar flytten från det tidigare monorepot till det nuvarande butlery-repositoriet.

## Steg i migreringen

- Samlade alla Flutter-filer under `lib/` och rensade äldre `src/`-strukturer.
- Introducerade `core/`, `services/` och `models/` för tydligare arkitektur.
- Uppdaterade `pubspec.yaml` med Firebase, Hive och testberoenden.
- Lades till CI-workflow för tester i `.github/workflows/test.yml`.
- Plattformsspecifika mappar (`android/`, `ios/`, `web/`) flyttades över oförändrade.

Denna översikt hjälper utvecklare att förstå hur projektet omorganiserades och vilka filer som påverkades.
