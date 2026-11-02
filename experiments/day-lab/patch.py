#!/usr/bin/env python3
from pathlib import Path
import re
root=Path("DayLab")
cargo=root/"Cargo.toml"
s=cargo.read_text()
s += '\n[package.metadata.day.ios]\nswift-packages = [{ path = "swiftui", products = ["ReviewLabViews"] }]\nplatform = "26.0"\n'
cargo.write_text(s)
lib=root/"src/lib.rs"
if not lib.exists():
    raise SystemExit("Day scaffold has no src/lib.rs; update integration for this Day version")
s=lib.read_text()
s += '\n// Generated typed SwiftUI bridge; SwiftUI is compiled inside the Day iOS app.\npub mod swiftui { include!(concat!(env!("OUT_DIR"), "/day_swiftui.rs")); }\n'
lib.write_text(s)
print("Day project configured with native SwiftUI package")
