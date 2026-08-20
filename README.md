<!-- Copyright 2026 Adobe. All rights reserved. -->
<!-- Licensed under the Apache License, Version 2.0 (the "License"). -->

# spectrum-ios-design-data

A **proof-of-concept, non-production** consumer of the
[Spectrum design-data](https://github.com/adobe/spectrum-design-data) Platform Manifest model,
standing in for how Spectrum iOS could adopt the cascade.

This repo is a standalone **in-system consumer**: its `.design-data.toml` pins the
`adobe/spectrum-design-data` foundation dataset via the `github` source (a release tarball fetched
over pure HTTPS — no Node, no git binary) and cascades a local Layer-2 `manifest.json` on top. That
is exactly the shape the source-config redesign in
[adobe/spectrum-design-data#1353](https://github.com/adobe/spectrum-design-data/pull/1353) enables.

> **Not production.** This is a personal POC sandbox, not an `adobe/`-org starter repo. It exists to
> validate the manifest+cascade model against a real platform's real override log before broader
> adoption work. See [`FINDINGS.md`](./FINDINGS.md) for the full writeup and the gaps it surfaced.

## Contents

| File                | What it is                                                                        |
| ------------------- | -------------------------------------------------------------------------------- |
| `.design-data.toml` | Pins the foundation (`github` source, tag `@adobe/spectrum-tokens@15.0.0`) + top-level `manifest`. |
| `manifest.json`     | A real iOS Layer-2 manifest: `foundationVersion`, `include`/`exclude`, typed `overrides`, `extensions.tokens`. |
| `FINDINGS.md`       | What was tested, what worked, and the model's real gaps (tracked as beads in the source repo). |

## Running it

The `design-data` CLI is not published to a package registry, so build it from a checkout of the
foundation repo:

```sh
git clone https://github.com/adobe/spectrum-design-data
cd spectrum-design-data && moon run sdk:build   # produces the design-data CLI (fetch feature on)
```

Then, from the root of **this** repo:

```sh
# The first run fetches + caches the release tarball. Point the cache at a scratch dir so
# nothing lands in the repo.
export DESIGN_DATA_CACHE_DIR=$(mktemp -d)
design-data resolve color   # File: manifest.json  → the manifest cascades over the github source
```

See [`FINDINGS.md` § Reproducing](./FINDINGS.md#reproducing) for the full command set and the
expected counts (and why `query` takes an explicit tokens path rather than `.`).

## License

Apache-2.0. Token values and manifest data are derived from Spectrum design data
(© Adobe); see [`LICENSE`](./LICENSE).
