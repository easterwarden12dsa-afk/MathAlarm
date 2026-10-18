"""Runs the same translation as the app (HebrewTranslator in Language.swift) on text
from a file (one string per line, or the CI test log's TXT| lines) and shows the result.

    python3 tools/hebrew_preview.py test.log [--untranslated]
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
data = json.load(open(os.path.join(ROOT, "MathAlarm", "Resources", "hebrew.json"), encoding="utf-8"))
EXACT = data["exact"]
HOLE = r"((?:(?![.?!] [A-Z\"“(]).)*?)"
TEMPLATES = []
for en, he in data["templates"]:
    parts = en.split("{}")
    rx = re.compile("^" + HOLE.join(re.escape(p) for p in parts) + "$", re.S)
    pieces, nxt, rest = [], 0, he
    for m in re.finditer(r"\{(\d*)\}|[^{]+|\{", he):
        if m.group(0).startswith("{") and m.group(0).endswith("}") and (m.group(1) or m.group(0) == "{}"):
            if m.group(1): pieces.append(("v", int(m.group(1)) - 1))
            else: pieces.append(("v", nxt)); nxt += 1
        else: pieces.append(("t", m.group(0)))
    TEMPLATES.append((rx, max(parts, key=len), pieces))
PHRASES = data["phrases"]
HEB = re.compile(r"[֐-׿]")

def direct(s, depth):
    t = s.strip(" ")
    if s in EXACT: return EXACT[s]
    if t in EXACT: return EXACT[t]
    if depth >= 4: return None
    for rx, first, pieces in TEMPLATES:
        if first and first not in t: continue
        m = rx.match(t)
        if not m: continue
        vals = m.groups()
        return "".join(x if k == "t" else (raw(vals[x], depth + 1) if x < len(vals) else "") for k, x in pieces)
    return None

def sentences(s):
    out, cur, i = [], "", 0
    while i < len(s):
        cur += s[i]
        if s[i] in ".?!" and i + 2 < len(s) and s[i + 1] == " " and (s[i + 2].isupper() or s[i + 2] in "\"“("):
            out.append(cur); cur = ""; i += 2; continue
        i += 1
    if cur: out.append(cur)
    return out

def phrased(s):
    for en, he in PHRASES:
        if en not in s: continue
        res, rest = "", s
        while en in rest:
            k = rest.index(en)
            before = rest[k - 1] if k > 0 else " "
            after = rest[k + len(en)] if k + len(en) < len(rest) else " "
            if (en[0].isalpha() and before.isalpha()) or (en[-1].isalpha() and after.isalpha()):
                res += rest[:k + len(en)]
            else:
                res += rest[:k] + he
            rest = rest[k + len(en):]
        s = res + rest
    return s

def raw(s, depth=0):
    if not re.search(r"[A-Za-z]{2,}", s): return s
    d = direct(s, depth)
    if d is not None: return d
    sen = sentences(s)
    if len(sen) > 1:
        out, i = [], 0
        while i < len(sen):
            for j in range(len(sen), i, -1):
                if i == 0 and j == len(sen): continue
                d = direct(" ".join(sen[i:j]), depth)
                if d is not None: out.append(d); i = j; break
            else:
                out.append(phrased(sen[i])); i += 1
        return " ".join(out)
    for sep in (" — ", ";  ", "  →  "):
        if sep in s:
            parts = s.split(sep)
            return sep.join(raw(p, depth + 1) for p in parts)
    return phrased(s)

MATH = {"sin", "cos", "tan", "ln", "lim", "max", "min", "arctan", "arcsin", "arccos", "sec", "csc", "cot", "log", "exp", "dx", "du", "dv", "dt", "ABC", "ABM", "ABD"}
def english_left(s):
    words = [w for w in re.findall(r"[A-Za-z]{3,}", s) if w not in MATH]
    return words

if __name__ == "__main__":
    lines = [l.rstrip("\n") for l in open(sys.argv[1], encoding="utf-8")]
    lines = [l.split("TXT|", 1)[1] for l in lines if "TXT|" in l] or lines
    only_bad = "--untranslated" in sys.argv
    bad = 0
    for l in lines:
        h = raw(l.replace("⏎", "\n"))
        left = english_left(h)
        if left: bad += 1
        if not only_bad or left:
            print("EN:", l); print("HE:", h.replace("\n", "⏎"), ("   ⚠ " + " ".join(left[:6])) if left else ""); print()
    print(f"{len(lines)} strings, {bad} with English words left", file=sys.stderr)
