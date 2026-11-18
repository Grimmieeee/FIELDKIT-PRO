# Tap target update

November 18, 2026 Pacific. Prior release: catalog v262 / entry v94.

Header icon controls now use actual 44 by 44 CSS-pixel boxes on all widths. The logo home link has a 44px minimum height. Catalog rows, category options, sort options and Related Items rows have 44px minimum heights. Existing icon drawings remain 18px; type, colors, chevrons, borders and gradients remain unchanged. No pseudo-element hit expansion, absolute overlays or negative-margin hit areas.

On widths at or below 414px the five header controls wrap to a second row, retaining the full wordmark and non-overlapping 44px boxes. Header height becomes 96px and the content-height calculation is adjusted by the same 36px. Wider screens retain the one-line header. At or below 480px compact 8px side padding and 2px gaps make the single-row layout fit where possible.

## Validation

Observed Chrome DOM geometry at 320, 375, 390, 414, 430, 480, 768 and 1280px, each in dark and light: every header icon is 44 by 44; catalog row minimum is 44; no pair of header controls/logo overlaps; glyphs remain 18 by 18. At 375, 430 and 1280px in both themes, opened category/sort menus and the Show Mailbox Usage card: category rows, sort rows and Related Items rows all measure at least 44px. Header mid-edge hit probes resolve to their controls at all eight widths. Menu selection, search, card opening/closing and theme toggling were exercised in these checks.

Raw geometry and the initial rounded-corner probe limitation: qa/tap-targets/chrome-measurements.json. Screenshot: qa/tap-targets/375px-header.jpg. Screenshot is Chrome responsive layout evidence, not an iOS capture.

**iOS Safari verification: NOT RUN.** This environment exposes Linux/Chrome only; no Apple device, iOS simulator or Safari session is available. Do not mark iOS accepted from responsive Chromium measurements. A remaining device check should cover header taps, menu scrolling/selection, result/card opening, dark/light mode and landscape.

Both catalogs, embedded scripts and application JavaScript remain byte-identical to the prior release. The change is CSS only, plus documentation/evidence and the rebuilt serving bundle. Existing search checks and bundle syntax checks are run on each release source.

Homepage SHA-256: `4b0a2de647f0d0e444fbf80fd7eeec4d4cfff145c1383fffee6f83f1e5f330f1`. Immediate rollback: v262. Final source/version/deployment pins are in the GitHub Project Summary.
