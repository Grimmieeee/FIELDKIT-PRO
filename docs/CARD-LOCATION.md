# Card location and breadcrumb

November 18, 2026 Pacific. Breadcrumb values are joined and HTML-escaped correctly. Closing a card keeps its last-viewed row gradient and green text; selecting another moves the marker. Active-card aria-pressed clears on close. Marker survives list redraws when its row is present; it is session-only, not reload persistence.

Actual renderer regression tests cover escaping and open/close/switch state. Existing search checks, bundle syntax and source preservation checks passed on both Sites sources. Chrome responsive interactions passed at 375px and 1100px; both themes checked at 375px, filtering and switching at 1100px. No new iOS Safari execution. All 272 records and embedded executable bytes unchanged. Dark default remains.
