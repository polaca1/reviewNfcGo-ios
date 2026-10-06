import json
import os
from pathlib import Path

key = os.environ.get("GOOGLE_PLACES_API_KEY", "")
if not key:
    raise SystemExit("Configure the GOOGLE_PLACES_API_KEY repository secret before building.")
Path("reviewNfcGo/LocalConfig.swift").write_text(
    "// Generated locally at build time. Do not commit.\n"
    "enum LocalConfig {\n"
    f"    static let googlePlacesAPIKey = {json.dumps(key)}\n"
    "}\n"
)
