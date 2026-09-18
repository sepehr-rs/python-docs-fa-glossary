#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-8000}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if ! command -v entr >/dev/null 2>&1; then
  echo "‘entr’ not found. Install it with:"
  echo "  macOS:  brew install entr"
  echo "  Debian/Ubuntu: sudo apt install entr"
  exit 1
fi

if [ ! -f data/glossary.json ] || [ ! -f data/corpus.json ]; then
  echo "data/glossary.json or data/corpus.json missing — building corpus first..."

  if [ ! -d python-docs-fa ]; then
    git clone --depth 1 https://github.com/python/python-docs-fa.git python-docs-fa
  fi

  python3 -m pip show polib >/dev/null 2>&1 || python3 -m pip install --quiet polib

  python3 scripts/build_corpus.py \
    --repo-dir python-docs-fa \
    --glossary-tsv glossary/glossary.tsv \
    --out-dir data
fi

python3 scripts/build_site.py \
  --site-dir site \
  --data-dir data \
  --out-dir dist


( cd dist && python3 -m http.server "$PORT" ) &
SERVER_PID=$!
trap 'kill $SERVER_PID' EXIT

echo "Serving http://localhost:${PORT} — watching site/ and data/ for changes..."

find site data -type f | entr -r python3 scripts/build_site.py \
  --site-dir site \
  --data-dir data \
  --out-dir dist