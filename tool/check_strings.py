#!/usr/bin/env python3
"""Переводы интерфейса iOS (жалоба 3: EN / RU / KK).

Источник — фрагменты tool/l10n/*.json: { "English key": {"ru": "…", "kk": "…"} }.
Скрипт собирает их в ios/NutriMate/Resources/strings.json и проверяет, что у каждой строки
L("…") / Lp(n, "…") в Swift-коде есть перевод на оба языка, а подстановки {0} {1} совпадают.

  python3 tool/check_strings.py          # собрать + проверить (код возврата 1, если чего-то нет)
  python3 tool/check_strings.py --list   # напечатать недостающие ключи
"""
import glob, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tool", "l10n")
OUT = os.path.join(ROOT, "ios", "NutriMate", "Resources", "strings.json")
SWIFT = os.path.join(ROOT, "ios", "NutriMate")

LIT = r'"((?:[^"\\\n]|\\.)*)"'
PATTERNS = [re.compile(r'\bL\(\s*' + LIT), re.compile(r'\bLK\(\s*' + LIT), re.compile(r'\bLp\([^,()]*(?:\([^()]*\))?[^,()]*,\s*' + LIT)]


def unescape(s):
    s = re.sub(r'\\u\{([0-9a-fA-F]+)\}', lambda m: chr(int(m.group(1), 16)), s)
    return s.replace('\\"', '"').replace("\\n", "\n").replace("\\t", "\t").replace("\\'", "'").replace("\\\\", "\\")


def code_keys():
    keys, bad = {}, []
    for path in glob.glob(os.path.join(SWIFT, "**", "*.swift"), recursive=True):
        if path.endswith("L10n.swift"):
            continue
        text = open(path, encoding="utf-8").read()
        for pat in PATTERNS:
            for m in pat.finditer(text):
                raw = m.group(1)
                where = f"{os.path.relpath(path, ROOT)}:{text.count(chr(10), 0, m.start()) + 1}"
                if "\\(" in raw:
                    bad.append(f"{where}: интерполяция внутри L(\"…\") — используй {{0}}: {raw[:60]}")
                    continue
                keys.setdefault(unescape(raw), where)
    return keys, bad


def main():
    table, problems = {}, []
    for f in sorted(glob.glob(os.path.join(SRC, "*.json"))):
        try:
            frag = json.load(open(f, encoding="utf-8"))
        except Exception as e:  # noqa
            print(f"❌ {f}: {e}")
            sys.exit(1)
        for k, v in frag.items():
            if k in table and table[k] != v:
                print(f"⚠️ разные переводы для «{k}» ({os.path.basename(f)}) — оставлен первый")
                continue
            table[k] = v
    keys, bad = code_keys()
    missing = []
    for k, where in sorted(keys.items(), key=lambda kv: kv[1]):
        t = table.get(k)
        if not t or not t.get("ru") or not t.get("kk"):
            missing.append((k, where))
            continue
        ph = sorted(set(re.findall(r"\{\d\}", k)))
        for lang in ("ru", "kk"):
            if sorted(set(re.findall(r"\{\d\}", t[lang]))) != ph:
                problems.append(f"{where}: подстановки в {lang} не совпадают: «{k}» → «{t[lang]}»")
            if "|" in k and lang == "ru" and t[lang].count("|") != 2:
                problems.append(f"{where}: ru-форма множественного числа должна быть «one|few|many»: «{t[lang]}»")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    used = {k: table[k] for k in sorted(table)}
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(used, fh, ensure_ascii=False, indent=0, sort_keys=True)
    print(f"strings.json: {len(used)} строк; в коде {len(keys)} ключей, без перевода {len(missing)}")
    for b in bad + problems:
        print("❌", b)
    if "--list" in sys.argv or missing:
        for k, where in missing[:400]:
            print(f"  нет перевода: {where}  {json.dumps(k, ensure_ascii=False)}")
    sys.exit(1 if (bad or problems or missing) else 0)


if __name__ == "__main__":
    main()
