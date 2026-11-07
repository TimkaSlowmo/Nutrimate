# NutriMate Pro (Flutter Web)

Деплой на GitHub Pages происходит автоматически при каждом push в ветку main.
Подробная инструкция — в чате.

## Иконки продуктов
3D-иконки — [Microsoft Fluent Emoji](https://github.com/microsoft/fluentui-emoji) (лицензия MIT, текст в `assets/icons/LICENSE-fluentui-emoji.txt`).
Иконки для продуктов без подходящего эмодзи (`assets/icons/p`) — собственные, рисуются скриптом `tool/make_icons.py`.
`tool/build_icons.py` пересобирает `lib/food_icons.dart` и проверяет базу (дубли, ингредиенты рецептов, иконки).
