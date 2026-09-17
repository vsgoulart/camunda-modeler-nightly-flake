#!/usr/bin/env bash
set -euo pipefail

flake=flake.nix
date="${NIGHTLY_DATE:-$(date -u +%F)}"
http_date="$(perl -MTime::Piece -e 'print Time::Piece->strptime(shift, "%Y-%m-%d")->strftime("%d %b %Y")' "$date")"
attempts="${MAX_ATTEMPTS:-1}"
delay="${RETRY_DELAY_SECONDS:-600}"
base_url=https://downloads.camunda.cloud/release/camunda-modeler/nightly
linux=camunda-modeler-nightly-linux-x64.tar.gz
darwin=camunda-modeler-nightly-mac-arm64.dmg

[[ -f "$flake" ]] || { echo "Run from the repository root." >&2; exit 1; }

for ((attempt = 1; attempt <= attempts; attempt++)); do
  current=true
  for artifact in "$linux" "$darwin"; do
    modified="$(curl -fsSIL "$base_url/$artifact" | sed -nE 's/^[Ll]ast-[Mm]odified: (.*)\r$/\1/p' | tail -n 1)"
    [[ "$modified" == *"$http_date"* ]] || current=false
  done

  $current && break
  ((attempt < attempts)) || { echo "Not all nightly artifacts were published on $date." >&2; exit 1; }
  echo "Nightly artifacts are not current; retrying in $delay seconds."
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
