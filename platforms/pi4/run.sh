#!/bin/bash
# Start the EYESY video engine on a Raspberry Pi 4 using the repo's venv.
# Stop with Esc in the EYESY window, or Ctrl+C here.

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
PY="$REPO/.venv/bin/python"

if [ ! -x "$PY" ]; then
    echo "No venv at $REPO/.venv, see platforms/pi4/README.md (Setup)."
    exit 1
fi

# main.py loads font.ttf by relative path, so run from engines/python
cd "$REPO/engines/python" || exit 1
exec "$PY" -u main.py "$@"
