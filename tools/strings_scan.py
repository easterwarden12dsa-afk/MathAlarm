"""Lists the user-visible string literals in the app's Swift files.

Each literal is printed with the call it is passed to and its interpolations,
so translations can be written for it (see tools/hebrew.py).
"""
import glob, json, re, sys

UI_CALLS = {"Text", "Label", "Button", "Toggle", "Section", "navigationTitle", "Picker", "confirmationDialog", "alert",
            "LabeledContent", "Menu", "ContentUnavailableView", "DisclosureGroup", "TextField", "Stepper", "DatePicker",
            "accessibilityLabel", "accessibilityHint", "ShareLink", "Tab", "tabItem"}

def scan(src):
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            j = src.find("\n", i); i = n if j < 0 else j; continue
        if src.startswith("/*", i):
            j = src.find("*/", i); i = n if j < 0 else j + 2; continue
        if c == '"':
            start = i
            multi = src.startswith('"""', i)
            i += 3 if multi else 1
            text, parts = "", []
            while i < n:
                if multi and src.startswith('"""', i): i += 3; break
                if not multi and src[i] == '"': i += 1; break
                if src[i] == "\\" and i + 1 < n and src[i + 1] == "(":
                    depth, j = 1, i + 2
                    while j < n and depth:
                        if src[j] == "(": depth += 1
                        elif src[j] == ")": depth -= 1
                        elif src[j] == '"':
                            # skip nested literal
                            k = j + 1
                            while k < n and src[k] != '"':
                                k += 2 if src[k] == "\\" else 1
                            j = k
                        j += 1
                    parts.append(src[i + 2:j - 1]); text += "\u0001"; i = j; continue
                if src[i] == "\\" and i + 1 < n:
                    text += {"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(src[i + 1], src[i + 1]); i += 2; continue
                text += src[i]; i += 1
            # the call this literal is an argument of
            before = src[max(0, start - 60):start]
            m = re.search(r"([A-Za-z_]+)\(\s*$", before)
            out.append((m.group(1) if m else None, text, parts))
            continue
        i += 1
    return out

if __name__ == "__main__":
    rows = []
    for f in sorted(glob.glob("MathAlarm/**/*.swift", recursive=True)):
        for call, text, parts in scan(open(f).read()):
            if not re.search(r"[A-Za-z]{2,}", text.replace("\u0001", "")): continue
            rows.append({"file": f.split("/")[-1], "call": call, "text": text, "parts": parts})
    json.dump(rows, sys.stdout, ensure_ascii=False, indent=0)
