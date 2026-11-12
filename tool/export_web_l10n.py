#!/usr/bin/env python3
"""Переводы веб-версии (EN / RU / KK) → lib/l10n_data.dart.

Источники (общие с iOS):
  tool/l10n/*.json            строки интерфейса { "English": {"ru": "…", "kk": "…"} } (web.json — только для веба)
  tool/translations_src.txt   названия продуктов и рецептов English|Русский|Қазақша
  tool/recipe_steps_l10n.json шаги рецептов
Проверка: у каждой tr('…') / trk('…') / trp(n, '…') в lib/*.dart должен быть перевод на оба языка с теми же {0}.

  python3 tool/export_web_l10n.py          # собрать + проверить (код 1, если чего-то нет)
"""
import glob, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "lib", "l10n_data.dart")

LIT = r"'((?:[^'\\\n]|\\.)*)'|\"((?:[^\"\\\n]|\\.)*)\""
PATS = [re.compile(r"\btr\(\s*(?:" + LIT + r")"), re.compile(r"\btrk\(\s*(?:" + LIT + r")"),
        re.compile(r"\btrp\([^,()]*(?:\([^()]*\))?[^,()]*,\s*(?:" + LIT + r")")]


def dq(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$").replace("\n", "\\n") + "'"


def unesc(s):
    return s.replace("\\'", "'").replace('\\"', '"').replace("\\n", "\n").replace("\\$", "$").replace("\\\\", "\\")


def main():
    table, web = {}, {}
    for f in sorted(glob.glob(os.path.join(ROOT, "tool", "l10n", "*.json"))):
        frag = json.load(open(f, encoding="utf-8"))
        if f.endswith("web.json"):
            web = frag
        for k, v in frag.items():
            table.setdefault(k, v)
    names = {}
    for line in open(os.path.join(ROOT, "tool", "translations_src.txt"), encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        p = line.split("|")
        if len(p) == 3:
            names[p[0].strip()] = (p[1].strip(), p[2].strip())
    steps = json.load(open(os.path.join(ROOT, "tool", "recipe_steps_l10n.json"), encoding="utf-8"))

    problems = []
    keys = {}
    for path in glob.glob(os.path.join(ROOT, "lib", "*.dart")):
        if path.endswith(("l10n.dart", "l10n_data.dart")):
            continue
        text = open(path, encoding="utf-8").read()
        for pat in PATS:
            for m in pat.finditer(text):
                raw = m.group(1) if m.group(1) is not None else m.group(2)
                where = f"{os.path.relpath(path, ROOT)}:{text.count(chr(10), 0, m.start()) + 1}"
                if re.search(r"(?<!\\)\$", raw):
                    problems.append(f"{where}: интерполяция $ внутри tr('…') — используй {{0}}: {raw[:60]}")
                    continue
                keys.setdefault(unesc(raw), where)
    for k, where in sorted(keys.items(), key=lambda kv: kv[1]):
        t = table.get(k)
        if not t or not t.get("ru") or not t.get("kk"):
            problems.append(f"{where}: нет перевода: {k!r}")
            continue
        ph = set(re.findall(r"\{\d\}", k))
        for lang in ("ru", "kk"):
            if set(re.findall(r"\{\d\}", t[lang])) != ph:
                problems.append(f"{where}: подстановки {{n}} не совпадают ({lang}): {k!r}")

    used = dict(sorted(table.items()))  # вся таблица: tr(x) вызывается и для строк из данных (советы, медали, места)
    used.update({k: table[k] for k in web})  # web.json целиком: там и ключи из const-данных (подписи мест, причины…)
    # категории и прочие ключи, которые tn() берёт из таблицы интерфейса
    for k in ("Vegetables", "Fruits", "Berries", "Meat", "Seafood", "Dairy", "Bakery", "Grains", "Nuts & Legumes",
              "Pantry", "Sweets", "Drinks", "Frozen", "Spices", "Canned", "Ready Meals", "Snacks", "Plant-Based",
              "World Foods", "Baby Food"):
        if k in table:
            used[k] = table[k]
    out = ["// СГЕНЕРИРОВАНО tool/export_web_l10n.py — не править вручную.", "// ignore_for_file: lines_longer_than_80_chars", "",
           "const Map<String, List<String>> uiTr = {"]
    for k, v in used.items():
        out.append(f"  {dq(k)}: [{dq(v.get('ru', ''))}, {dq(v.get('kk', ''))}],")
    out.append("};\n\nconst Map<String, List<String>> nameTr = {")
    for k, (ru, kk) in sorted(names.items()):
        out.append(f"  {dq(k)}: [{dq(ru)}, {dq(kk)}],")
    out.append("};\n\nconst Map<String, List<List<String>>> stepsTr = {")
    for k, v in sorted(steps.items()):
        ru = ", ".join(dq(s) for s in v.get("ru", []))
        kk = ", ".join(dq(s) for s in v.get("kk", []))
        out.append(f"  {dq(k)}: [[{ru}], [{kk}]],")
    out.append("};\n")
    open(OUT, "w", encoding="utf-8").write("\n".join(out))
    if problems:
        print("\n".join(problems))
        print(f"❌ {len(problems)} проблем")
        sys.exit(1)
    print(f"OK: {len(used)} строк интерфейса, {len(names)} названий, {len(steps)} рецептов с шагами → lib/l10n_data.dart")


if __name__ == "__main__":
    main()
