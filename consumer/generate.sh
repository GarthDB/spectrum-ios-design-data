#!/usr/bin/env bash
# Copyright 2026 Adobe. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR REPRESENTATIONS OF ANY KIND, either express or
# implied. See the License for the specific language governing permissions
# and limitations under the License.
#
# Regenerates consumer/resolved-tokens.json by running the design-data CLI
# against this repo's .design-data.toml (github source pin + manifest.json
# cascade) for a small, curated demo set spanning the three cascade
# mechanisms: override, extension, and untouched foundation.
#
# The Swift consumer reads the *generated* JSON, not this script's live
# output — see consumer/Sources/spectrum-demo/main.swift. Re-run this after
# any manifest.json or foundation-pin change.
#
# ponytail: hand-picked demo tokens, not a general resolver. Extend the
# arrays below if the demo needs to show a different cascade mechanism.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESIGN_DATA_BIN="${DESIGN_DATA_BIN:-}"

if [[ -z "$DESIGN_DATA_BIN" ]]; then
  # Default: a sibling checkout of adobe/spectrum-design-data with the SDK built
  # (moon run sdk:build). Override with DESIGN_DATA_BIN=/path/to/design-data.
  DESIGN_DATA_BIN="$(command -v design-data || true)"
fi
if [[ -z "$DESIGN_DATA_BIN" || ! -x "$DESIGN_DATA_BIN" ]]; then
  echo "error: design-data CLI not found. Build it from a spectrum-design-data checkout" >&2
  echo "  (moon run sdk:build) and set DESIGN_DATA_BIN=/path/to/design-data, or put it on PATH." >&2
  exit 1
fi

export DESIGN_DATA_CACHE_DIR="$(mktemp -d)"
trap 'rm -rf "$DESIGN_DATA_CACHE_DIR"' EXIT

cd "$REPO_ROOT"

# Trigger the github-source fetch + cache (any resolve/query call does this),
# then locate the fetched foundation tokens dir for direct `query` calls below.
"$DESIGN_DATA_BIN" resolve color --format json >/dev/null
TOKENS_DIR="$(find "$DESIGN_DATA_CACHE_DIR" -maxdepth 8 -type d -path '*design-data/tokens' | head -1)"
if [[ -z "$TOKENS_DIR" ]]; then
  echo "error: could not locate fetched tokens dir under $DESIGN_DATA_CACHE_DIR" >&2
  exit 1
fi

query_by_uuid() {
  "$DESIGN_DATA_BIN" query "$TOKENS_DIR" --filter "uuid=$1" --format json
}

# --- override: manifest.json overrides this UUID's value to teal ---
override_record="$(query_by_uuid 9a727140-328d-430f-9b10-8965eebe77d1)"

# --- extension: net-new to the manifest, no foundation record exists under
#     this property name at all (see FINDINGS.md) ---
extension_record="$("$DESIGN_DATA_BIN" resolve accent-background-color --color-scheme light --format json)"

# --- foundation: plain, untouched palette swatch (blue-900, light) ---
foundation_record="$(query_by_uuid 3451c170-3e78-449b-86f2-8b7dbea24c1c)"

python3 - "$override_record" "$extension_record" "$foundation_record" <<'PY' > "$REPO_ROOT/consumer/resolved-tokens.json"
import json, sys

override = json.loads(sys.argv[1])[0]
extension = json.loads(sys.argv[2])
foundation = json.loads(sys.argv[3])[0]

def entry(record, provenance, label):
    return {"name": label, "value": record["value"], "provenance": provenance}

out = [
    entry(foundation, "foundation", "blue-900 (light)"),
    entry(override, "override", "seafoam-background-color-default (dark)"),
    entry(extension, "extension", "accent-background-color-default (light, contrast=high)"),
]
print(json.dumps(out, indent=2))
PY

echo "wrote $REPO_ROOT/consumer/resolved-tokens.json"
