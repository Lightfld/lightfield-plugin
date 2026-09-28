#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 <platform> [output-directory]" >&2
  echo "Available platforms are the directories under platforms/." >&2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 64
fi

platform="$1"
if [[ ! "$platform" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "Invalid platform name: $platform" >&2
  exit 64
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
spec_path="$repo_root/platforms/$platform/package-spec.json"
output_dir="${2:-$repo_root/dist}"

if [[ ! -f "$spec_path" ]]; then
  echo "Unknown platform: $platform" >&2
  usage
  exit 64
fi

read_spec_field() {
  python3 - "$spec_path" "$1" <<'PY'
import json
import pathlib
import sys

spec_path = pathlib.Path(sys.argv[1])
field = sys.argv[2]
with spec_path.open(encoding="utf-8") as file:
    spec = json.load(file)

value = spec.get(field)
if field == "include":
    if not isinstance(value, list) or not value:
        raise SystemExit(f"Missing include paths in {spec_path}")
    if not all(isinstance(path, str) and path for path in value):
        raise SystemExit(f"Invalid include path in {spec_path}")
    print(*value, sep="\n")
elif not isinstance(value, str) or not value:
    raise SystemExit(f"Missing {field} in {spec_path}")
else:
    print(value)
PY
}

artifact_name="$(read_spec_field artifactName)"
version_manifest="$(read_spec_field versionManifest)"
include_output="$(read_spec_field include)"
includes=()
while IFS= read -r source; do
  includes+=("$source")
done < <(printf '%s\n' "$include_output")

if [[ ! "$artifact_name" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "Invalid artifact name for $platform: $artifact_name" >&2
  exit 65
fi

validate_relative_path() {
  local path="$1"
  case "$path" in
    /*|..|../*|*/../*|*/..)
      echo "Unsafe package path for $platform: $path" >&2
      exit 65
      ;;
  esac
}

validate_relative_path "$version_manifest"
if [[ ! -f "$repo_root/$version_manifest" ]]; then
  echo "Missing version manifest for $platform: $version_manifest" >&2
  exit 66
fi

version="$(python3 - "$repo_root/$version_manifest" <<'PY'
import json
import pathlib
import sys

manifest = pathlib.Path(sys.argv[1])
with manifest.open(encoding="utf-8") as file:
    value = json.load(file).get("version")
if not isinstance(value, str) or not value:
    raise SystemExit(f"Missing top-level version in {manifest}")
print(value)
PY
)"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid package version for $platform: $version" >&2
  exit 65
fi

stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/lightfield-plugin.XXXXXX")"
cleanup() {
  rm -rf -- "$stage_dir"
}
trap cleanup EXIT

for source in "${includes[@]}"; do
  validate_relative_path "$source"
  if [[ ! -e "$repo_root/$source" ]]; then
    echo "Missing package path for $platform: $source" >&2
    exit 66
  fi

  mkdir -p "$stage_dir/$(dirname "$source")"
  cp -R "$repo_root/$source" "$stage_dir/$source"
done

# Stable timestamps make identical source trees produce identical archives.
find "$stage_dir" -exec touch -t 198001010000 {} +

mkdir -p "$output_dir"
archive_name="$artifact_name-$version.zip"
temporary_archive="$stage_dir/$archive_name"
archive_path="$output_dir/$archive_name"

(
  cd "$stage_dir"
  zip -X -q -r "$temporary_archive" "${includes[@]}"
)

unzip -tq "$temporary_archive" >/dev/null
mv -f "$temporary_archive" "$archive_path"

echo "$archive_path"
