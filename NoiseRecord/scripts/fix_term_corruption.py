#!/usr/bin/env python3
"""Repair machine-translated placeholder corruption in String Catalogs."""

from __future__ import annotations

import json
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
LOCALIZABLE = REPO_ROOT / "NoiseRecord" / "Localizable.xcstrings"
INFOPLIST = REPO_ROOT / "NoiseRecord" / "InfoPlist.xcstrings"
CACHE_PATH = REPO_ROOT / "scripts" / ".translation_cache.json"

PROTECTED_TERMS = (
    "DecibelPro", "dBA", "dBC", "dBZ", "dB", "Leq", "GPS", "CSV", "RMS", "SPL", "AI", "LED",
)

TERM_TOKEN_RE = re.compile(r"__\s*TERM[A-Z]*\s*(\d+)\s*__", re.IGNORECASE)
SEMESTER_CORRUPTION_RE = re.compile(r"__?\s*第?(\d+)学期\s*__?", re.IGNORECASE)
TRAD_SEMESTER_CORRUPTION_RE = re.compile(r"__?\s*第?(\d+)學期\s*__?", re.IGNORECASE)
TERM_SEMESTER_SUFFIX_RE = re.compile(r"__?\s*学期(\d+)\s*__?", re.IGNORECASE)
TERM_TRAD_SEMESTER_SUFFIX_RE = re.compile(r"__?\s*學期(\d+)\s*__?", re.IGNORECASE)
DB_CORRUPTION_RE = re.compile(
    r"__?\s*(?:第\d+学期|第\d+學期|HỌC\d+|المصطلح\d+)\s*__?",
    re.IGNORECASE,
)
DB_UNIT_RE = re.compile(r"^(\d+(?:\.\d+)?)\s*dB(?:Z|A|C)?$", re.IGNORECASE)


def repair_value(value: str, english: str | None = None) -> str:
    repaired = value
    for match in TERM_TOKEN_RE.finditer(repaired):
        index = int(match.group(1))
        if 0 <= index < len(PROTECTED_TERMS):
            repaired = repaired.replace(match.group(0), PROTECTED_TERMS[index])
    for match in SEMESTER_CORRUPTION_RE.finditer(repaired):
        index = int(match.group(1))
        if 0 <= index < len(PROTECTED_TERMS):
            repaired = repaired.replace(match.group(0), PROTECTED_TERMS[index])
    for match in TRAD_SEMESTER_CORRUPTION_RE.finditer(repaired):
        index = int(match.group(1))
        if 0 <= index < len(PROTECTED_TERMS):
            repaired = repaired.replace(match.group(0), PROTECTED_TERMS[index])
    for match in TERM_SEMESTER_SUFFIX_RE.finditer(repaired):
        index = int(match.group(1))
        if 0 <= index < len(PROTECTED_TERMS):
            repaired = repaired.replace(match.group(0), PROTECTED_TERMS[index])
    for match in TERM_TRAD_SEMESTER_SUFFIX_RE.finditer(repaired):
        index = int(match.group(1))
        if 0 <= index < len(PROTECTED_TERMS):
            repaired = repaired.replace(match.group(0), PROTECTED_TERMS[index])
    repaired = DB_CORRUPTION_RE.sub("dB", repaired)
    repaired = re.sub(r"(\d)\s*dB", r"\1 dB", repaired)
    if english and DB_UNIT_RE.match(english.strip()):
        return english
    return repaired


def repair_catalog(path: Path) -> int:
    data = json.loads(path.read_text(encoding="utf-8"))
    changed = 0
    for entry in data.get("strings", {}).values():
        locs = entry.get("localizations", {})
        english = locs.get("en", {}).get("stringUnit", {}).get("value")
        for locale in locs:
            unit = locs[locale].get("stringUnit", {})
            value = unit.get("value")
            if not isinstance(value, str):
                continue
            fixed = repair_value(value, english)
            if fixed != value:
                unit["value"] = fixed
                changed += 1
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return changed


def patch_exchange_rate_labels() -> None:
    data = json.loads(LOCALIZABLE.read_text(encoding="utf-8"))
    overrides = {
        "mediaDetail.exchangeRate": {
            "en": "Exchange Rate",
            "zh-Hans": "交换率",
            "zh-Hant": "交換率",
            "ja": "交換率",
            "ko": "교환율",
            "de": "Tauschrate",
            "fr": "Taux d'échange (dose)",
            "es": "Tasa de intercambio",
            "pt": "Taxa de troca",
            "it": "Tasso di scambio",
        }
    }
    for key, locales in overrides.items():
        locs = data["strings"][key]["localizations"]
        for locale, value in locales.items():
            locs[locale]["stringUnit"]["value"] = value
    LOCALIZABLE.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def purge_bad_cache_entries() -> int:
    if not CACHE_PATH.exists():
        return 0
    cache = json.loads(CACHE_PATH.read_text(encoding="utf-8"))
    removed = 0
    for key, value in list(cache.items()):
        if TERM_TOKEN_RE.search(value) or DB_CORRUPTION_RE.search(value) or "__学期" in value:
            del cache[key]
            removed += 1
    CACHE_PATH.write_text(json.dumps(cache, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return removed


def main() -> int:
    changed_localizable = repair_catalog(LOCALIZABLE)
    changed_infoplist = repair_catalog(INFOPLIST)
    patch_exchange_rate_labels()
    removed = purge_bad_cache_entries()
    print(
        f"Repaired {changed_localizable} Localizable + {changed_infoplist} InfoPlist values; "
        f"removed {removed} bad cache entries."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
