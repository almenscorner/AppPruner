#!/usr/bin/env python3
import json, hashlib, sys
from pathlib import Path
from datetime import datetime, timezone

# root is current directory
ROOT = Path(__file__).parent.resolve()
DEFS = ROOT / "defs"
INDEX = ROOT / "index.json"


def sha256_hex(data: bytes) -> str:
    h = hashlib.sha256()
    h.update(data)
    return h.hexdigest()


def main():
    items = []
    for appdir in sorted(DEFS.glob("*")):
        if not appdir.is_dir():
            continue
        for defpath in sorted(appdir.glob("*.json")):
            data = defpath.read_bytes()
            try:
                j = json.loads(data)
            except Exception as e:
                print(f"Skipping invalid JSON: {defpath} ({e})", file=sys.stderr)
                continue

            # Pull fields from your definition
            name = j.get("name")
            version = j.get("version") or sha256_hex(data)[:8]
            updated_at = j.get("updated_at")
            uninstall = j.get("uninstall", {})
            bundle_id = uninstall.get("bundleId")

            if not (bundle_id and name and version and updated_at):
                print(f"Missing fields in {defpath}", file=sys.stderr)
                continue

            rel = defpath.relative_to(ROOT).as_posix()
            items.append(
                {
                    "id": bundle_id,
                    "name": name,
                    "version": version,
                    "updated_at": updated_at,
                    "path": rel,
                    "sha256": sha256_hex(data),
                }
            )

    out = {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "items": items,
    }
    tmp = INDEX.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
    tmp.replace(INDEX)
    print(f"Wrote {INDEX} with {len(items)} item(s).")


if __name__ == "__main__":
    main()
