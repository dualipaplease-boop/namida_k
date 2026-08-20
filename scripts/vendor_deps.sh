#!/usr/bin/env bash
# Vendors the 4 private deps into this repo and points pubspec.yaml at them.
# Usage: bash scripts/vendor_deps.sh
# Expects sources at /tmp/opencode/{youtipie,namico_subscription_manager,namico_login_manager,basic_audio_handler}
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC=/tmp/opencode
DEPS=(youtipie namico_subscription_manager namico_login_manager basic_audio_handler)

for d in "${DEPS[@]}"; do
  if [ ! -f "$SRC/$d/pubspec.yaml" ]; then
    echo "MISSING: $SRC/$d/pubspec.yaml"
    exit 1
  fi
done

rm -rf "$ROOT/vendor"
mkdir -p "$ROOT/vendor"
for d in "${DEPS[@]}"; do
  cp -r "$SRC/$d" "$ROOT/vendor/$d"
  rm -rf "$ROOT/vendor/$d/.git"
  echo "vendored: $d"
done

# Rewrite the 4 git deps to local path deps in pubspec.yaml
python3 - "$ROOT/pubspec.yaml" <<'PY'
import sys, re
path = sys.argv[1]
with open(path) as f:
    src = f.read()
for d in ["youtipie", "namico_login_manager", "namico_subscription_manager", "basic_audio_handler"]:
    src = re.sub(
        r"(\n  " + re.escape(d) + r":\n(?:    [^\n]+\n)+?)(  [a-z_]+:)",
        lambda m: f"\n  {d}:\n    path: vendor/{d}\n" + m.group(2),
        src, count=1,
    )
with open(path, "w") as f:
    f.write(src)
print("pubspec.yaml updated")
PY

cd "$ROOT"
git add vendor pubspec.yaml
git commit -m "vendor: add youtipie, namico_login_manager, namico_subscription_manager, basic_audio_handler as path deps"
git push namida-k main
git push namida-k option-b-remove-gate
echo "DONE - vendor committed and pushed. Trigger the build_apks workflow on GitHub Actions."