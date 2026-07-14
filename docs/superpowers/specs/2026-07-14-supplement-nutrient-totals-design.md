# Supplement Nutrient Totals — Design

## Problem

Supplement Tracker already models tablets as containers of ingredients
(`supplements` + `supplement_ingredients`, e.g. tablet X = Vitamin A 10mg +
Vitamin B 12mg + Vitamin C 15mg) and logs which tablets were taken per day
(`supplement_log`). There is no view of **total nutrients consumed on a
given day** — e.g. taking both tablet X and Y should show Vitamin A 10mg,
Vitamin B 22mg (12+10), Vitamin C 15mg, Vitamin D 15mg.

## Goals

- On the Data Entry page (health-log.html), show a live "Today's nutrients"
  card that sums ingredient amounts across all tablets marked taken for the
  selected log date.
- Prevent the same ingredient from silently splitting into multiple totals
  due to unit mismatch (e.g. Vitamin D as "IU" in one tablet, "mcg" in
  another).
- Keep the existing architecture: single `DB` data-access module per page,
  client-side computation, no new backend logic.

## Non-goals

- No historical/multi-day nutrient trend view (out of scope for this spec).
- No unit conversion (e.g. IU ↔ mcg) — mismatched units are blocked at
  entry time, not reconciled automatically.
- No canonical ingredient dictionary/table — ingredient names stay freeform
  text with autocomplete as a soft nudge, not a hard constraint.

## Data model changes

`supplement_ingredients.amount` (freeform text) is replaced with two
columns so amounts can be summed:

```sql
alter table supplement_ingredients drop column amount;
alter table supplement_ingredients add column amount_value numeric;
alter table supplement_ingredients add column amount_unit text;
```

No existing ingredient amount data exists yet (confirmed with user), so
this is a clean migration — no conversion step needed.

`ingredient` name column is unchanged (freeform text). Aggregation matches
names case-insensitively and trimmed (`trim().toLowerCase()`), not via a
canonical lookup table.

## Ingredient entry UI (Health Log "+ Add tablet" form + Supplement Tracker
edit form — both already have an ingredient row list)

Each ingredient row becomes three inputs instead of two:

- **Ingredient name** — text input with `<datalist>` autocomplete populated
  from all ingredient names used across every tablet (case-insensitive
  dedup for the suggestion list, but the datalist shows original casing).
- **Amount** — numeric input (`amount_value`).
- **Unit** — text input (e.g. `mg`, `mcg`, `IU`, `g`) with its own
  `<datalist>` autocomplete from units already used.

### Unit-conflict validation (on Save, both forms)

Before saving a tablet's ingredient list:

1. Fetch all existing `supplement_ingredients` rows (across all tablets,
   excluding the tablet currently being edited).
2. Normalize each row's ingredient name (`trim().toLowerCase()`).
3. For each ingredient being saved, if its normalized name already exists
   elsewhere with a **different non-empty** unit, block the save and show:
   `"<Ingredient> already used as '<existing unit>' elsewhere — pick the
   same unit or rename this ingredient."`
4. If the unit matches (or the ingredient name is new), save proceeds
   normally.

This keeps every occurrence of "the same" ingredient (by normalized name)
using one unit app-wide, which is what makes summation valid.

## "Today's nutrients" card (Data Entry page only)

New card on `health-log.html`, placed below the existing tablet checklist,
tied to the same `logDate` the checklist already uses.

**Data needed:** ingredients for every *active* tablet (fetched once,
cached client-side the same way `activeSupplements` already is).

**Recompute triggers:** page load, log-date change, and every checkbox
toggle in the existing tablet checklist (reuses the same event hook that
already calls `DB.supplementLogSet`).

**Computation (pure client-side JS):**

1. Filter active tablets to those marked `taken` for `logDate` (from the
   already-loaded `supplementLogForDate` result).
2. For each taken tablet, iterate its ingredients.
3. Group by `normalized name + unit`, summing `amount_value`.
4. Display label uses the **first-seen original casing** of the ingredient
   name (not the lowercased key) for readability.

**Rendering:** simple list, e.g.:

```
Vitamin A: 10 mg
Vitamin B: 22 mg
Vitamin C: 15 mg
Vitamin D: 15 mg
```

**Empty state:** "No tablets taken yet today." when no tablet is checked
for the selected date.

Supplement Tracker page (supplement-tracker.html) is unaffected by this
card — it keeps its existing per-day History table (✓/✗/— checklist view)
without adding a nutrient-totals column, per user's explicit scoping
("supplement page is the table of all days").

## Error handling

- Ingredient fetch failure for the nutrients card: show inline "Could not
  load nutrients: <error>" in the card, same pattern as existing
  `suppChecklist` error handling.
- Save-time unit conflict: blocks save, inline error in the existing
  `crs-msg` element used by the ingredient form (no new UI pattern).

## Testing

- Manual verification (per project convention — no test suite in this
  repo): add two tablets with an overlapping ingredient at the same unit,
  check both on a date, confirm the nutrients card sums correctly. Add a
  third tablet with a conflicting unit for an existing ingredient name,
  confirm save is blocked with the expected message.
