# Camunda Modeler Nightly Flake

A Nix flake providing the latest nightly build of
[Camunda Modeler](https://github.com/camunda/camunda-modeler).

## Run

```console
nix run github:vsgoulart/camunda-modeler-nightly-flake
```

## Install

```console
nix profile install github:vsgoulart/camunda-modeler-nightly-flake
```

The package supports `x86_64-linux` and Apple Silicon (`aarch64-darwin`).

## Updates

Camunda starts its nightly build at 18:00 UTC. The update workflow runs daily
at 19:00 UTC, waits for a delayed upload when necessary, verifies the artifact
date, updates its fixed-output hash and version, builds the package, and commits
the result. Both the Linux archive and macOS arm64 DMG must build successfully.

To update a local checkout manually:

```console
bash scripts/update.sh
nix build
```

The upstream URL is mutable. Each repository revision pins the expected archive
by SHA-256, which prevents an unnoticed replacement, but older revisions may
need a Nix cache after Camunda replaces the upstream file.
