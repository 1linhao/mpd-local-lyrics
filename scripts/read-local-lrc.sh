#!/usr/bin/env bash
set -euo pipefail

music_dir=${1:-"$HOME/Music"}
extensions=${2:-".lrc,.LRC"}
track_url=${3:-}
track_title=${4:-}

expand_path() {
  case "$1" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s\n' "$HOME/${1#~/}" ;;
    '$HOME'*) printf '%s\n' "$HOME${1#\$HOME}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

uri_to_path() {
  python3 - "$1" <<'PY'
import sys
from urllib.parse import unquote, urlparse

uri = sys.argv[1]
if uri.startswith("file://"):
    parsed = urlparse(uri)
    print(unquote(parsed.path))
elif uri and "://" not in uri:
    print(unquote(uri))
PY
}

music_dir=$(expand_path "$music_dir")

IFS=',' read -r -a ext_list <<< "$extensions"
for i in "${!ext_list[@]}"; do
  ext=${ext_list[$i]//[[:space:]]/}
  [[ -z "$ext" ]] && ext=".lrc"
  [[ "$ext" == .* ]] || ext=".$ext"
  ext_list[$i]=$ext
done

declare -a audio_candidates=()

if [[ -n "$track_url" ]]; then
  url_path=$(uri_to_path "$track_url" || true)
  if [[ -n "${url_path:-}" ]]; then
    if [[ "$url_path" = /* ]]; then
      audio_candidates+=("$url_path")
    else
      audio_candidates+=("$music_dir/$url_path")
    fi
  fi
fi

if command -v mpc >/dev/null 2>&1; then
  mpc_file=$(mpc --format '%file%' current 2>/dev/null || true)
  if [[ -n "$mpc_file" ]]; then
    if [[ "$mpc_file" = /* ]]; then
      audio_candidates+=("$mpc_file")
    else
      audio_candidates+=("$music_dir/$mpc_file")
    fi
  fi
fi

for audio in "${audio_candidates[@]}"; do
  base=${audio%.*}
  for ext in "${ext_list[@]}"; do
    lyric="${base}${ext}"
    if [[ -f "$lyric" ]]; then
      cat "$lyric"
      exit 0
    fi
  done
done

if [[ -n "$track_title" && -d "$music_dir" ]]; then
  for ext in "${ext_list[@]}"; do
    lyric=$(find "$music_dir" -type f -name "${track_title}${ext}" -print -quit 2>/dev/null || true)
    if [[ -n "$lyric" && -f "$lyric" ]]; then
      cat "$lyric"
      exit 0
    fi
  done
fi

exit 1
