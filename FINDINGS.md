<!-- Copyright 2026 Adobe. All rights reserved. -->

<!-- Licensed under the Apache License, Version 2.0 (the "License");           -->

<!-- you may not use this file except in compliance with the License. You may -->

<!-- obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0 -->

<!-- Unless required by applicable law or agreed to in writing, software       -->

<!-- distributed under the License is distributed on an "AS IS" BASIS,        -->

<!-- WITHOUT WARRANTIES OR REPRESENTATIONS OF ANY KIND, either express or     -->

<!-- implied. See the License for the specific language governing permissions -->

<!-- and limitations under the License.                                        -->

# Spectrum iOS platform manifest — POC findings

**Status:** proof of concept, **not production**. Tracks bd `spectrum-design-data-284.10`
/ `spectrum-design-data-7mt.3` (Aug 28 2026 milestone, "cascade proven on iOS first").

**Goal:** validate the [Platform Manifest spec](../../../packages/design-data-spec/spec/manifest.md)
(draft `1.0.0-draft`) against a real platform, using real data from Spectrum iOS's actual token
package (`spectrum-tokens-ios`, not fabricated), before extending the model to Android.

The manifest+cascade engine this POC exercises already exists and is not part of this deliverable:
`TokenGraph::apply_platform_manifest` (`sdk/core/src/graph.rs:737`), `manifest::apply_configured`
(`sdk/core/src/manifest.rs`), `cascade.rs` resolution. This POC is data + a validation writeup.

## What's here

* **`manifest.json`** — a real iOS Layer-2 manifest: `foundationVersion` pin, `include`/`exclude`
  query filters, three typed `overrides`, `extensions.tokens` (net-new + contrast-mode tokens),
  and an `extensions.components` entry for `tab-bar-ios`.
* **`.design-data.toml`** — `type = "github"`, pinned to `@adobe/spectrum-tokens@15.1.0`, with a
  **top-level `manifest` key** that cascades on top of the remotely-fetched foundation. This is the
  original intent, now functional: the POC surfaced gap #0 (the manifest cascade only applied to a
  `type = "path"` source), which was then fixed in `sdk/core` — see gap #0 below for the fix and the
  source-strategy rationale.
* **`components/tab-bar-ios.json`** — standalone component spec backing the manifest's
  `extensions.components` entry.
* **`registry/platform-extensions/ios-states.json`** — iOS-specific state registry used by the
  overrides/extensions above.
* This document — what was tested, what worked, and where the model has real gaps.

## Grounding: what real Spectrum iOS actually does

Source: `spectrum-tokens-ios` (`~/Spectrum/spectrum-tokens-ios` in this environment), which pins
`@adobe/spectrum-tokens@13.0.0` and ships `ios-tokens/override-log.csv` — a real log of **742**
overrides applied on top of the foundation token set. Classifying those 742 rows by shape:

| Category                         | Count | Shape                                                                        |
| -------------------------------- | ----- | ---------------------------------------------------------------------------- |
| Net-new tokens ("Custom token")  | 177   | Foundation has no equivalent at all                                          |
| Contrast/elevated-only additions | 399   | `light`/`dark` unchanged; `lightIncreased`/`darkIncreased`/`elevated*` added |
| True value changes               | 11    | `light`/`dark` base values actually replaced                                 |
| Typography / other               | 155   | `font-size.json`, `letter-spacing.json`, component files, etc.               |

**The dominant iOS override pattern (399 of 742, \~54%) is adding increased-contrast color
variants** — not changing existing values. That's the central thing this POC needed to test against
the manifest model, because:

Foundation defines a `contrast` mode set (`packages/design-data/mode-sets/contrast.json`, modes
`["regular", "high"]`) but **ships zero tokens with a `high` value** — every foundation color token
that has a `contrast` field simply... doesn't have one; `high` falls back to the `regular` default.
So "add the high-contrast variant iOS actually ships" cannot be represented as a *value replacement*
of an existing token — there is no existing `contrast=high` record to target. It has to be new data.

## Manifest content, and why

* **`foundationVersion`**: pinned to `@adobe/spectrum-tokens@15.1.0` — the current dataset, not
  iOS's real `13.0.0`. `13.0.0` predates the cascade token format entirely (structured `name`
  objects, mode sets, UUIDs); a manifest against it isn't meaningful. **This version gap is itself
  a finding** — see [Gaps](#gaps-found) below.
* **`include`**: the token `property` families iOS's generated Swift sources actually cover
  (`color`, `size`, `line-height`, `font-weight`, `font-family`, `text-align`, `corner-radius`,
  `border-width`, `opacity`, `background-color`) — verified present in
  `packages/design-data/tokens/*.tokens.json` before use; not guessed.
* **`exclude`**: `colorScheme=wireframe` — iOS ships only light/dark (+ increased-contrast
  variants); the design-tool-only `wireframe` scheme (460 color tokens) is real overhead it never
  consumes.
* **`overrides`**: three of the 11 real "true value change" rows — the accent-color tokens
  targeted **by UUID** (`736e4768-…`, `9a727140-…`, `df8f47d4-…`) — each replacing the
  resolved literal color with iOS's actual teal value (`rgba(9, 144, 120, 1.0)`).
* **`extensions.tokens`**: one representative net-new token (`accent-background-color-pressed`,
  a real "Custom token" row, light+dark) plus the `contrast=high` variants of
  `accent-background-color-default` (light+dark) — using the increased-contrast values from the
  real override log. This is the concrete resolution of the central question above: **increased-
  contrast values belong in `extensions`, not `overrides`**, because there is no existing record to
  override.
* **`extensions.components`** *(new)*: the full `tab-bar-ios` component definition
  (`components/tab-bar-ios.json`), exercising the same extension mechanism for platform-local
  component specs, not just tokens.
* **`extensions.formatting`**: `casing: camelCase`, matching iOS's real Swift symbol style
  (`accentBackgroundColorDefault`). Left minimal — see gaps.
* **`extensions.relationships`** *(new — exercises #1389)*: one CTR linking the `tab-bar-ios`
  component's `background-color` property, in its "Selected tab background" context, to the
  same accent-color foundation token this manifest already overrides to teal
  (`736e4768-…`) — reuses a target already proven resolvable elsewhere in this manifest rather
  than inventing a new one.
* **`extensions.guidelines`** *(new — exercises #1387)*: one guideline (`tab-bar-ios`, category
  `developing`) carrying the component's own description and `documentationUrl` as its `purpose`
  block — matches `guideline.schema.json`'s required shape.
* **`extensions.namingExceptions`** *(new — exercises #1390)*: `add` forward-declares three
  legacy slugs from `gaps.md`'s unresolved-rows list
  (`switch-selected-emphasized-track-color`, `switch-selected-not-emphasized-track-color`,
  `slider-track-disabled-background-fill-color`) as known-irregular names pending remediation —
  see `gaps.md` for the full cross-reference.
* **`extensions.fields`** *(exercises #1388 — skipped)*: no real iOS-specific field concept
  surfaced from this override log to ground a field declaration in. The SDK's own test fixture
  for this extension type (`hapticStyle`, `sdk/core/src/manifest.rs:300`) is illustrative but not
  drawn from iOS's actual data, so it's left out here rather than fabricated. Revisit if a real
  need surfaces (e.g. from the font-size/letter-spacing importer follow-up).

## What was verified (commands run against real fetched/local data)

All runs used the CLI built from this repo (`cargo build -p design-data-cli`, `fetch` feature is
on by default for the CLI binary).

**1. Remote pin + manifest cascade compose end-to-end.** With `.design-data.toml` at
`type = "github"` (tag `@adobe/spectrum-tokens@15.1.0`) and a **top-level** `manifest` key, the CLI
downloads and caches the tagged release tarball (pure HTTPS, no Node/git binary — the tarball ships
the full dataset including `packages/tokens/schemas/**`), then applies the manifest on top of the
fetched foundation. `query --filter "property=color" --count` against the fetched dataset returns
the manifest-filtered **1136** (not the unfiltered baseline 1587), `resolve color` reports
`File: manifest.json` for extension tokens, and overrides/extensions materialize (items 2–4 below,
re-verified against the `github` source). This is the resolution of gap #0: the manifest used to
apply only to a `type = "path"` source. See [Gaps](#gaps-found) #0 for the fix.

**2. Filtering works.** `query --filter "property=color"` returns 1587 without a manifest configured;
with this manifest's `exclude: ["colorScheme=wireframe"]` applied, it drops to 1136 — the wireframe-
scheme color tokens are correctly removed.

**3. Extensions materialize and are queryable.** `query --filter "property=color,state=pressed"`
with the manifest configured returns exactly the 2 net-new `accent-background-color-pressed`
records (light/dark) from `extensions.tokens`; `query --filter "property=color,contrast=high"`
returns exactly the 2 `contrast=high` records. Neither exists in the foundation set.

**4. Overrides land as new Platform-layer records, not in-place replacements.** After adding the
three UUID-targeted accent-color overrides, the query count for the targeted selector goes up
by 3 — the original foundation records (untouched) are still present, **plus** 3 new synthetic
records carrying the override's literal teal value. `query` shows the full graph across all
layers; only `resolve()` / `resolve_property()` apply `Foundation < Platform < Product`
precedence to pick a single winner. This is a genuine, useful distinction to document for
anyone using `query` output to "count what a platform ships" — it will double-count overridden
tokens unless you know to resolve, not just query. (This is now also documented in the
manifest spec's `overrides` section, `packages/design-data-spec/spec/manifest.md` in the
`adobe/spectrum-design-data` repo.)

**5. Manifest re-validates clean under the stricter post-fix rules.** After #1365 and #1376
landed, `design-data validate-manifest` (added by #1367) still reports `manifest.json is valid` —
all 1118 `extensions.tokens` entries pass the new schema check, and both alias-targeted overrides
pass the now-complete type-safety check. This POC's data holds up; nothing here needed repair.

## Gaps found (worth raising before Nov 20 adoption work)

0. **RESOLVED — manifest hoisted to a top-level, source-independent config key; `github` source
   accepts tag/branch/sha.** As originally found, the manifest cascade only applied to a
   `type = "path"` source: `SourceConfig::Path` was the *only* variant with a `manifest` field, and
   because `SourceConfig` had no `deny_unknown_fields`, `manifest = "..."` under `type = "github"`
   was silently dropped, leaving `ResolvedData::platform_manifest = None` and
   `manifest::apply_configured` a permanent no-op. Fixed in `sdk/core`:

   * **Hoisted `manifest` to the top level of `DesignDataConfig`** (`data_source/mod.rs`) — it's a
     local, platform-authored file, orthogonal to where the *foundation* comes from, so coupling it
     to one source variant was the root cause. It now cascades over **any** source (path, github,
     even the embedded/probed default). `#[serde(deny_unknown_fields)]` on both `DesignDataConfig`
     and `SourceConfig` makes a misplaced key error loudly instead of vanishing.
   * **Extended the `github` source to pin by `tag`, `branch`, or `sha`** (`data_source/fetch.rs`) —
     GitHub serves an archive tarball for any ref (`/archive/refs/tags/{tag}`,
     `/archive/refs/heads/{branch}`, `/archive/{sha}`), so "track a branch/directory of the
     foundation repo" needs **no `gix`, no git binary, no new dependency**. Branch pins (mutable)
     bypass the `.complete` sentinel and refetch each run; tag/sha (immutable) keep the fast path.

   **Source-strategy rationale (github vs npm vs git — the question this fix answered):** the
   constraint was that npm effectively requires Node, which many iOS/Android devs lack. But fetching
   is HTTPS either way — the real differentiator is *dataset completeness*. The legacy
   `@adobe/spectrum-tokens` npm tarball ships tokens only (no schema catalog); `@adobe/spectrum-
   design-data` ships tokens/components/fields/mode-sets/guidelines but **not** `schemas/`. The
   **GitHub release tarball ships everything over pure HTTPS with no Node and no git binary**, and
   now supports tag/branch/sha — so it strictly dominates npm for the cascade. `npm` and `git`
   remain stubbed, with errors that point at `type = "github"`; a real `gix` `git` source (for
   non-GitHub hosts) is YAGNI here.
1. **RESOLVED — override targets by legacy slug no longer silently no-op.** The manifest schema's
   `target` field is documented as "enough information to identify the target token," but
   `resolve_override_targets` (`sdk/core/src/graph.rs:903`) originally fell back to a direct key
   lookup against the graph's internal key, **not** the `legacy_name_index` that maps human-readable
   legacy slugs (`disabled-background-color`) to that key — so targeting by the plain legacy name
   failed with no error and no effect. **Fixed by #1356** (`fix(sdk): resolve override targets by
   legacy slug`): override target resolution now reuses `resolve_alias_key`, preserving the
   UUID → graph key → legacy-name resolution chain, so legacy-slug targets like `blue-100` resolve
   correctly. A platform author can now hand-author a manifest straight from a legacy-named override
   log without pre-resolving every target to a UUID.
2. **RESOLVED — type-safety guard now covers alias-only targets.** Cascade type-safety
   ("overrides MUST NOT change resolved type") was enforced in `graph.rs:790-798` only when the
   *matched foundation record itself* carried a literal `"value"` field to compare against; both
   override targets here are pure `$ref` aliases with no `"value"` field, so `orig_value` was `None`
   and the check was skipped unconditionally — an override with `"value": 42` (number) against an
   alias-typed UUID applied with no error. Alias-typed tokens are the large majority of the color
   corpus, so this covered most real overrides, not an edge case. **Fixed by #1365**
   (`fix(sdk): enforce cascade type-safety on alias-only override targets`) — type-safety now
   resolves the alias chain to its underlying value type before comparing, closing the gap for the
   majority of the corpus this manifest actually targets.
3. **Foundation version pin predates the cascade format.** iOS's real, current pin
   (`@adobe/spectrum-tokens@13.0.0`) has no `packages/design-data/*` cascade dataset at all — it's
   pre-cascade legacy format. A real adoption manifest can't target that tag; iOS would need to
   move its pin forward to a cascade-format release (`15.0.0`+) as a prerequisite, independent of
   the manifest work itself.
4. **RESOLVED — `extensions.tokens` is now schema-validated.** `manifest.schema.json`'s
   `extensions` property originally only declared `formatting`; everything else (including
   `tokens`) was accepted purely via `additionalProperties: true` — no shape validation before
   `apply_platform_manifest` consumed it, so a malformed extension token (bad `$schema`, missing
   `name` fields) would fail silently or downstream, not at manifest-validation time.
   **Fixed by #1376** (`fix(sdk): schema-validate extensions.tokens in platform manifest`):
   `extensions.tokens` entries are now validated against the token-type schemas at manifest-apply
   time. All 1118 `extensions.tokens` entries in this manifest re-validate clean under the stricter
   check (see Verdict).
5. **`extensions.formatting` is under-specified for iOS's actual naming.** Real iOS Swift symbols
   (`accentBackgroundColorDefault`) don't map cleanly from foundation's structured `name` object via
   `conceptOrder`/`casing`/`delimiter`/`abbreviations` alone — iOS's actual generator
   (`Tools/tokentool`) does custom Swift codegen, not driven by this taxonomy today. Reconciling the
   two is unscoped follow-up work, not blocking for this POC.
6. **`npm`/`git` sources are deliberately unimplemented** — not a gap. The published npm tarballs
   are dataset-incomplete for the cascade and the `github` source now covers tag/branch/sha over
   pure HTTPS; both stubs error with a pointer to `type = "github"`. See gap #0's source-strategy
   note for the full rationale.
7. **RESOLVED — `query`/`resolve` now honor `.design-data.toml`'s `[source]` root when the
   positional `PATH` is omitted.** `run_query` and `run_resolve` computed catalog paths via
   `data_source::resolve()` but loaded the token dataset from the raw CLI `PATH` arg (defaulting to
   `"."`), so a `[source]` block never actually took effect for these commands — passing `.` inside
   a manifest's directory would silently load whatever `*.json` files happened to sit under the
   literal cwd (this repo hit that directly: a stray fetched-tarball cache once produced a
   plausible-looking but coincidental result). **Fixed by #1360**
   (`fix(sdk): load query/resolve/legacy-output-cascaded tokens from resolved source`): both
   commands now thread the optional `PATH` into `CliPathOverrides` and load from
   `resolved.tokens_root` when no explicit path is given, matching the pattern `primer`/
   `cache-build` already used (a regression suite in `sdk/cli/tests/cli_source.rs` covers all three
   commands run with no positional arg against a configured source). Running `design-data query`
   with no path from inside this repo now resolves the configured `github` source correctly; the
   explicit `$TOKENS` workaround in **Reproducing** below is no longer required (passing `.`
   explicitly is still the footgun this gap described — omit the path instead).
   Note: `validate-dataset`'s cwd-relative scope is a separate, intentional design choice, not part
   of this fix.

## Verdict

The manifest model — pin, filter, override, extend — **holds up against a real platform's real
override log**, and the cascade pieces (query filtering, overrides, extensions) work exactly as
documented. **Remote pinning now composes with the manifest cascade** (gap #0, fixed here): a
`github`-pinned foundation + a top-level `manifest` key filters, overrides, and extends end-to-end,
so the locked-in "use existing GitHub source" scoping decision is deliverable. The next tier of
gaps this POC surfaced — #1 (legacy-slug override targeting), #2 (type-safety on alias targets),
#4 (`extensions.tokens` schema validation), and #7 (`query`/`resolve` source resolution) — have
since all been fixed upstream (#1356, #1365, #1376, #1360 respectively; see each gap above), and
the manifest re-validates clean under the stricter rules. Remaining recommendation: repeat this
exercise for Android to confirm the model (not just this one engine implementation) generalizes.

## Real consumer

Everything above proves the cascade JSON-to-JSON — a manifest cascading over a fetched
foundation resolves correctly, but nothing consumed that output as real platform code. `consumer/`
closes that gap: a minimal Swift executable (`consumer/generate.sh` + `swift run spectrum-demo`)
reads resolved cascade output and renders it as truecolor terminal swatches — one foundation
color, one of the three overrides (teal, visibly distinct from the foundation blue it sits on
top of), and one `contrast=high` extension token. The cascade now reaches a rendered pixel, not
just a JSON diff.

**Android** is not built in this pass. The manifest/cascade engine
(`TokenGraph::apply_platform_manifest`, `sdk/core/src/graph.rs`) is platform-agnostic — it
consumes the same `manifest.json` and emits the same `resolve`/`query --format json` output
regardless of consumer. An Android consumer would read that identical JSON; the only new work
is the rendering side (Kotlin instead of Swift), not the cascade model. This iOS consumer is
sufficient to demonstrate the model; Android is a codegen-target swap, not a model change,
tracked separately if adoption work proceeds.

## Reproducing

```sh
# Run from the root of this repo (where .design-data.toml and manifest.json live).
# .design-data.toml here uses `type = "github"` (tag @adobe/spectrum-tokens@15.1.0) with a
# top-level `manifest` key. The first run fetches + caches the release tarball (pure HTTPS);
# set DESIGN_DATA_CACHE_DIR to a scratch dir so nothing lands in the repo.
export DESIGN_DATA_CACHE_DIR=$(mktemp -d)
design-data resolve color   # File: manifest.json  → confirms the manifest cascades over the github source

# `query`/`resolve` now honor `.design-data.toml`'s `[source]` root when PATH is omitted (gap #7,
# fixed by #1360) — no need to pass the fetched tokens dir explicitly anymore. Still avoid passing
# "." explicitly (that footgun is what gap #7 originally described); just omit the path.
design-data query --filter "property=color" --count                       # 1136 (1587 without the manifest's exclude)
design-data query --filter "property=color,state=pressed" --count         # extensions: 2 net-new contrast/pressed tokens
design-data query --filter "property=color,contrast=high" --count         # extensions: 2 contrast-mode tokens
design-data query --filter "property=color,state=disabled" --count        # overrides: 7 → 9 (see item 4)
design-data validate-manifest                                             # manifest.json is valid (post-#1365/#1376 rules)
```

(`design-data` = the `design-data-cli` binary built from `sdk/`, `moon run sdk:build`.)
