# Supplement History — Design

## Problem

Alcohol History (`alcohol-history.html`) gives a day-by-day view of past
drinking. Supplements have no equivalent: `supplement_log` records which
tablets were taken/not-taken (plus optional quantity) per day, but there's
no page to see what was actually consumed, nutrient-wise, over time.

## Goals

- New page `supplement-history.html`: one row per day, showing total
  amount of user-selected ingredients taken that day.
- Mirror `alcohol-history.html`'s look, nav placement, and range/sort
  controls so the app stays consistent.
- Let the user pick which ingredients to see as columns (multi-select),
  since the full ingredient set across all tablets is far larger and more
  variable than alcohol's fixed 3 types (a single multivitamin can have
  20+ ingredients).

## Non-goals

- No unit conversion (e.g. IU ↔ mcg) — same-named ingredients logged
  under different units are treated as distinct metrics (see Data model
  below), not reconciled.
- No edits from this page — it's read-only, same as Alcohol History.
  Tablet/ingredient management stays on Item Catalog.
- No "Total" column — summing across different ingredients/units isn't
  meaningful, so sort/aggregate-by-total (which Alcohol History has) is
  dropped for this page.

## Data model

No schema changes. Reads only:

- `supplement_log` — `log_date, supplement, taken, quantity`, filtered to
  `taken = true`, in the selected date range (paginated the same way
  `alcohol-history.html`'s `alcoholLogInRange` handles Supabase's 1000-row
  cap).
- `supplement_ingredients` — `supplement, ingredient, amount_value,
  amount_unit`, loaded in full once (not range-filtered — needed both to
  compute the picker's ingredient list and to resolve amounts for any
  historical tablet, including archived ones).

**Ingredient identity is `(ingredient name, amount_unit)`, not name
alone.** The current app (`item-catalog.html`) does not enforce that a
given ingredient name always uses the same unit across different tablets
(that validation only exists in an unmerged branch). Treating name alone
as the key could silently sum incompatible units (e.g. Vitamin D3 as
`600 IU` in one tablet and `15 mcg` in another → nonsense total). Keying
on the pair instead means "Vitamin D3 (IU)" and "Vitamin D3 (mcg)" are
two distinct, independently-selectable picker entries, each internally
consistent to sum.

Name matching for the key is exact (not normalized/case-folded) — this
mirrors how `ingredientsBySupp` already keys by raw `supplement` name
elsewhere in the app, and avoids collapsing two differently-cased
ingredient entries a user may have intentionally kept distinct.

## Page structure

New file `supplement-history.html`, copied from `alcohol-history.html`'s
shell (topbar, sidebar nav, CSS variables, table-wrap pattern) with:

- Sidebar: add `💊 Supplement History` link under the Health Log group,
  next to `🍸 Alcohol History`, in this file and every other page's
  sidebar nav block (same as how `alcohol-history.html` itself is listed
  everywhere).
- Title: "💊 Supplement History".

### Ingredient picker

A field above the range controls: a list of checkbox chips, one per
distinct `(ingredient, unit)` pair across **all** supplements (active and
archived — historical rows can reference an archived tablet), labeled
`"<ingredient> (<unit>)"`, sorted alphabetically by ingredient name. No
chip is selected by default.

### Range & sort controls

Identical to `alcohol-history.html`: quick buttons `Last 50 days` /
`All data`, custom `From`/`To` date inputs with `Apply`, and sort buttons
`Date ↑ oldest` / `Date ↓ newest` (default: newest first). No
total-based sort (see Non-goals).

### Table

- Empty-picker state: table area replaced with the message "Pick one or
  more ingredients above to see their totals per day." (no table
  rendered).
- Once ≥1 ingredient is picked: `Date` column + one column per selected
  ingredient (header = `"<ingredient> (<unit>)"`). Every calendar date in
  the selected range gets a row (zero-filled, matching Alcohol History's
  `dateRangeDesc` behavior) — cells with nothing taken show `—` styled
  like Alcohol History's `.total-val.zero`.
- Cell value = sum of `amount_value × (quantity ?? 1)` across every
  taken-that-day tablet whose ingredient list contains that
  `(ingredient, unit)` pair. Hovering a non-zero cell shows a tooltip
  listing the contributing tablets (name + per-tablet amount), same
  pattern as Alcohol History's `title` tooltip on drink cells.
- Changing the ingredient selection or the date range recomputes/rerenders
  the table client-side from already-fetched data where possible (range
  changes still need a fresh `supplement_log` fetch; ingredient-selection
  changes do not, since all ingredient data is loaded once upfront).

## Data access (`DB` module, local to this page)

```js
supplementLogInRange(fromDate, toDate)   // paginated, taken=true only, mirrors alcoholLogInRange
allSupplementIngredients()               // supplement -> [{ingredient, amount_value, amount_unit}], all tablets
earliestSupplementLogDate()              // for "All data" lower bound, mirrors earliestAlcoholDate
```

No changes to `health-log.html` or `item-catalog.html`'s existing `DB`
objects — this page is fully self-contained, per the project's one-`DB`-
module-per-page pattern.

## Error handling

- `supplement_log` / ingredient fetch failure: inline message in the
  page's `dataMsg` element, same text pattern as Alcohol History
  (`"Could not load: <error>"` / `"Refresh failed: <error>"`).
- Picker fetch failure (i.e. `allSupplementIngredients` fails on initial
  load): picker area shows an inline "Could not load ingredients:
  <error>" instead of chips; range/table stay in the empty-picker state.

## Testing

Manual verification (no test suite in this repo, per project convention):

- Pick a single ingredient present in one tablet, confirm daily totals
  match `supplement_log` × `supplement_ingredients` by hand for a few
  known dates.
- Pick an ingredient that appears in two different tablets taken on the
  same day, confirm the cell sums both contributions and the tooltip
  lists both.
- Confirm an ingredient logged under two different units shows as two
  separate picker entries, not one.
- Confirm archived tablets' historical ingredient data still resolves
  (don't filter `supplement_ingredients` by `active`).
- Confirm date-range and sort controls behave identically to Alcohol
  History (Last 50 days default, All data, custom range, sort toggle).
