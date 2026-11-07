# NutriMate iOS — журнал ночного агента

## Как установить
1. https://github.com/TimkaSlowmo/Nutrimate/releases/tag/ios-latest → скачать **NutriMate.ipa**.
2. Sideloadly (или AltStore) → свой Apple ID → iPhone по кабелю. Бесплатный Apple ID: переустанавливать раз в 7 дней.
3. Переустановка поверх сохраняет данные (файл `Application Support/nutrimate.json`).

## Устройство
- SwiftUI, iOS 17+, Swift 5 mode, без сторонних библиотек. Проект — XcodeGen (`ios/project.yml`), сборка — `.github/workflows/ios.yml`
  (macos-15, неподписанный .ipa → релиз `ios-latest` + artifact).
- Данные продуктов/рецептов: `NutriMate/Resources/foods.json` ← `python3 tool/export_data.py` (из lib/main.dart). Не править вручную.
- Иконка: `python3 tool/make_app_icon.py`.
- Хранение: `AppStore` (ObservableObject) → JSON, мягкое декодирование (новые поля не ломают старые сохранения),
  битый файл копируется в `nutrimate.broken-<время>.json`, а не затирается.
- Версия: `ios/VERSION` + `CFBundleShortVersionString/CFBundleVersion` в project.yml (+1 за ночь).

## Этапы
- [x] 1. Скелет, сборка и релиз, 5 вкладок, цвета, стеклянный таб-бар, хранение, данные, рабочий холодильник
- [~] 2. Свежесть (есть), поиск с категориями и подсказками (есть), добавление продуктов (есть); TODO: свой срок при добавлении, количество/граммы
- [~] 3. Калории (дневник есть), рецепты из холодильника (есть), список покупок (есть); TODO: график веса, недельная статистика
- [~] 4. Eco Impact (цифры в профиле), достижения (есть); регистрация (простая); TODO: туториал с Нутриком, экран Eco Impact
- [ ] 5. Анимации Нутрика (бег/падение/еда), полировка, локальные уведомления о портящихся продуктах
