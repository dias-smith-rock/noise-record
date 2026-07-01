#!/usr/bin/env python3
"""Expand String Catalog localizations for DecibelPro (incremental, resumable)."""

from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path

try:
    from deep_translator import GoogleTranslator, MyMemoryTranslator
except ImportError:
    print("Install: python3 -m pip install deep-translator", file=sys.stderr)
    raise

REPO_ROOT = Path(__file__).resolve().parent.parent
LOCALIZABLE = REPO_ROOT / "NoiseRecord" / "Localizable.xcstrings"
INFOPLIST = REPO_ROOT / "NoiseRecord" / "InfoPlist.xcstrings"
CACHE_PATH = REPO_ROOT / "scripts" / ".translation_cache.json"

TARGET_LOCALES = [
    "en", "ar", "bg", "ca", "cs", "da", "de", "el", "es", "fi", "fr", "he", "hi", "hr", "hu",
    "id", "it", "ja", "ko", "ms", "nb", "nl", "pl", "pt", "ro", "ru", "sk", "sv", "th", "tr",
    "uk", "vi", "zh-Hans", "zh-Hant",
]

GOOGLE_LOCALE = {"zh-Hans": "zh-CN", "zh-Hant": "zh-TW", "nb": "no", "he": "iw"}
MYMEMORY_LOCALE = {"zh-Hans": "zh-CN", "zh-Hant": "zh-TW", "nb": "no", "he": "iw"}
VERBATIM_KEYS = {"", "·", "dB", "72", "%lld %@"}
PLACEHOLDER_RE = re.compile(r"%(?:\d+\$)?[@dflld]|%.[\d]+[f]|%%")
DB_UNIT_RE = re.compile(r"^\d+(?:\.\d+)?\s*dB(?:Z|A|C)?$", re.IGNORECASE)
PROTECTED_TERMS = (
    "DecibelPro", "dBA", "dBC", "dBZ", "dB", "Leq", "GPS", "CSV", "RMS", "SPL", "AI", "LED",
)


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def save_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def load_cache() -> dict[str, str]:
    if CACHE_PATH.exists():
        return json.loads(CACHE_PATH.read_text(encoding="utf-8"))
    return {}


def save_cache(cache: dict[str, str]) -> None:
    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    CACHE_PATH.write_text(json.dumps(cache, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def english_source(entry: dict) -> str | None:
    locs = entry.get("localizations", {})
    if "en" in locs:
        return locs["en"].get("stringUnit", {}).get("value")
    for locale in TARGET_LOCALES:
        value = locs.get(locale, {}).get("stringUnit", {}).get("value")
        if value is not None:
            return value
    return None


def protect_placeholders(text: str) -> tuple[str, list[str]]:
    placeholders: list[str] = []

    def repl(match: re.Match[str]) -> str:
        placeholders.append(match.group(0))
        return f"__PH{len(placeholders) - 1}__"

    return PLACEHOLDER_RE.sub(repl, text), placeholders


def restore_placeholders(text: str, placeholders: list[str]) -> str:
    for index, ph in enumerate(placeholders):
        for variant in (f"__PH{index}__", f"__PH{index} __", f"__ PH{index}__"):
            text = text.replace(variant, ph)
    return text


def protect_terms(text: str) -> tuple[str, dict[str, str]]:
    tokens: dict[str, str] = {}
    for index, term in enumerate(PROTECTED_TERMS):
        if term in text:
            token = f"\uE000{index}\uE001"
            tokens[token] = term
            text = text.replace(term, token)
    return text, tokens


def restore_terms(text: str, tokens: dict[str, str]) -> str:
    for token, term in tokens.items():
        text = text.replace(token, term)

    # Recover from translators mutating legacy __TERM{n}__ placeholders.
    for match in re.finditer(r"__\s*TERM[A-Z]*\s*(\d+)\s*__", text, flags=re.IGNORECASE):
        index = int(match.group(1))
        if 0 <= index < len(PROTECTED_TERMS):
            text = text.replace(match.group(0), PROTECTED_TERMS[index])

    # Recover common Chinese/Vietnamese corruptions of __TERM4__ (dB).
    text = re.sub(r"__?\s*第?(\d+)学期\s*__?", _replace_term_index, text, flags=re.IGNORECASE)
    text = re.sub(r"__?\s*第?(\d+)學期\s*__?", _replace_term_index, text, flags=re.IGNORECASE)
    text = re.sub(r"__?\s*学期(\d+)\s*__?", _replace_term_index, text, flags=re.IGNORECASE)
    text = re.sub(r"__?\s*學期(\d+)\s*__?", _replace_term_index, text, flags=re.IGNORECASE)
    text = re.sub(r"__?\s*HỌC(\d+)\s*__?", _replace_term_index, text, flags=re.IGNORECASE)
    return text


def _replace_term_index(match: re.Match[str]) -> str:
    index = int(match.group(1))
    if 0 <= index < len(PROTECTED_TERMS):
        return PROTECTED_TERMS[index]
    return match.group(0)


def cache_key(locale: str, text: str) -> str:
    return f"{locale}\u241f{text}"


def call_translator(locale: str, text: str) -> str:
    google_locale = GOOGLE_LOCALE.get(locale, locale)
    last_error: Exception | None = None
    for attempt in range(4):
        try:
            return GoogleTranslator(source="en", target=google_locale).translate(text)
        except Exception as error:  # noqa: BLE001
            last_error = error
            time.sleep(0.5 * (attempt + 1))
    memory_locale = MYMEMORY_LOCALE.get(locale, locale)
    try:
        return MyMemoryTranslator(source="en", target=memory_locale).translate(text)
    except Exception as error:  # noqa: BLE001
        raise last_error or error


def translate_one(locale: str, text: str, cache: dict[str, str]) -> str:
    if locale == "en":
        return text
    key = cache_key(locale, text)
    if key in cache:
        return cache[key]
    protected, placeholders = protect_placeholders(text)
    protected, term_tokens = protect_terms(protected)
    try:
        translated = call_translator(locale, protected)
    except Exception as error:  # noqa: BLE001
        print(f"  WARN {locale}: {error!r}", file=sys.stderr)
        translated = protected
    translated = restore_terms(translated, term_tokens)
    translated = restore_placeholders(translated, placeholders)
    cache[key] = translated
    time.sleep(0.05)
    return translated


def is_verbatim(key: str, source: str) -> bool:
    if key in VERBATIM_KEYS or source in VERBATIM_KEYS:
        return True
    if DB_UNIT_RE.match(source.strip()):
        return True
    if source in PROTECTED_TERMS:
        return True
    return False


def expand_catalog(path: Path, cache: dict[str, str]) -> int:
    catalog = load_json(path)
    strings = catalog.get("strings", {})
    added = 0

    for locale in TARGET_LOCALES:
        pending: list[tuple[str, str]] = []
        for key, entry in strings.items():
            locs = entry.setdefault("localizations", {})
            if locale in locs:
                continue
            source = english_source(entry)
            if source is None:
                continue
            if is_verbatim(key, source):
                locs[locale] = {"stringUnit": {"state": "translated", "value": source}}
                added += 1
                continue
            pending.append((key, source))

        if not pending:
            continue

        print(f"  {path.name} · {locale}: {len(pending)} strings", flush=True)
        for index, (key, source) in enumerate(pending, start=1):
            value = translate_one(locale, source, cache)
            strings[key]["localizations"][locale] = {
                "stringUnit": {"state": "translated", "value": value},
            }
            added += 1
            if index % 50 == 0:
                save_cache(cache)
                save_json(path, catalog)
                print(f"    … {index}/{len(pending)}", flush=True)

        save_cache(cache)
        save_json(path, catalog)

    return added


def main() -> int:
    cache = load_cache()
    print(f"Locales: {len(TARGET_LOCALES)} | Cache: {len(cache)} entries", flush=True)
    total = 0
    for path in (LOCALIZABLE, INFOPLIST):
        print(f"Expanding {path.name} …", flush=True)
        total += expand_catalog(path, cache)
    print(f"Done. Added {total} localizations.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
