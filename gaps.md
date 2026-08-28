# iOS Override Import — Gap Report

## Known vocabulary gaps

- `elevated`/`elevatedIncreased` ColorSet slots: no foundation colorScheme or contrast mode maps to iOS's elevated surface concept (10 CSV rows skipped).
- `lightIncreased`/`darkIncreased` naming maps to `contrast:"high"` — modeled here, and now
  registered via `registry/platform-extensions/ios-contrast.json` (added to `manifest.json`'s
  `extensions.platformExtensions`), so the increased→high crosswalk is discoverable, not just
  implicit in the importer.
- `pressed`/`down` state terms: `pressed` is now a registered alias of the foundation `active`
  state (`packages/design-data/registry/states.json` upstream), with `down` cross-referenced via
  `relatedTerms` — no iOS-side platform-extension needed since `pressed` isn't iOS-specific
  vocabulary.
- Typography/size rows (`Scale(FontSize(...))`, 155 rows) are out of scope for this importer; see the follow-up bead for font-size/letter-spacing import.

The manifest spec has since grown a registered mechanism for exactly this kind of vocabulary
mismatch: `extensions.namingExceptions` (add/remove overlay on the base naming-exceptions
allowlist) and `extensions.platformExtensions` (already used here, in
`registry/platform-extensions/ios-states.json`, for the `pressed`/`down` state-term crosswalk
above). `manifest.json`'s `extensions.namingExceptions.add` now forward-declares three of the
unresolved slugs below (`switch-selected-emphasized-track-color`,
`switch-selected-not-emphasized-track-color`, `slider-track-disabled-background-fill-color`) as
known-irregular legacy names pending remediation — the same intent as the foundation's own
`naming-exceptions.json` allowlist, applied platform-locally. The `elevated`/`increased` and
`disabled`/`selected` rows below still have no foundation equivalent at all (a data gap, not a
naming-vocabulary one) and namingExceptions doesn't address that.

## Unresolved rows (14)

Rows whose target slug (or a specific colorScheme/contrast mode within it) has no foundation-token equivalent, so no manifest fragment was emitted.

### disabled-background-color

- Candidates tried: disabled-background-color
- Source: figma-tokens.json

### disabled-border-color

- Candidates tried: disabled-border-color
- Source: figma-tokens.json

### disabled-content-color

- Candidates tried: disabled-content-color
- Source: figma-tokens.json

### icon-color-primary-default

- Candidates tried: icon-color-primary-default (light), icon-color-primary-default (dark)
- Source: figma-tokens.json

### icon-color-seafoam-primary-default

- Candidates tried: icon-color-seafoam-primary-default (dark)
- Source: figma-tokens.json

### neutral-content-color-default

- Candidates tried: neutral-content-color-default (light), neutral-content-color-default (dark)
- Source: figma-tokens.json

### neutral-subdued-content-color-default

- Candidates tried: neutral-subdued-content-color-default (light), neutral-subdued-content-color-default (dark)
- Source: figma-tokens.json

### selected-background-color

- Candidates tried: selected-background-color
- Source: figma-tokens.json

### selected-border-color

- Candidates tried: selected-border-color
- Source: figma-tokens.json

### slider-text-disabled-content-color

- Candidates tried: slider-text-disabled-content-color, disabled-content-color
- Source: figma-tokens.json

### slider-track-disabled-background-color

- Candidates tried: slider-track-disabled-background-color, disabled-background-color
- Source: figma-tokens.json

### slider-track-disabled-background-fill-color

- Candidates tried: slider-track-disabled-background-fill-color, disabled-background-color
- Source: figma-tokens.json

### switch-selected-emphasized-track-color

- Candidates tried: switch-selected-emphasized-track-color
- Source: switch.json

### switch-selected-not-emphasized-track-color

- Candidates tried: switch-selected-not-emphasized-track-color
- Source: switch.json
