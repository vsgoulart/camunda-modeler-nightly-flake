#!/usr/bin/env bash
set -euo pipefail

flake=flake.nix
attempts="${MAX_ATTEMPTS:-1}"
delay="${RETRY_DELAY_SECONDS:-600}"
base_url=https://downloads.camunda.cloud/release/camunda-modeler/nightly
linux=camunda-modeler-nightly-linux-x64.tar.gz
darwin=camunda-modeler-nightly-mac-arm64.dmg

[[ -f "$flake" ]] || { echo "Run from the repository root." >&2; exit 1; }

pinned_date="$(sed -nE 's/^ *version = "[^"]*-nightly\.([0-9]{4}-[0-9]{2}-[0-9]{2})";/\1/p' "$flake")"
[[ -n "$pinned_date" ]] || { echo "Could not read pinned nightly date from $flake." >&2; exit 1; }

publish_date() {
  local modified
  modified="$(curl -fsSIL "$base_url/$1" | sed -nE 's/^[Ll]ast-[Mm]odified: (.*)\r$/\1/p' | tail -n 1)"
  [[ -n "$modified" ]] || { echo "No Last-Modified header for $1." >&2; return 1; }
  perl -MTime::Piece -e 'print Time::Piece->strptime(shift, "%a, %d %b %Y %H:%M:%S GMT")->strftime("%Y-%m-%d")' "$modified"
}

for ((attempt = 1; attempt <= attempts; attempt++)); do
  linux_date="$(publish_date "$linux")"
  darwin_date="$(publish_date "$darwin")"
  date="$linux_date"
  [[ "$darwin_date" > "$date" ]] && date="$darwin_date"

  if [[ -n "${NIGHTLY_DATE:-}" ]]; then
    [[ "$linux_date" == "$NIGHTLY_DATE" && "$darwin_date" == "$NIGHTLY_DATE" ]] && break
    reason="expected $NIGHTLY_DATE"
  else
    [[ "$linux_date" > "$pinned_date" && "$darwin_date" > "$pinned_date" ]] && break
    reason="need both newer than pinned $pinned_date"
  fi

  echo "Nightly artifacts are not current (linux $linux_date, darwin $darwin_date; $reason)."
  ((attempt < attempts)) || exit 1
  echo "Retrying in $delay seconds."
  sleep "$delay"
done

linux_prefetch="$(nix store prefetch-file --json "$base_url/$linux")"
linux_hash="$(jq -r .hash <<<"$linux_prefetch")"
linux_path="$(jq -r .storePath <<<"$linux_prefetch")"
darwin_hash="$(nix store prefetch-file --json "$base_url/$darwin" | jq -r .hash)"
upstream_version="$(tar -xOf "$linux_path" camunda-modeler-nightly-linux-x64/VERSION)"
base_version="$(sed -nE 's/^v([^ ]+).*/\1/p' <<<"$upstream_version")"
[[ -n "$base_version" ]] || { echo "Could not parse version: $upstream_version" >&2; exit 1; }

version="$base_version-nightly.$date"
VERSION="$version" LINUX_HASH="$linux_hash" DARWIN_HASH="$darwin_hash" perl -0pi -e '
  s/version = "[^"]+";/version = "$ENV{VERSION}";/;
  s|(linux-x64\.tar\.gz";\n\s+hash = ")[^"]+";|$1$ENV{LINUX_HASH}";|;
  s|(mac-arm64\.dmg";\n\s+hash = ")[^"]+";|$1$ENV{DARWIN_HASH}";|;
' "$flake"

echo "Pinned Camunda Modeler $version."
