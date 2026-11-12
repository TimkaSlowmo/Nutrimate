// Три языка веб-версии: English / Русский / Қазақша (как в iOS).
// Ключ — английский текст; {0}, {1}… — подстановки. Таблицы — lib/l10n_data.dart
// (генерирует `python3 tool/export_web_l10n.py` из tool/l10n/*.json, translations_src.txt, recipe_steps_l10n.json;
// скрипт падает, если у tr('…') в lib/main.dart нет перевода).
import 'l10n_data.dart';

const appLangs = ['en', 'ru', 'kk'];
const langFlag = {'en': '🇬🇧', 'ru': '🇷🇺', 'kk': '🇰🇿'};
const langNative = {'en': 'English', 'ru': 'Русский', 'kk': 'Қазақша'};
const langHello = {
  'en': "Hi! I'm Nutrik 🐾 Let's pick your language.",
  'ru': 'Привет! Я Нутрик 🐾 Давай выберем язык.',
  'kk': 'Сәлем! Мен Нутрикпін 🐾 Тілді таңдайық.',
};

/// Текущий язык (выставляет AppState при загрузке и при смене).
String appLang = 'en';

int get _li => appLang == 'ru' ? 0 : (appLang == 'kk' ? 1 : -1);

String _raw(String key) {
  final i = _li;
  if (i < 0) return key;
  final t = uiTr[key];
  if (t == null || t[i].isEmpty) return key;
  return t[i];
}

/// Перевод строки интерфейса: tr('Expires in {0} days', [3]).
String tr(String key, [List<Object?> args = const []]) {
  var s = _raw(key);
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}

/// Метка ключа перевода для строк в данных/массивах (переводятся при показе через tr(x)).
String trk(String key) => key;

/// Слово с числом: trp(3, 'product|products') → «3 продукта». ru: «one|few|many», kk: одна форма.
String trp(int n, String forms, {bool withNumber = true}) {
  final f = _raw(forms).split('|');
  String w;
  if (f.length == 1) {
    w = f[0];
  } else {
    final a = n.abs();
    if (f.length >= 3) {
      final m10 = a % 10, m100 = a % 100;
      w = (m10 == 1 && m100 != 11) ? f[0] : ((m10 >= 2 && m10 <= 4 && !(m100 >= 12 && m100 <= 14)) ? f[1] : f[2]);
    } else {
      w = a == 1 ? f[0] : f[1];
    }
  }
  return withNumber ? '$n $w' : w;
}

/// Название продукта, рецепта или категории на языке приложения (в данных всегда английское).
String tn(String en) {
  final i = _li;
  if (i < 0) return en;
  final t = nameTr[en] ?? uiTr[en];
  if (t == null || t[i].isEmpty) return en;
  return t[i];
}

/// Все названия продукта (для поиска на трёх языках), в нижнем регистре.
String searchKey(String en) => _searchKeys[en] ??= () {
  final t = nameTr[en];
  return t == null ? en.toLowerCase() : '${en.toLowerCase()} ${t[0].toLowerCase()} ${t[1].toLowerCase()}';
}();
final _searchKeys = <String, String>{};

/// Шаги рецепта на языке приложения (нет перевода или другое число шагов — английские).
List<String> trSteps(String recipe, List<String> en) {
  final i = _li;
  if (i < 0) return en;
  final t = stepsTr[recipe];
  if (t == null || t[i].length != en.length) return en;
  return t[i];
}

/// Язык системы браузера, если он ru/kk, иначе en.
String systemLang(String? code) {
  final c = (code ?? '').toLowerCase();
  if (c.startsWith('ru')) return 'ru';
  if (c.startsWith('kk')) return 'kk';
  return 'en';
}

const _monthsRu = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
const _monthsKk = ['қаң', 'ақп', 'нау', 'сәу', 'мам', 'мау', 'шіл', 'там', 'қыр', 'қаз', 'қар', 'жел'];
const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// «12 Nov» / «12 ноя» / «12 қар»
String fmtDate(DateTime d) {
  final m = appLang == 'ru' ? _monthsRu : (appLang == 'kk' ? _monthsKk : _monthsEn);
  return '${d.day} ${m[d.month - 1]}';
}

/// «1 h 20 min» → «1 ч 20 мин» / «1 сағ 20 мин».
String trTime(String t) {
  if (appLang == 'en') return t;
  final ru = appLang == 'ru';
  return t
      .replaceAll(RegExp(r'\bmin\b'), 'мин')
      .replaceAll(RegExp(r'\bh\b'), ru ? 'ч' : 'сағ')
      .replaceAll('night', ru ? 'ночь' : 'түн')
      .replaceAll('chill', ru ? 'в холодильнике' : 'салқындату');
}

const _staples = {
  'salt': ['соль', 'тұз'],
  'pepper': ['перец', 'бұрыш'],
  'black pepper': ['чёрный перец', 'қара бұрыш'],
  'oil': ['масло', 'май'],
  'bay leaf': ['лавровый лист', 'лавр жапырағы'],
  'cumin': ['зира', 'зире'],
  'paprika': ['паприка', 'паприка'],
  'cinnamon': ['корица', 'даршын'],
  'water': ['вода', 'су'],
  'oregano': ['орегано', 'орегано'],
  'lemon': ['лимон', 'лимон'],
  'chili': ['чили', 'чили'],
  'chili flakes': ['хлопья чили', 'чили үгіндісі'],
  'vanilla': ['ваниль', 'ваниль'],
  'baking soda': ['сода', 'сода'],
  'sesame seeds': ['кунжут', 'күнжіт'],
  'dill': ['укроп', 'аскөк'],
  'thyme': ['тимьян', 'тимьян'],
  'nutmeg': ['мускатный орех', 'мускат жаңғағы'],
  'vinegar': ['уксус', 'сірке суы'],
  'pinch of salt': ['щепотка соли', 'бір шымшым тұз'],
  'herbs': ['зелень', 'көк шөп'],
  'dried herbs': ['сушёные травы', 'кептірілген шөптер'],
  'mustard': ['горчица', 'қыша'],
  'stock': ['бульон', 'сорпа'],
  'baking powder': ['разрыхлитель', 'қопсытқыш'],
  'garlic': ['чеснок', 'сарымсақ'],
  'sugar': ['сахар', 'қант'],
  'soy sauce': ['соевый соус', 'соя соусы'],
  'oil for frying': ['масло для жарки', 'қуыруға май'],
  'ice': ['лёд', 'мұз'],
  'nothing else': ['больше ничего', 'басқа ештеңе'],
};

/// «salt, pepper, oil» → «соль, перец, масло» (незнакомые слова остаются как есть).
String trStaples(String s) {
  final i = _li;
  if (i < 0) return s;
  return s.split(',').map((p) {
    final w = p.trim();
    var opt = '';
    var core = w;
    if (core.toLowerCase().startsWith('optional: ')) {
      core = core.substring(10);
      opt = i == 0 ? 'по желанию: ' : 'қаласаңыз: ';
    }
    final t = _staples[core.toLowerCase()];
    return opt + (t == null ? core : t[i]);
  }).join(', ');
}
