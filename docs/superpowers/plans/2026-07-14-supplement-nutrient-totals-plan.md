# Supplement Nutrient Totals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a live "Today's nutrients" card on the Data Entry page that sums ingredient amounts across every tablet marked taken for the selected date, backed by structured (number + unit) ingredient amounts instead of freeform text.

**Architecture:** No backend logic changes beyond one column migration. Both pages (`health-log.html`, `supplement-tracker.html`) already load their tablet/ingredient data fully into client-side JS arrays on page load (see each file's `DB` module) — this plan extends that same pattern: fetch all ingredients, sum client-side, re-render on checkbox toggle.

**Tech Stack:** Plain HTML + vanilla JS (ES modules, no build step) + Supabase (Postgres + supabase-js v2). No test framework in this repo — verification is manual, done by opening the page in a browser and exercising the feature, plus checking data in the Supabase Table Editor.

---

## File Structure

- **Create** `supabase/supplement_ingredients_amount_unit.sql` — column migration.
- **Modify** `supplement-tracker.html` — ingredient row UI (name/amount/unit), unit-conflict validation, ingredient display formatting, `DB.ingredientsAll`/`DB.ingredientsReplace` field names.
- **Modify** `health-log.html` — same ingredient row UI + validation changes as above (this file has its own independent copy of the ingredient-editing code, same as it does today), plus the new "Today's nutrients" card, its computation, and a new `DB.ingredientsAll` method (doesn't exist here yet).

Both HTML files stay fully self-contained (no shared JS module) — this matches the existing pattern where `addIngredientRow`/`collectIngredients` are already independently duplicated in both files.

---

### Task 1: Database migration — split `amount` into `amount_value` + `amount_unit`

**Files:**
- Create: `supabase/supplement_ingredients_amount_unit.sql`

- [ ] **Step 1: Write the migration file**

```sql
-- Split freeform ingredient amount into a numeric value + unit so amounts
-- across tablets can be summed (e.g. Vitamin B 12mg + 10mg = 22mg).
-- Run in Supabase → SQL Editor (after supplement_ingredients.sql).

alter table supplement_ingredients drop column amount;
alter table supplement_ingredients add column amount_value numeric;
alter table supplement_ingredients add column amount_unit text;
```

- [ ] **Step 2: Run it against the Supabase project**

Open `https://supabase.com/dashboard/project/twpzcszcvylhaopcwqkv/sql/new`, paste the contents of the file, click **Run**.

- [ ] **Step 3: Verify the migration**

In the Supabase dashboard, go to **Table Editor → supplement_ingredients**. Confirm:
- `amount` column is gone.
- `amount_value` (numeric, nullable) and `amount_unit` (text, nullable) columns exist.

- [ ] **Step 4: Commit**

```bash
git add supabase/supplement_ingredients_amount_unit.sql
git commit -m "feat(supplements): split ingredient amount into value + unit columns"
```

---

### Task 2: Update `DB.ingredientsAll` / `DB.ingredientsReplace` in `supplement-tracker.html`

**Files:**
- Modify: `supplement-tracker.html:285-302`

- [ ] **Step 1: Replace the two DB methods**

Find (around line 285):

```javascript
      async ingredientsAll() {
        const { data, error } = await supabase.from('supplement_ingredients')
          .select('supplement, ingredient, amount').order('sort_order', { ascending: true });
        if (error) throw error;
        return data;
      },
      // replace the full ingredient list for a tablet (delete + re-insert is
      // simplest to keep in sync with a freeform, reorderable row list)
      async ingredientsReplace(supplement, ingredients) {
        const del = await supabase.from('supplement_ingredients').delete().eq('supplement', supplement);
        if (del.error) throw del.error;
        if (!ingredients.length) return;
        const rows = ingredients.map((ing, i) => ({
          supplement, ingredient: ing.ingredient, amount: ing.amount || null, sort_order: i,
        }));
        const ins = await supabase.from('supplement_ingredients').insert(rows);
        if (ins.error) throw ins.error;
      },
```

Replace with:

```javascript
      async ingredientsAll() {
        const { data, error } = await supabase.from('supplement_ingredients')
          .select('supplement, ingredient, amount_value, amount_unit').order('sort_order', { ascending: true });
        if (error) throw error;
        return data;
      },
      // replace the full ingredient list for a tablet (delete + re-insert is
      // simplest to keep in sync with a freeform, reorderable row list)
      async ingredientsReplace(supplement, ingredients) {
        const del = await supabase.from('supplement_ingredients').delete().eq('supplement', supplement);
        if (del.error) throw del.error;
        if (!ingredients.length) return;
        const rows = ingredients.map((ing, i) => ({
          supplement, ingredient: ing.ingredient,
          amount_value: ing.amount_value, amount_unit: ing.amount_unit, sort_order: i,
        }));
        const ins = await supabase.from('supplement_ingredients').insert(rows);
        if (ins.error) throw ins.error;
      },
```

- [ ] **Step 2: Commit**

```bash
git add supplement-tracker.html
git commit -m "feat(supplements): use amount_value/amount_unit in DB module"
```

(Page won't load ingredients correctly until Task 3 updates the render/collect code — that's expected, next task fixes it.)

---

### Task 3: Ingredient row UI (name/amount/unit) in `supplement-tracker.html`

**Files:**
- Modify: `supplement-tracker.html:147-149` (CSS)
- Modify: `supplement-tracker.html:219-221` (markup — add datalists)
- Modify: `supplement-tracker.html:350-367` (`addIngredientRow`, `collectIngredients`)
- Modify: `supplement-tracker.html:376-378` (`openSuppForm` ingredient prefill)
- Modify: `supplement-tracker.html:414-420` (`renderSuppTable` ingredient display)
- Modify: `supplement-tracker.html:442-449` (`loadSupplements` — populate datalists)

- [ ] **Step 1: CSS — add a fixed width for the new unit input**

Find (line 147-149):

```css
    .ing-row { display: flex; gap: 6px; margin-bottom: 6px; }
    .ing-row input { flex: 1; min-width: 0; }
    .ing-row input.ing-amount { flex: 0 0 90px; }
```

Replace with:

```css
    .ing-row { display: flex; gap: 6px; margin-bottom: 6px; }
    .ing-row input { flex: 1; min-width: 0; }
    .ing-row input.ing-amount { flex: 0 0 70px; }
    .ing-row input.ing-unit { flex: 0 0 70px; }
```

- [ ] **Step 2: Markup — add datalists for autocomplete**

Find (line 219-221):

```html
          <label class="muted-note">Ingredients</label>
          <div id="sfIngredients"></div>
          <button class="mini-btn ghost" id="sfIngAdd" type="button">＋ Add ingredient</button>
```

Replace with:

```html
          <label class="muted-note">Ingredients</label>
          <div id="sfIngredients"></div>
          <button class="mini-btn ghost" id="sfIngAdd" type="button">＋ Add ingredient</button>
          <datalist id="ingNameList"></datalist>
          <datalist id="ingUnitList"></datalist>
```

- [ ] **Step 3: JS — rewrite `addIngredientRow` and `collectIngredients`**

Find (line 350-367):

```javascript
    function addIngredientRow(ingredient = '', amount = '') {
      const row = document.createElement('div');
      row.className = 'ing-row';
      row.innerHTML = `
        <input type="text" class="ing-name" placeholder="Ingredient, e.g. Vitamin D3" value="${ingredient}" />
        <input type="text" class="ing-amount" placeholder="Amount" value="${amount}" />
        <button type="button" class="ing-rm" title="Remove">✕</button>`;
      row.querySelector('.ing-rm').addEventListener('click', () => row.remove());
      $('sfIngredients').appendChild(row);
    }
    function collectIngredients() {
      return [...$('sfIngredients').querySelectorAll('.ing-row')]
        .map(row => ({
          ingredient: row.querySelector('.ing-name').value.trim(),
          amount: row.querySelector('.ing-amount').value.trim(),
        }))
        .filter(i => i.ingredient);
    }
```

Replace with:

```javascript
    function addIngredientRow(ingredient = '', amountValue = '', amountUnit = '') {
      const row = document.createElement('div');
      row.className = 'ing-row';
      row.innerHTML = `
        <input type="text" class="ing-name" list="ingNameList" placeholder="Ingredient, e.g. Vitamin D3" value="${ingredient}" />
        <input type="number" step="any" class="ing-amount" placeholder="Amount" value="${amountValue}" />
        <input type="text" class="ing-unit" list="ingUnitList" placeholder="Unit" value="${amountUnit}" />
        <button type="button" class="ing-rm" title="Remove">✕</button>`;
      row.querySelector('.ing-rm').addEventListener('click', () => row.remove());
      $('sfIngredients').appendChild(row);
    }
    function collectIngredients() {
      return [...$('sfIngredients').querySelectorAll('.ing-row')]
        .map(row => {
          const rawAmount = row.querySelector('.ing-amount').value.trim();
          return {
            ingredient: row.querySelector('.ing-name').value.trim(),
            amount_value: rawAmount === '' ? null : Number(rawAmount),
            amount_unit: row.querySelector('.ing-unit').value.trim() || null,
          };
        })
        .filter(i => i.ingredient);
    }
    // normalized ingredient name -> shared key for matching across tablets
    const ingKey = name => name.trim().toLowerCase();
    // datalist options for ingredient names / units, deduped case-insensitively,
    // keeping the first-seen original casing for display
    function populateIngredientDatalists(allIngredients) {
      const names = [], units = [], seenNames = new Set(), seenUnits = new Set();
      for (const r of allIngredients) {
        const nk = ingKey(r.ingredient);
        if (!seenNames.has(nk)) { seenNames.add(nk); names.push(r.ingredient); }
        if (r.amount_unit) {
          const uk = r.amount_unit.trim().toLowerCase();
          if (!seenUnits.has(uk)) { seenUnits.add(uk); units.push(r.amount_unit); }
        }
      }
      $('ingNameList').innerHTML = names.map(n => `<option value="${n}"></option>`).join('');
      $('ingUnitList').innerHTML = units.map(u => `<option value="${u}"></option>`).join('');
    }
    // block save when an ingredient name is already used elsewhere with a
    // different unit — that's what makes cross-tablet summation valid
    function findUnitConflict(newIngredients, allIngredients, excludeNames) {
      const unitByName = {};
      for (const row of allIngredients) {
        if (excludeNames.includes(row.supplement)) continue;
        if (!row.amount_unit) continue;
        const key = ingKey(row.ingredient);
        if (!(key in unitByName)) unitByName[key] = { unit: row.amount_unit, original: row.ingredient };
      }
      for (const ing of newIngredients) {
        if (!ing.amount_unit) continue;
        const existing = unitByName[ingKey(ing.ingredient)];
        if (existing && existing.unit !== ing.amount_unit) {
          return `"${existing.original}" already used as "${existing.unit}" elsewhere — pick the same unit or rename this ingredient.`;
        }
      }
      return null;
    }
```

- [ ] **Step 4: JS — prefill amount/unit when editing a tablet**

Find (line 376-378):

```javascript
      const ings = ingredientsBySupp[s.name] || [];
      if (ings.length) ings.forEach(i => addIngredientRow(i.ingredient, i.amount || ''));
      else addIngredientRow();
```

Replace with:

```javascript
      const ings = ingredientsBySupp[s.name] || [];
      if (ings.length) ings.forEach(i => addIngredientRow(i.ingredient, i.amount_value ?? '', i.amount_unit || ''));
      else addIngredientRow();
```

- [ ] **Step 5: JS — show amount + unit in the tablet table**

Find (line 414-420):

```javascript
      for (const s of supplements) {
        const ings = ingredientsBySupp[s.name] || [];
        const ingText = ings.length
          ? ings.map(i => i.amount ? `${i.ingredient} (${i.amount})` : i.ingredient).join(', ')
          : '—';
```

Replace with:

```javascript
      for (const s of supplements) {
        const ings = ingredientsBySupp[s.name] || [];
        const ingText = ings.length
          ? ings.map(i => i.amount_value != null
              ? `${i.ingredient} (${i.amount_value}${i.amount_unit ? ' ' + i.amount_unit : ''})`
              : i.ingredient).join(', ')
          : '—';
```

- [ ] **Step 6: JS — populate datalists after loading ingredients**

Find (line 442-449):

```javascript
    async function loadSupplements() {
      const [supps, ings] = await Promise.all([DB.supplementsAll(), DB.ingredientsAll()]);
      supplements = supps;
      ingredientsBySupp = {};
      for (const i of ings) (ingredientsBySupp[i.supplement] ||= []).push(i);
      renderSuppTable();
      renderHistTable();
    }
```

Replace with:

```javascript
    async function loadSupplements() {
      const [supps, ings] = await Promise.all([DB.supplementsAll(), DB.ingredientsAll()]);
      supplements = supps;
      ingredientsBySupp = {};
      for (const i of ings) (ingredientsBySupp[i.supplement] ||= []).push(i);
      populateIngredientDatalists(ings);
      renderSuppTable();
      renderHistTable();
    }
```

- [ ] **Step 7: Manual verification**

Open `supplement-tracker.html` in a browser (`file://` or your local server — same as you already use), log in.
- Click **Edit** on an existing tablet. Confirm the ingredient rows now show three inputs (name, amount, unit) and existing ingredients prefill amount/unit as empty (since Task 1 dropped old data).
- Type an ingredient name, amount `10`, unit `mg`. Click **Save**. Confirm the tablet's row in the table now shows `Ingredient (10 mg)`.
- Start typing an ingredient name you already used in another tablet — confirm the browser's native autocomplete dropdown suggests it.

- [ ] **Step 8: Commit**

```bash
git add supplement-tracker.html
git commit -m "feat(supplements): structured amount+unit ingredient inputs with autocomplete"
```

---

### Task 4: Wire unit-conflict validation into `supplement-tracker.html` save

**Files:**
- Modify: `supplement-tracker.html:384-406` (`sfSave` handler)

- [ ] **Step 1: Add the validation check before saving**

Find (line 384-406):

```javascript
    $('sfSave').addEventListener('click', async () => {
      const name = $('sfName').value.trim();
      if (!name) { suppMsg('Name is required.', 'err'); return; }
      const origName = $('sfOrigName').value;
      $('sfSave').disabled = true;
      suppMsg('Saving…', '');
      try {
        if (origName && origName !== name) {
          await DB.supplementSetActive(origName, false);   // don't silently orphan the old row
        }
        const existing = supplements.find(s => s.name === name);
        await DB.supplementUpsert({
          name, dose: $('sfDose').value.trim(), notes: $('sfNotes').value.trim(),
          active: true, sort_order: existing ? existing.sort_order : supplements.length,
        });
        await DB.ingredientsReplace(name, collectIngredients());
        suppMsg('Saved.', 'ok');
        $('suppForm').classList.add('hidden');
        await loadSupplements();
      } catch (e) {
        suppMsg('Save failed: ' + (e.message || ''), 'err');
      } finally { $('sfSave').disabled = false; }
    });
```

Replace with:

```javascript
    $('sfSave').addEventListener('click', async () => {
      const name = $('sfName').value.trim();
      if (!name) { suppMsg('Name is required.', 'err'); return; }
      const origName = $('sfOrigName').value;
      const ingredients = collectIngredients();
      $('sfSave').disabled = true;
      suppMsg('Saving…', '');
      try {
        const allIngredients = await DB.ingredientsAll();
        const conflict = findUnitConflict(ingredients, allIngredients, [name, origName].filter(Boolean));
        if (conflict) { suppMsg(conflict, 'err'); $('sfSave').disabled = false; return; }
        if (origName && origName !== name) {
          await DB.supplementSetActive(origName, false);   // don't silently orphan the old row
        }
        const existing = supplements.find(s => s.name === name);
        await DB.supplementUpsert({
          name, dose: $('sfDose').value.trim(), notes: $('sfNotes').value.trim(),
          active: true, sort_order: existing ? existing.sort_order : supplements.length,
        });
        await DB.ingredientsReplace(name, ingredients);
        suppMsg('Saved.', 'ok');
        $('suppForm').classList.add('hidden');
        await loadSupplements();
      } catch (e) {
        suppMsg('Save failed: ' + (e.message || ''), 'err');
      } finally { $('sfSave').disabled = false; }
    });
```

- [ ] **Step 2: Manual verification**

- Edit tablet X, give ingredient "Vitamin D" unit `mg`, save — succeeds.
- Edit tablet Y, add ingredient "Vitamin D" (same name, case-insensitive e.g. "vitamin d") unit `mcg`, click Save. Confirm it's **blocked** with the message `"Vitamin D" already used as "mg" elsewhere — pick the same unit or rename this ingredient.` and nothing is written (refresh page, confirm tablet Y's ingredient list unaffected).
- Retry with unit `mg` (matching) — confirm it saves successfully.

- [ ] **Step 3: Commit**

```bash
git add supplement-tracker.html
git commit -m "feat(supplements): block saving ingredients with conflicting units"
```

---

### Task 5: Ingredient row UI (name/amount/unit) in `health-log.html`

**Files:**
- Modify: `health-log.html:308-310` (CSS)
- Modify: `health-log.html:433-435` (markup — add datalists)
- Modify: `health-log.html:648-659` (`DB.ingredientsReplace`, add `DB.ingredientsAll`)
- Modify: `health-log.html:953-970` (`addIngredientRow`, `collectIngredients`, add `ingKey`/`findUnitConflict`/`populateIngredientDatalists`)

- [ ] **Step 1: CSS — add a fixed width for the new unit input**

Find (line 308-310):

```css
    .ing-row { display: flex; gap: 6px; margin-bottom: 6px; }
    .ing-row input { flex: 1; min-width: 0; }
    .ing-row input.ing-amount { flex: 0 0 90px; }
```

Replace with:

```css
    .ing-row { display: flex; gap: 6px; margin-bottom: 6px; }
    .ing-row input { flex: 1; min-width: 0; }
    .ing-row input.ing-amount { flex: 0 0 70px; }
    .ing-row input.ing-unit { flex: 0 0 70px; }
```

- [ ] **Step 2: Markup — add datalists**

Find (line 433-435):

```html
              <label class="muted-note">Ingredients</label>
              <div id="sfIngredients"></div>
              <button class="mini-btn ghost" id="sfIngAdd" type="button">＋ Add ingredient</button>
```

Replace with:

```html
              <label class="muted-note">Ingredients</label>
              <div id="sfIngredients"></div>
              <button class="mini-btn ghost" id="sfIngAdd" type="button">＋ Add ingredient</button>
              <datalist id="ingNameList"></datalist>
              <datalist id="ingUnitList"></datalist>
```

- [ ] **Step 3: DB module — add `ingredientsAll`, update `ingredientsReplace`**

Find (line 648-659):

```javascript
      // replace the full ingredient list for a tablet (delete + re-insert is
      // simplest to keep in sync with a freeform, reorderable row list)
      async ingredientsReplace(supplement, ingredients) {
        const del = await supabase.from('supplement_ingredients').delete().eq('supplement', supplement);
        if (del.error) throw del.error;
        if (!ingredients.length) return;
        const rows = ingredients.map((ing, i) => ({
          supplement, ingredient: ing.ingredient, amount: ing.amount || null, sort_order: i,
        }));
        const ins = await supabase.from('supplement_ingredients').insert(rows);
        if (ins.error) throw ins.error;
      },
      async receivedAdd(supplement, received_date) {
        const { error } = await supabase.from('supplement_received').insert({ supplement, received_date });
        if (error) throw error;
      },
```

Replace with:

```javascript
      async ingredientsAll() {
        const { data, error } = await supabase.from('supplement_ingredients')
          .select('supplement, ingredient, amount_value, amount_unit').order('sort_order', { ascending: true });
        if (error) throw error;
        return data;
      },
      // replace the full ingredient list for a tablet (delete + re-insert is
      // simplest to keep in sync with a freeform, reorderable row list)
      async ingredientsReplace(supplement, ingredients) {
        const del = await supabase.from('supplement_ingredients').delete().eq('supplement', supplement);
        if (del.error) throw del.error;
        if (!ingredients.length) return;
        const rows = ingredients.map((ing, i) => ({
          supplement, ingredient: ing.ingredient,
          amount_value: ing.amount_value, amount_unit: ing.amount_unit, sort_order: i,
        }));
        const ins = await supabase.from('supplement_ingredients').insert(rows);
        if (ins.error) throw ins.error;
      },
      async receivedAdd(supplement, received_date) {
        const { error } = await supabase.from('supplement_received').insert({ supplement, received_date });
        if (error) throw error;
      },
```

- [ ] **Step 4: JS — rewrite `addIngredientRow`/`collectIngredients`, add helper functions**

Find (line 953-970):

```javascript
    function addIngredientRow(ingredient = '', amount = '') {
      const row = document.createElement('div');
      row.className = 'ing-row';
      row.innerHTML = `
        <input type="text" class="ing-name" placeholder="Ingredient, e.g. Vitamin D3" value="${ingredient}" />
        <input type="text" class="ing-amount" placeholder="Amount" value="${amount}" />
        <button type="button" class="ing-rm" title="Remove">✕</button>`;
      row.querySelector('.ing-rm').addEventListener('click', () => row.remove());
      $('sfIngredients').appendChild(row);
    }
    function collectIngredients() {
      return [...$('sfIngredients').querySelectorAll('.ing-row')]
        .map(row => ({
          ingredient: row.querySelector('.ing-name').value.trim(),
          amount: row.querySelector('.ing-amount').value.trim(),
        }))
        .filter(i => i.ingredient);
    }
```

Replace with:

```javascript
    function addIngredientRow(ingredient = '', amountValue = '', amountUnit = '') {
      const row = document.createElement('div');
      row.className = 'ing-row';
      row.innerHTML = `
        <input type="text" class="ing-name" list="ingNameList" placeholder="Ingredient, e.g. Vitamin D3" value="${ingredient}" />
        <input type="number" step="any" class="ing-amount" placeholder="Amount" value="${amountValue}" />
        <input type="text" class="ing-unit" list="ingUnitList" placeholder="Unit" value="${amountUnit}" />
        <button type="button" class="ing-rm" title="Remove">✕</button>`;
      row.querySelector('.ing-rm').addEventListener('click', () => row.remove());
      $('sfIngredients').appendChild(row);
    }
    function collectIngredients() {
      return [...$('sfIngredients').querySelectorAll('.ing-row')]
        .map(row => {
          const rawAmount = row.querySelector('.ing-amount').value.trim();
          return {
            ingredient: row.querySelector('.ing-name').value.trim(),
            amount_value: rawAmount === '' ? null : Number(rawAmount),
            amount_unit: row.querySelector('.ing-unit').value.trim() || null,
          };
        })
        .filter(i => i.ingredient);
    }
    // normalized ingredient name -> shared key for matching across tablets
    const ingKey = name => name.trim().toLowerCase();
    // datalist options for ingredient names / units, deduped case-insensitively,
    // keeping the first-seen original casing for display
    function populateIngredientDatalists(allIngredients) {
      const names = [], units = [], seenNames = new Set(), seenUnits = new Set();
      for (const r of allIngredients) {
        const nk = ingKey(r.ingredient);
        if (!seenNames.has(nk)) { seenNames.add(nk); names.push(r.ingredient); }
        if (r.amount_unit) {
          const uk = r.amount_unit.trim().toLowerCase();
          if (!seenUnits.has(uk)) { seenUnits.add(uk); units.push(r.amount_unit); }
        }
      }
      $('ingNameList').innerHTML = names.map(n => `<option value="${n}"></option>`).join('');
      $('ingUnitList').innerHTML = units.map(u => `<option value="${u}"></option>`).join('');
    }
    // block save when an ingredient name is already used elsewhere with a
    // different unit — that's what makes cross-tablet summation valid
    function findUnitConflict(newIngredients, allIngredients, excludeNames) {
      const unitByName = {};
      for (const row of allIngredients) {
        if (excludeNames.includes(row.supplement)) continue;
        if (!row.amount_unit) continue;
        const key = ingKey(row.ingredient);
        if (!(key in unitByName)) unitByName[key] = { unit: row.amount_unit, original: row.ingredient };
      }
      for (const ing of newIngredients) {
        if (!ing.amount_unit) continue;
        const existing = unitByName[ingKey(ing.ingredient)];
        if (existing && existing.unit !== ing.amount_unit) {
          return `"${existing.original}" already used as "${existing.unit}" elsewhere — pick the same unit or rename this ingredient.`;
        }
      }
      return null;
    }
```

- [ ] **Step 5: Manual verification**

Open `health-log.html`, click **+ Add tablet**. Confirm the ingredient rows show three inputs (name, amount, unit).

- [ ] **Step 6: Commit**

```bash
git add health-log.html
git commit -m "feat(supplements): structured amount+unit ingredient inputs with autocomplete"
```

---

### Task 6: Wire unit-conflict validation into `health-log.html` save, refresh datalists

**Files:**
- Modify: `health-log.html:982-997` (`sfSave` handler)

- [ ] **Step 1: Add validation, populate datalists on load**

Find (line 982-997):

```javascript
    $('sfSave').addEventListener('click', async () => {
      const name = $('sfName').value.trim();
      if (!name) { suppFormMsg('Tablet name is required.', 'err'); return; }
      $('sfSave').disabled = true;
      suppFormMsg('Saving…', '');
      try {
        await DB.supplementUpsert({ name, dose: $('sfDose').value.trim(), sort_order: activeSupplements.length });
        await DB.ingredientsReplace(name, collectIngredients());
        activeSupplements = [];   // force a refetch so the new one shows up
        $('suppForm').classList.add('hidden');
        suppFormMsg('', '');
        await loadSupplementChecklist($('logDate').value);
      } catch (e) {
        suppFormMsg('Save failed: ' + (e.message || ''), 'err');
      } finally { $('sfSave').disabled = false; }
    });
```

Replace with:

```javascript
    $('sfSave').addEventListener('click', async () => {
      const name = $('sfName').value.trim();
      if (!name) { suppFormMsg('Tablet name is required.', 'err'); return; }
      const ingredients = collectIngredients();
      $('sfSave').disabled = true;
      suppFormMsg('Saving…', '');
      try {
        const allIngredients = await DB.ingredientsAll();
        const conflict = findUnitConflict(ingredients, allIngredients, [name]);
        if (conflict) { suppFormMsg(conflict, 'err'); $('sfSave').disabled = false; return; }
        await DB.supplementUpsert({ name, dose: $('sfDose').value.trim(), sort_order: activeSupplements.length });
        await DB.ingredientsReplace(name, ingredients);
        activeSupplements = [];   // force a refetch so the new one shows up
        $('suppForm').classList.add('hidden');
        suppFormMsg('', '');
        await loadSupplementChecklist($('logDate').value);
      } catch (e) {
        suppFormMsg('Save failed: ' + (e.message || ''), 'err');
      } finally { $('sfSave').disabled = false; }
    });
```

- [ ] **Step 2: Manual verification**

Repeat the conflicting-unit check from Task 4, Step 2, this time using the "+ Add tablet" form on `health-log.html`. Confirm the same block/message behavior.

- [ ] **Step 3: Commit**

```bash
git add health-log.html
git commit -m "feat(supplements): block saving ingredients with conflicting units"
```

---

### Task 7: "Today's nutrients" card — markup + CSS

**Files:**
- Modify: `health-log.html:421-444` (add new field between Supplement Tracker and Tablet received sections)
- Modify: `health-log.html` styles (add near existing `.checklist`/`.check-row` rules, e.g. after line 288)

- [ ] **Step 1: CSS — add nutrient row styling**

Find (line 288, the `.empty-note` rule):

```css
    .empty-note { color: var(--muted); font-size: 0.85rem; padding: 8px 0; }
```

Replace with:

```css
    .empty-note { color: var(--muted); font-size: 0.85rem; padding: 8px 0; }
    .nutrient-list { display: flex; flex-direction: column; gap: 6px; margin-top: 4px; }
    .nutrient-row {
      display: flex; justify-content: space-between; align-items: center;
      background: var(--field); border: 1px solid var(--border);
      border-radius: 10px; padding: 8px 12px; font-size: 0.9rem;
    }
    .nutrient-row .nr-amt { color: var(--accent); font-weight: 700; }
```

- [ ] **Step 2: Markup — insert the new card**

Find (line 421-444, the end of the Supplement Tracker field):

```html
          <div class="checklist" id="suppChecklist"></div>
        </div>
```

This is the closing of the Supplement Tracker `<div class="field">`. Immediately after that field's closing `</div>` and before the `<!-- ---------- Tablet received ---------- -->` comment (line 445), insert:

```html
          <div class="field">
            <div class="field-head"><span class="icon">🥗</span><span class="label">Today's nutrients</span></div>
            <div class="muted-note">Total from tablets checked above for this date. Same unit required across tablets to sum.</div>
            <div id="nutrientMsg" class="crs-msg"></div>
            <div class="nutrient-list" id="nutrientList"></div>
          </div>
```

- [ ] **Step 3: Manual verification**

Reload `health-log.html`. Confirm a new "Today's nutrients" card appears between the Supplement Tracker checklist and the Tablet received card, currently empty (no JS wired yet — that's Task 8).

- [ ] **Step 4: Commit**

```bash
git add health-log.html
git commit -m "feat(supplements): add Today's nutrients card markup"
```

---

### Task 8: "Today's nutrients" computation + wiring

**Files:**
- Modify: `health-log.html:889` (globals)
- Modify: `health-log.html:890-925` (`loadSupplementChecklist`)
- Modify: `health-log.html:1199-1208` (`showApp`)

- [ ] **Step 1: Add globals and the render/load functions**

Find (line 889):

```javascript
    let activeSupplements = [];
```

Replace with:

```javascript
    let activeSupplements = [];
    let ingredientsBySupp = {};   // tablet name -> [{ ingredient, amount_value, amount_unit }]
    let takenSet = new Set();     // tablet names marked taken for the selected log date

    async function loadIngredients() {
      const rows = await DB.ingredientsAll();
      ingredientsBySupp = {};
      for (const r of rows) (ingredientsBySupp[r.supplement] ||= []).push(r);
      populateIngredientDatalists(rows);
    }

    function nutrientMsg(text, kind) {
      const el = $('nutrientMsg'); el.textContent = text || '';
      el.className = 'crs-msg' + (kind ? ' ' + kind : '');
    }

    function renderNutrientTotals() {
      const el = $('nutrientList');
      const totals = {};   // "normalizedName|unit" -> { label, unit, sum }
      for (const name of takenSet) {
        for (const ing of ingredientsBySupp[name] || []) {
          if (ing.amount_value == null || !ing.amount_unit) continue;
          const key = ingKey(ing.ingredient) + '|' + ing.amount_unit;
          if (!totals[key]) totals[key] = { label: ing.ingredient, unit: ing.amount_unit, sum: 0 };
          totals[key].sum += Number(ing.amount_value);
        }
      }
      const rows = Object.values(totals);
      if (!rows.length) {
        el.innerHTML = '<div class="empty-note">No tablets taken yet today.</div>';
        return;
      }
      el.innerHTML = rows
        .map(r => `<div class="nutrient-row"><span class="nr-name">${r.label}</span><span class="nr-amt">${r.sum} ${r.unit}</span></div>`)
        .join('');
    }
```

- [ ] **Step 2: Build `takenSet` on load and on checkbox toggle**

Find (line 890-925):

```javascript
    async function loadSupplementChecklist(logDate) {
      const el = $('suppChecklist');
      if (!logDate) { el.innerHTML = ''; return; }
      try {
        if (!activeSupplements.length) activeSupplements = await DB.activeSupplements();
        populateReceivedSelect();
        if (!activeSupplements.length) {
          el.innerHTML = '<div class="empty-note">No active tablets — click "+ Add tablet" above.</div>';
          return;
        }
        const rows = await DB.supplementLogForDate(logDate);
        const takenMap = Object.fromEntries(rows.map(r => [r.supplement, r.taken]));
        el.innerHTML = activeSupplements.map(s => {
          const taken = takenMap[s.name] === true;
          return `<label class="check-row${taken ? ' taken' : ''}" data-name="${s.name}">
            <input type="checkbox" ${taken ? 'checked' : ''} />
            <span class="cr-name">${s.name}</span><span class="cr-dose">${s.dose || ''}</span>
          </label>`;
        }).join('');
        el.querySelectorAll('.check-row').forEach(row => {
          const cb = row.querySelector('input');
          cb.addEventListener('change', async () => {
            cb.disabled = true;
            try {
              await DB.supplementLogSet(logDate, row.dataset.name, cb.checked);
              row.classList.toggle('taken', cb.checked);
            } catch (e) {
              cb.checked = !cb.checked;
              msg($('saveMsg'), 'Supplement save failed: ' + e.message, 'err');
            } finally { cb.disabled = false; }
          });
        });
      } catch (e) {
        el.innerHTML = '<div class="empty-note">Could not load supplements: ' + e.message + '</div>';
      }
    }
```

Replace with:

```javascript
    async function loadSupplementChecklist(logDate) {
      const el = $('suppChecklist');
      if (!logDate) { el.innerHTML = ''; takenSet = new Set(); renderNutrientTotals(); return; }
      try {
        if (!activeSupplements.length) activeSupplements = await DB.activeSupplements();
        if (!Object.keys(ingredientsBySupp).length) await loadIngredients();
        populateReceivedSelect();
        if (!activeSupplements.length) {
          el.innerHTML = '<div class="empty-note">No active tablets — click "+ Add tablet" above.</div>';
          takenSet = new Set();
          renderNutrientTotals();
          return;
        }
        const rows = await DB.supplementLogForDate(logDate);
        const takenMap = Object.fromEntries(rows.map(r => [r.supplement, r.taken]));
        takenSet = new Set(Object.keys(takenMap).filter(name => takenMap[name]));
        el.innerHTML = activeSupplements.map(s => {
          const taken = takenMap[s.name] === true;
          return `<label class="check-row${taken ? ' taken' : ''}" data-name="${s.name}">
            <input type="checkbox" ${taken ? 'checked' : ''} />
            <span class="cr-name">${s.name}</span><span class="cr-dose">${s.dose || ''}</span>
          </label>`;
        }).join('');
        el.querySelectorAll('.check-row').forEach(row => {
          const cb = row.querySelector('input');
          cb.addEventListener('change', async () => {
            cb.disabled = true;
            try {
              await DB.supplementLogSet(logDate, row.dataset.name, cb.checked);
              row.classList.toggle('taken', cb.checked);
              if (cb.checked) takenSet.add(row.dataset.name); else takenSet.delete(row.dataset.name);
              renderNutrientTotals();
            } catch (e) {
              cb.checked = !cb.checked;
              msg($('saveMsg'), 'Supplement save failed: ' + e.message, 'err');
            } finally { cb.disabled = false; }
          });
        });
        renderNutrientTotals();
      } catch (e) {
        el.innerHTML = '<div class="empty-note">Could not load supplements: ' + e.message + '</div>';
        nutrientMsg('Could not load nutrients: ' + e.message, 'err');
      }
    }
```

- [ ] **Step 3: Refresh ingredients after adding a tablet**

Find (in the `sfSave` handler edited in Task 6):

```javascript
        activeSupplements = [];   // force a refetch so the new one shows up
```

Replace with:

```javascript
        activeSupplements = [];   // force a refetch so the new one shows up
        ingredientsBySupp = {};   // force a refetch so new ingredients are included in totals
```

- [ ] **Step 4: Manual verification**

- Reload `health-log.html`, go to today's date. Confirm "Today's nutrients" shows "No tablets taken yet today."
- Check a tablet with ingredients (amount + unit set in earlier tasks). Confirm the nutrient card immediately shows that ingredient's amount.
- Check a second tablet that shares an ingredient name (same unit) with the first. Confirm the totals **sum** (e.g. 12mg + 10mg → 22mg) rather than showing two separate lines.
- Uncheck one tablet. Confirm totals update immediately (subtract that tablet's contribution).
- Switch `logDate` to a different day with no logged tablets. Confirm the card resets to "No tablets taken yet today."

- [ ] **Step 5: Commit**

```bash
git add health-log.html
git commit -m "feat(supplements): compute and render today's nutrient totals"
```

---

### Task 9: Full end-to-end verification (per spec's Testing section)

**Files:** none (verification only)

- [ ] **Step 1: Two-tablet overlap, same unit**

On `health-log.html`, add tablet "Multi A" with ingredients Vitamin A `10 mg`, Vitamin B `12 mg`. Add tablet "Multi B" with Vitamin B `10 mg`, Vitamin D `15 mg`. Check both tablets for today. Confirm "Today's nutrients" shows:

```
Vitamin A: 10 mg
Vitamin B: 22 mg
Vitamin D: 15 mg
```

- [ ] **Step 2: Conflicting unit blocked**

Add a third tablet "Multi C" with ingredient "Vitamin B" unit `mcg` (conflicts with the `mg` used by Multi A/B). Confirm save is blocked with the unit-conflict message and no partial data is written (refresh `supplement-tracker.html`, confirm Multi C either doesn't exist or has no ingredients, depending on when you attempted the save).

- [ ] **Step 3: Supplement Tracker page unaffected**

Confirm `supplement-tracker.html`'s History table still shows the ✓/✗/— per-day view unchanged, with no nutrient-totals column added there (per spec's explicit scoping).

- [ ] **Step 4: No commit needed** — this task is verification-only. If any check fails, fix the relevant task's code and re-verify before moving on.

---

## Self-Review Notes

- **Spec coverage:** Data model (Task 1) ✓, ingredient entry UI + autocomplete (Tasks 3, 5) ✓, unit-conflict validation (Tasks 4, 6) ✓, Today's nutrients card + computation (Tasks 7, 8) ✓, error handling for fetch failure and save conflict (Tasks 6, 8) ✓, manual testing (Task 9) ✓. Supplement Tracker page explicitly left unchanged beyond ingredient-input/display updates, matching the spec's scoping.
- **Type/naming consistency:** `ingKey`, `findUnitConflict`, `populateIngredientDatalists`, `ingredientsBySupp`, `amount_value`/`amount_unit` are named identically across both files' independent copies (Tasks 3/5, 4/6) and match the DB column names from Task 1.
- **No placeholders:** every step above contains literal, runnable code and exact find/replace targets.
