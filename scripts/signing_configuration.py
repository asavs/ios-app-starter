"""Validate the native configuration export shared by signing commands."""
import json
from pathlib import Path
import re


def read_config(path):
    records = json.loads(Path(path).read_text(encoding="utf-8"))
    if (not isinstance(records, list) or len(records) != 2
            or any(not isinstance(item, dict) for item in records)
            or any(item.get("configuration") not in ("Debug", "Release") for item in records)
            or {item.get("configuration") for item in records} != {"Debug", "Release"}):
        raise ValueError("Fresh export must contain the Debug and Release record list.")
    for item in records:
        if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", str(item.get("bundleIdentifier", ""))):
            raise ValueError("Exported bundle identifier is invalid.")
        if not re.fullmatch(r"[A-Z0-9]{10}", str(item.get("teamIdentifier", ""))):
            raise ValueError("Exported Apple Team ID is missing or invalid; configure DEVELOPMENT_TEAM in the selected manifest.")
        name = item.get("displayName")
        if not isinstance(name, str) or not name.strip() or any(ord(char) < 32 or ord(char) == 127 for char in name):
            raise ValueError("Exported display name is missing or contains control characters.")
        if not re.fullmatch(r"\d+(?:\.\d+)*", str(item.get("minimumIOS", ""))):
            raise ValueError("Exported deployment minimum is invalid.")
    for key in ("bundleIdentifier", "teamIdentifier", "displayName", "minimumIOS"):
        if len({str(item[key]) for item in records}) != 1:
            raise ValueError(f"Debug and Release {key} values differ.")
    return next(item for item in records if item["configuration"] == "Release")
