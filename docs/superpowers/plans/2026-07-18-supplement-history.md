# Supplement History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new `supplement-history.html` page showing, per day, the total amount of user-selected ingredients taken across all logged tablets — mirroring `alcohol-history.html`'s layout with a multi-select ingredient picker instead of fixed type columns.

**Architecture:** Single self-contained static HTML page (shell + inline `<style>` + inline `type="module"` script with its own `DB` object), same pattern as every other page in this app (`alcohol-history.html`, `bmi-history.html`, etc.). No shared JS files, no backend/schema changes — read-only against existing `supplement_log` and `supplement_ingredients` tables.

**Tech Stack:** Vanilla JS (ES modules), Supabase JS client v2 (`@supabase/supabase-js` via esm.sh CDN, same as every other page), no build step, no test framework (this repo has none — verification is manual in-browser per project convention).

**Spec:** `docs/superpowers/specs/2026-07-18-supplement-history-design.md`

---

### Task 1: Create `supplement-history.html`

**Files:**
- Create: `supplement-history.html`

- [ ] **Step 1: Write the full page**

Full file content:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
  <title>Health Log - Supplement History — Daily Compass</title>
  <link rel="manifest" href="manifest.json" />
  <link rel="icon" href="icons/icon-192.png" />
  <link rel="apple-touch-icon" href="icons/apple-touch-icon.png" />
  <meta name="theme-color" content="#0f172a" />
  <meta name="apple-mobile-web-app-capable" content="yes" />
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
  <meta name="apple-mobile-web-app-title" content="Compass" />
  <style>
    :root {
      --bg: #0f172a;
      --card: #1e293b;
      --field: #0f172a;
      --border: #334155;
      --text: #e2e8f0;
      --muted: #94a3b8;
      --accent: #38bdf8;
      --accent-press: #0ea5e9;
      --ok: #22c55e;
      --err: #f87171;
      --warn: #f59e0b;
    }
    * { box-sizing: border-box; }
    html { color-scheme: dark; scrollbar-width: none; }
    ::-webkit-scrollbar { display: none; width: 0; height: 0; }
    body {
      margin: 0;
      font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif;
      background: var(--bg);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding-bottom: 48px;
    }
    .wrap { width: 100%; max-width: 1300px; padding: 20px 20px 0; }
    .field {
      background: var(--card); border: 1px solid var(--border);
      border-radius: 14px; padding: 16px; margin-bottom: 14px;
    }
    .hidden { display: none !important; }
    /* topbar */
    .topbar {
      position: sticky; top: 0; z-index: 50;
      width: 100%;
      display: flex; justify-content: space-between; align-items: center;
      font-size: 0.85rem; color: var(--muted);
      padding: calc(12px + env(safe-area-inset-top)) 20px 12px; border-bottom: 1px solid var(--border);
      background: var(--bg);
    }
    .topbar-title { font-weight: 700; font-size: 1rem; color: var(--text); }
    .link-btn {
      background: none; border: none; color: var(--accent);
      cursor: pointer; font-size: 0.8rem; padding: 0; text-decoration: none;
    }
    /* ---- side drawer nav ---- */
    .hamburger {
      background: none; border: none; color: var(--text);
      font-size: 1.4rem; line-height: 1; cursor: pointer; padding: 0;
    }
    .sidebar {
      position: fixed; top: 0; left: 0; bottom: 0; width: 260px; max-width: 82vw;
      background: var(--card); border-right: 1px solid var(--border);
      transform: translateX(-100%); transition: transform 0.22s ease;
      z-index: 110; display: flex; flex-direction: column; gap: 4px;
      padding: 16px 12px;
    }
    .sidebar.open { transform: translateX(0); }
    .sidebar-head {
      display: flex; align-items: center; justify-content: space-between;
      padding: 4px 8px 6px; margin-bottom: 8px;
    }
    .sidebar-title { font-weight: 700; font-size: 1.05rem; }
    .sidebar-close {
      background: none; border: none; color: var(--muted);
      font-size: 1.2rem; line-height: 1; cursor: pointer; padding: 4px;
    }
    .sidebar-backdrop {
      position: fixed; inset: 0; background: rgba(0, 0, 0, 0.5);
      z-index: 105; opacity: 0; pointer-events: none; transition: opacity 0.22s;
    }
    .sidebar-backdrop.open { opacity: 1; pointer-events: auto; }
    /* ---- tree nav (explorer style) ---- */
    .tree { display: flex; flex-direction: column; gap: 1px; margin-top: 4px; }
    .tnode {
      display: flex; align-items: center; gap: 6px;
      padding: 6px 8px; border-radius: 6px;
      color: var(--text); text-decoration: none; font-size: 0.9rem;
      cursor: pointer; white-space: nowrap; user-select: none;
    }
    .tnode:hover { background: var(--field); }
    .tnode.active { background: var(--field); color: var(--accent); font-weight: 600; }
    .tnode.soon { opacity: 0.5; pointer-events: none; }
    .nav-badge {
      margin-left: auto; background: var(--err); color: #2a0505;
      font-size: 0.68rem; font-weight: 700; line-height: 1;
      border-radius: 999px; padding: 2px 6px;
    }
    .tw { width: 1em; font-size: 0.62rem; color: var(--muted); display: inline-block; text-align: center; transition: transform 0.15s; }
    .tw-sp { width: 1em; display: inline-block; }
    .tchildren { padding-left: 14px; }
    .tchildren.collapsed { display: none; }
    .tfolder.collapsed .tw { transform: rotate(-90deg); }
    /* ---- ingredient picker ---- */
    .chip-row { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 12px; }
    .chip {
      display: inline-flex; align-items: center; gap: 6px;
      background: var(--field); border: 1px solid var(--border); border-radius: 999px;
      padding: 6px 12px; font-size: 0.82rem; cursor: pointer; user-select: none;
    }
    .chip input { margin: 0; }
    .chip.checked { border-color: var(--accent); color: var(--accent); }
    /* ---- data table ---- */
    .data-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px; }
    .data-head h2 { margin: 0; font-size: 1rem; }
    .range-bar { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin-bottom: 10px; }
    .muted-note { color: var(--muted); font-size: 0.82rem; }
    .mini-btn {
      background: var(--accent); color: #06202e; border: none;
      border-radius: 8px; padding: 7px 12px; font-size: 0.82rem; font-weight: 600; cursor: pointer;
    }
    .mini-btn.ghost { background: var(--field); color: var(--text); border: 1px solid var(--border); }
    .mini-btn[data-active="1"] { outline: 2px solid var(--accent); outline-offset: 1px; }
    .range-bar input[type="date"] {
      background: var(--field); border: 1px solid var(--border); color: var(--text);
      border-radius: 8px; padding: 6px 8px; font-size: 0.82rem; color-scheme: dark;
    }
    .table-wrap { overflow: auto; max-height: 75vh; margin-top: 8px; }
    table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
    th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid var(--border); white-space: nowrap; }
    th { color: var(--muted); font-weight: 600; background: var(--card); position: sticky; top: 0; }
    .total-val { border-bottom: 1px dotted var(--muted); cursor: help; font-weight: 600; color: var(--accent); }
    .total-val.zero { color: var(--muted); font-weight: 400; border-bottom: none; cursor: default; }
    .msg { text-align: center; font-size: 0.9rem; margin: 12px 0; min-height: 1.2em; }
    .msg.ok { color: var(--ok); }
    .msg.err { color: var(--err); }
  </style>
</head>
<body>
  <!-- ---- side drawer nav ---- -->
  <div class="sidebar-backdrop" id="navBackdrop"></div>
  <nav class="sidebar" id="sidebar" aria-label="Main menu">
    <div class="sidebar-head">
      <span class="sidebar-title">🧭 Daily Compass</span>
      <button class="sidebar-close" id="navClose" aria-label="Close menu">✕</button>
    </div>
    <div class="tree">
      <a class="tnode" href="index.html"><span class="tw-sp"></span>🏠 Home</a>
      <div class="tfolder tnode collapsed" data-group="g-health"><span class="tw">▾</span>🩺 Health Log</div>
      <div class="tchildren collapsed" id="g-health">
        <a class="tnode" href="health-log.html"><span class="tw-sp"></span>Data Entry</a>
        <a class="tnode" href="bmi-history.html"><span class="tw-sp"></span>⚖️ BMI/BMR History</a>
        <a class="tnode" href="time-history.html"><span class="tw-sp"></span>☀️ Time History</a>
        <a class="tnode" href="alcohol-history.html"><span class="tw-sp"></span>🍸 Alcohol History</a>
        <a class="tnode active" href="supplement-history.html"><span class="tw-sp"></span>💊 Supplement History</a>
      </div>
      <div class="tfolder tnode collapsed" data-group="g-temp"><span class="tw">▾</span>🗓️ Temporary</div>
      <div class="tchildren collapsed" id="g-temp">
        <div class="tfolder tnode collapsed" data-group="g-pr"><span class="tw">▾</span><svg width="14" height="9" viewBox="0 0 30 20" style="vertical-align:-1px;margin-right:4px;" aria-label="Canada"><rect width="30" height="20" fill="#fff" /><rect width="7.5" height="20" fill="#d52b1e" /><rect x="22.5" width="7.5" height="20" fill="#d52b1e" /><path fill="#d52b1e" d="M15 4l1 2.3 2.3-1-0.6 2.4 2.3 0.3-1.7 1.7 1.7 1.7-2.3 0.3 0.6 2.4-2.3-1-1 2.3-1-2.3-2.3 1 0.6-2.4-2.3-0.3 1.7-1.7-1.7-1.7 2.3-0.3-0.6-2.4 2.3 1z" /></svg>Canadian PR</div>
        <div class="tchildren collapsed" id="g-pr">
          <a class="tnode" href="temporary.html#pool"><span class="tw-sp"></span>📈 Pool breakdown</a>
          <a class="tnode" href="temporary.html#growth"><span class="tw-sp"></span>🌱 Growth</a>
          <a class="tnode" href="temporary.html#draws"><span class="tw-sp"></span>🎯 Draws</a>
          <a class="tnode" href="temporary.html#analysis"><span class="tw-sp"></span>🔍 New candidates</a>
          <a class="tnode" href="temporary.html#stats"><span class="tw-sp"></span>📐 Stats</a>
          <a class="tnode" href="temporary.html#quota"><span class="tw-sp"></span>📊 Quota</a>
        </div>
      </div>
      <div class="tfolder tnode collapsed" data-group="g-settings"><span class="tw">▾</span>⚙️ Settings<span class="nav-badge hidden" id="settingsBadge"></span></div>
      <div class="tchildren collapsed" id="g-settings">
        <a class="tnode" href="item-catalog.html"><span class="tw-sp"></span>🗂️ Item Catalog</a>
        <a class="tnode" href="developer.html"><span class="tw-sp"></span>🛠️ Developer</a>
        <a class="tnode" href="thresholds.html"><span class="tw-sp"></span>🎯 Thresholds</a>
      </div>
    </div>
  </nav>

  <div class="topbar">
    <button class="hamburger" id="navToggle" aria-label="Open menu">☰</button>
    <span class="topbar-title">💊 Supplement History</span>
    <button class="link-btn" id="logoutBtn">Log out</button>
  </div>

  <div class="wrap">
    <div id="appView" class="hidden">

      <section class="field">
        <div class="data-head">
          <h2>Ingredients taken per day</h2>
          <button class="link-btn" id="refreshBtn">↻ Refresh</button>
        </div>
        <div class="muted-note" style="margin-bottom:10px;">
          Pick one or more ingredients below. Amounts are per-tablet amount × quantity taken, summed across every tablet logged that day. Ingredients logged under different units count as separate entries.
        </div>
        <div id="pickerMsg" class="msg"></div>
        <div class="chip-row" id="ingredientPicker"></div>

        <div class="range-bar">
          <button class="mini-btn" id="rangeLast50" data-active="1">Last 50 days</button>
          <button class="mini-btn ghost" id="rangeAll">All data</button>
          <label class="muted-note" for="rangeFrom">From</label>
          <input type="date" id="rangeFrom" />
          <label class="muted-note" for="rangeTo">To</label>
          <input type="date" id="rangeTo" />
          <button class="mini-btn ghost" id="rangeApply">Apply</button>
        </div>
        <div class="range-bar">
          <span class="muted-note">Sort:</span>
          <button class="mini-btn" id="sortDateDesc" data-active="1">Date ↓ newest</button>
          <button class="mini-btn ghost" id="sortDateAsc">Date ↑ oldest</button>
        </div>
        <div class="msg" id="dataMsg"></div>
        <div class="table-wrap">
          <table id="dataTable">
            <thead>
              <tr id="tableHeadRow"><th>Date</th></tr>
            </thead>
            <tbody id="dataBody"></tbody>
          </table>
        </div>
      </section>

    </div>
  </div>

  <script type="module">
    import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

    // ---- config (anon/publishable key; RLS protects data) ----
    const SUPABASE_URL = 'https://twpzcszcvylhaopcwqkv.supabase.co';
    const SUPABASE_KEY = 'sb_publishable_c1BhUlrZPf2YsXW_5LdrZw_-wYh4lJM';
    const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

    const DB = {
      onAuthChange(cb) { supabase.auth.onAuthStateChange((_e, s) => cb(s)); },
      async currentSession() { const { data } = await supabase.auth.getSession(); return data.session; },
      async signOut() { await supabase.auth.signOut(); },
      // from/to are inclusive log_date bounds; pass null for either to leave
      // that side open. Only taken=true rows matter for totals. Paginated —
      // Supabase caps unbounded queries at 1000 rows regardless of .limit().
      async supplementLogInRange(fromDate, toDate) {
        const PAGE = 1000;
        let all = [];
        let offset = 0;
        while (true) {
          let q = supabase.from('supplement_log')
            .select('log_date, supplement, quantity')
            .eq('taken', true)
            .order('log_date', { ascending: true })
            .range(offset, offset + PAGE - 1);
          if (fromDate) q = q.gte('log_date', fromDate);
          if (toDate) q = q.lte('log_date', toDate);
          const { data, error } = await q;
          if (error) throw error;
          all = all.concat(data);
          if (data.length < PAGE) break;
          offset += PAGE;
        }
        return all;
      },
      // earliest ever taken=true log date, for "All data"'s lower bound
      async earliestSupplementLogDate() {
        const { data, error } = await supabase.from('supplement_log')
          .select('log_date').eq('taken', true).order('log_date', { ascending: true }).limit(1);
        if (error) throw error;
        return data.length ? data[0].log_date : null;
      },
      // every ingredient row for every tablet ever created (active or
      // archived — historical log rows can reference an archived tablet).
      async allSupplementIngredients() {
        const { data, error } = await supabase.from('supplement_ingredients')
          .select('supplement, ingredient, amount_value, amount_unit');
        if (error) throw error;
        return data;
      },
    };

    const $ = id => document.getElementById(id);
    const pad = n => String(n).padStart(2, '0');
    // Local calendar date, NOT toISOString().slice(0,10) — that's UTC-based
    // and shifts the date backward for positive-UTC-offset zones (e.g. IST)
    // whenever local time is past UTC midnight. log_date everywhere else in
    // this app is a local calendar date, so date math here has to match.
    const isoDate = d => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
    const todayDate = () => isoDate(new Date());
    const round2 = n => Math.round(n * 100) / 100;

    // ---- side drawer nav ----
    const openNav  = () => { $('sidebar').classList.add('open'); $('navBackdrop').classList.add('open'); };
    const closeNav = () => { $('sidebar').classList.remove('open'); $('navBackdrop').classList.remove('open'); };
    $('navToggle').addEventListener('click', openNav);
    $('navClose').addEventListener('click', closeNav);
    $('navBackdrop').addEventListener('click', closeNav);
    (function updateSettingsBadge() {
      try {
        const log = JSON.parse(localStorage.getItem('dc_dev_errors') || '[]');
        const badge = document.getElementById('settingsBadge');
        if (badge && log.length) { badge.textContent = log.length; badge.classList.remove('hidden'); }
      } catch { /* localStorage unavailable */ }
    })();
    document.addEventListener('keydown', e => { if (e.key === 'Escape') closeNav(); });
    $('sidebar').addEventListener('click', e => {
      const f = e.target.closest('.tfolder');
      if (f) {
        const g = document.getElementById(f.dataset.group);
        if (g) g.classList.toggle('collapsed');
        f.classList.toggle('collapsed');
        return;
      }
      if (e.target.closest('a.tnode')) closeNav();
    });

    $('logoutBtn').addEventListener('click', async () => { await DB.signOut(); });

    function dataMsg(text, kind) {
      const el = $('dataMsg'); el.textContent = text || '';
      el.className = 'msg' + (kind ? ' ' + kind : '');
    }
    function pickerMsg(text, kind) {
      const el = $('pickerMsg'); el.textContent = text || '';
      el.className = 'msg' + (kind ? ' ' + kind : '');
    }

    // Every calendar date from `from` to `to` inclusive, newest first.
    function dateRangeDesc(from, to) {
      const out = [];
      const start = new Date(from + 'T00:00:00');
      const end = new Date(to + 'T00:00:00');
      for (let d = new Date(end); d >= start; d.setDate(d.getDate() - 1)) {
        out.push(isoDate(d));
      }
      return out;
    }

    // ================================================================
    // Ingredient picker
    // ================================================================
    // Key is (ingredient name, unit) — not name alone. item-catalog.html
    // doesn't enforce one unit per ingredient name across tablets, so
    // keying on the pair keeps mismatched units (e.g. Vitamin D3 as IU in
    // one tablet, mcg in another) as separate, independently-summable
    // entries instead of silently mixing them.
    const keyOf = (ingredient, unit) => `${ingredient} ${unit}`;

    let ingredientRows = [];         // raw supplement_ingredients rows
    let ingredientsBySupplement = {}; // supplement name -> [{key, ingredient, unit, amount_value}]
    let selectedKeys = new Set();

    function indexIngredients() {
      ingredientsBySupplement = {};
      for (const r of ingredientRows) {
        if (r.amount_value == null || !r.amount_unit) continue; // can't sum/label without both
        const key = keyOf(r.ingredient, r.amount_unit);
        (ingredientsBySupplement[r.supplement] ||= []).push({
          key, ingredient: r.ingredient, unit: r.amount_unit, amount_value: r.amount_value,
        });
      }
    }

    function ingredientOptions() {
      const seen = new Map(); // key -> {ingredient, unit}
      for (const r of ingredientRows) {
        if (r.amount_value == null || !r.amount_unit) continue;
        const key = keyOf(r.ingredient, r.amount_unit);
        if (!seen.has(key)) seen.set(key, { key, ingredient: r.ingredient, unit: r.amount_unit });
      }
      return [...seen.values()].sort((a, b) =>
        a.ingredient.localeCompare(b.ingredient) || a.unit.localeCompare(b.unit));
    }

    function renderPicker() {
      const opts = ingredientOptions();
      const el = $('ingredientPicker');
      if (!opts.length) {
        el.innerHTML = '<span class="muted-note">No ingredient data yet — add ingredients in Item Catalog.</span>';
        return;
      }
      el.innerHTML = opts.map(o => {
        const checked = selectedKeys.has(o.key);
        const safeKey = o.key.replace(/"/g, '&quot;');
        return `<label class="chip ${checked ? 'checked' : ''}">` +
          `<input type="checkbox" data-key="${safeKey}" ${checked ? 'checked' : ''} />` +
          `${o.ingredient} (${o.unit})</label>`;
      }).join('');
      el.querySelectorAll('input[type="checkbox"]').forEach(cb => {
        cb.addEventListener('change', () => {
          if (cb.checked) selectedKeys.add(cb.dataset.key);
          else selectedKeys.delete(cb.dataset.key);
          cb.closest('.chip').classList.toggle('checked', cb.checked);
          renderTable();
        });
      });
    }

    // ================================================================
    // Table
    // ================================================================
    let currentRange = { from: null, to: null };
    let currentSort = 'date-desc';
    let lastLogRows = [];   // cached supplement_log rows for currentRange

    function cellFor(amount, contributors, unit) {
      if (!amount) return '<td><span class="total-val zero">—</span></td>';
      const tip = contributors.map(c => `${c.supplement}: ${c.amount}${unit}`).join('\n').replace(/"/g, '&quot;');
      return `<td><span class="total-val" title="${tip}">${round2(amount)}</span></td>`;
    }

    function renderRow(dateStr, dayLogRows, selectedOpts) {
      const dateLabel = new Date(`${dateStr}T00:00`)
        .toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric', year: 'numeric' });
      const cells = selectedOpts.map(opt => {
        let amount = 0;
        const contributors = [];
        for (const log of dayLogRows) {
          for (const ing of (ingredientsBySupplement[log.supplement] || [])) {
            if (ing.key !== opt.key) continue;
            const amt = ing.amount_value * (log.quantity ?? 1);
            amount += amt;
            contributors.push({ supplement: log.supplement, amount: round2(amt) });
          }
        }
        return cellFor(amount, contributors, opt.unit);
      }).join('');
      return `<tr><td>${dateLabel}</td>${cells}</tr>`;
    }

    function renderTable() {
      const opts = ingredientOptions().filter(o => selectedKeys.has(o.key));
      $('tableHeadRow').innerHTML = '<th>Date</th>' + opts.map(o => `<th>${o.ingredient} (${o.unit})</th>`).join('');

      const body = $('dataBody');
      if (!opts.length) {
        body.innerHTML = '<tr><td>Pick one or more ingredients above to see their totals per day.</td></tr>';
        return;
      }
      if (!currentRange.from || !currentRange.to) {
        body.innerHTML = `<tr><td colspan="${opts.length + 1}">Nothing yet.</td></tr>`;
        return;
      }
      const byDate = {};
      for (const r of lastLogRows) (byDate[r.log_date] = byDate[r.log_date] || []).push(r);
      let dates = dateRangeDesc(currentRange.from, currentRange.to);
      if (currentSort === 'date-asc') dates = dates.slice().reverse();
      body.innerHTML = dates.map(d => renderRow(d, byDate[d] || [], opts)).join('');
    }

    // ================================================================
    // Load / wiring
    // ================================================================
    async function loadIngredients() {
      try {
        ingredientRows = await DB.allSupplementIngredients();
        indexIngredients();
        renderPicker();
        pickerMsg('', '');
      } catch (e) { pickerMsg('Could not load ingredients: ' + e.message, 'err'); }
    }

    async function loadLogRows() {
      lastLogRows = await DB.supplementLogInRange(currentRange.from, currentRange.to);
      renderTable();
    }

    $('refreshBtn').addEventListener('click', async () => {
      $('refreshBtn').disabled = true;
      try { await loadLogRows(); }
      catch (e) { dataMsg('Refresh failed: ' + e.message, 'err'); }
      finally { $('refreshBtn').disabled = false; }
    });

    const SORT_BTNS = { sortDateDesc: 'date-desc', sortDateAsc: 'date-asc' };
    function setActiveSortBtn(id) {
      Object.keys(SORT_BTNS).forEach(btnId => {
        if (btnId === id) $(btnId).dataset.active = '1';
        else delete $(btnId).dataset.active;
      });
    }
    Object.keys(SORT_BTNS).forEach(btnId => {
      $(btnId).addEventListener('click', () => {
        currentSort = SORT_BTNS[btnId];
        setActiveSortBtn(btnId);
        renderTable();
      });
    });

    function setActiveQuickBtn(id) {
      ['rangeLast50', 'rangeAll'].forEach(btnId => {
        if (btnId === id) $(btnId).dataset.active = '1';
        else delete $(btnId).dataset.active;
      });
    }
    function last50Range() {
      const to = new Date();
      const from = new Date(to.getTime() - 49 * 86400000);
      return { from: isoDate(from), to: isoDate(to) };
    }

    $('rangeLast50').addEventListener('click', async () => {
      currentRange = last50Range();
      $('rangeFrom').value = currentRange.from;
      $('rangeTo').value = currentRange.to;
      setActiveQuickBtn('rangeLast50');
      try { await loadLogRows(); } catch (e) { dataMsg('Could not load: ' + e.message, 'err'); }
    });
    $('rangeAll').addEventListener('click', async () => {
      $('rangeAll').disabled = true;
      try {
        const earliest = await DB.earliestSupplementLogDate();
        currentRange = { from: earliest || todayDate(), to: todayDate() };
        $('rangeFrom').value = currentRange.from;
        $('rangeTo').value = currentRange.to;
        setActiveQuickBtn('rangeAll');
        await loadLogRows();
      } catch (e) { dataMsg('Could not load: ' + e.message, 'err'); }
      finally { $('rangeAll').disabled = false; }
    });
    $('rangeApply').addEventListener('click', async () => {
      if (!$('rangeFrom').value || !$('rangeTo').value) { dataMsg('Pick both From and To.', 'err'); return; }
      currentRange = { from: $('rangeFrom').value, to: $('rangeTo').value };
      setActiveQuickBtn(null);
      try { await loadLogRows(); } catch (e) { dataMsg('Could not load: ' + e.message, 'err'); }
    });

    // ---- route: no session → sign in on the picker page ----
    function showLogin() { window.location.replace('index.html'); }
    async function showApp() {
      $('appView').classList.remove('hidden');
      currentRange = last50Range();
      $('rangeFrom').value = currentRange.from;
      $('rangeTo').value = currentRange.to;
      await loadIngredients();
      try { await loadLogRows(); } catch (e) { dataMsg('Could not load: ' + e.message, 'err'); }
    }

    DB.onAuthChange(session => { if (session) showApp(); else showLogin(); });
    DB.currentSession().then(s => { if (s) showApp(); else showLogin(); });
  </script>
</body>
</html>
```

- [ ] **Step 2: Open the page and confirm it loads**

Open `supplement-history.html` directly in a browser (already-logged-in session, e.g. same browser you use for Item Catalog).
Expected: page loads with no console errors, sidebar shows "💊 Supplement History" highlighted active, ingredient chips appear below "Ingredients taken per day" (built from whatever's currently in `supplement_ingredients`), table shows the "Pick one or more ingredients..." placeholder row since nothing is selected yet.

- [ ] **Step 3: Commit**

```bash
git add supplement-history.html
git commit -m "$(cat <<'EOF'
feat(supplements): add Supplement History page

Day-by-day ingredient totals view mirroring Alcohol History's layout,
with a multi-select ingredient picker (keyed on name+unit, since the
app doesn't enforce one unit per ingredient name across tablets) in
place of fixed type columns.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Add sidebar nav link to every other page

**Files:**
- Modify: `index.html:180`
- Modify: `health-log.html:422`
- Modify: `bmi-history.html:187`
- Modify: `time-history.html:206`
- Modify: `alcohol-history.html:155`
- Modify: `item-catalog.html:198`
- Modify: `developer.html:149`
- Modify: `thresholds.html:160`
- Modify: `temporary.html:297`
- Modify: `all-data.html:171`

Every one of these files has this exact line in its sidebar `g-health` block:

```html
        <a class="tnode" href="alcohol-history.html"><span class="tw-sp"></span>🍸 Alcohol History</a>
```

(In `alcohol-history.html` itself it's `class="tnode active"` instead of `class="tnode"` — same fix applies, just match the line as it exists in that file.)

- [ ] **Step 1: Edit `index.html`**

Old:
```html
        <a class="tnode" href="alcohol-history.html"><span class="tw-sp"></span>🍸 Alcohol History</a>
```
New:
```html
        <a class="tnode" href="alcohol-history.html"><span class="tw-sp"></span>🍸 Alcohol History</a>
        <a class="tnode" href="supplement-history.html"><span class="tw-sp"></span>💊 Supplement History</a>
```

- [ ] **Step 2: Edit `health-log.html`** (same old/new as Step 1)

- [ ] **Step 3: Edit `bmi-history.html`** (same old/new as Step 1)

- [ ] **Step 4: Edit `time-history.html`** (same old/new as Step 1)

- [ ] **Step 5: Edit `alcohol-history.html`**

Old:
```html
        <a class="tnode active" href="alcohol-history.html"><span class="tw-sp"></span>🍸 Alcohol History</a>
```
New:
```html
        <a class="tnode active" href="alcohol-history.html"><span class="tw-sp"></span>🍸 Alcohol History</a>
        <a class="tnode" href="supplement-history.html"><span class="tw-sp"></span>💊 Supplement History</a>
```

- [ ] **Step 6: Edit `item-catalog.html`** (same old/new as Step 1)

- [ ] **Step 7: Edit `developer.html`** (same old/new as Step 1)

- [ ] **Step 8: Edit `thresholds.html`** (same old/new as Step 1)

- [ ] **Step 9: Edit `temporary.html`** (same old/new as Step 1)

- [ ] **Step 10: Edit `all-data.html`** (same old/new as Step 1)

- [ ] **Step 11: Spot-check one page in the browser**

Open `health-log.html`, open the sidebar, expand Health Log — confirm "💊 Supplement History" appears right after "🍸 Alcohol History" and clicking it navigates to `supplement-history.html`.

- [ ] **Step 12: Commit**

```bash
git add index.html health-log.html bmi-history.html time-history.html alcohol-history.html item-catalog.html developer.html thresholds.html temporary.html all-data.html
git commit -m "$(cat <<'EOF'
feat(nav): add Supplement History link to sidebar

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Manual verification pass

No automated test suite exists in this repo (static HTML pages, verified manually per project convention — see spec's Testing section). Run through each scenario in the browser against real data, using Item Catalog to check/adjust ingredient data as needed.

- [ ] **Step 1: Single-ingredient sum**

In Item Catalog, note an ingredient that appears in exactly one tablet (e.g. one of Centrum Men's, if that's the only tablet with it), with a known `amount_value`/`amount_unit`. In Data Entry, confirm it was logged taken (with a known quantity) on a few known dates. On Supplement History, pick that ingredient's chip, confirm the cell value for those dates equals `amount_value × quantity` by hand-calculation, and other dates show `—`.

- [ ] **Step 2: Multi-tablet sum on the same day**

Find (or temporarily create in Item Catalog) two tablets that share an ingredient name + unit (e.g. both have "Zinc (mg)"). Log both as taken on the same date. Pick that ingredient's chip on Supplement History, confirm that day's cell equals the sum of both tablets' contributions, and hovering the cell shows a tooltip listing both tablets separately.

- [ ] **Step 3: Same name, different units stay separate**

In Item Catalog, find or create two tablets where the same ingredient name is entered with two different units (e.g. "Vitamin D3" as `mcg` in one, `IU` in another). Confirm Supplement History's picker shows these as two distinct chips (`Vitamin D3 (mcg)` and `Vitamin D3 (IU)`), not merged into one.

- [ ] **Step 4: Archived tablet still resolves**

Archive a tablet in Item Catalog that has historical `supplement_log` entries. Confirm its ingredient's chip still appears in the picker and its historical days still show correct amounts on Supplement History (archiving must not hide past data).

- [ ] **Step 5: Range and sort controls**

On Supplement History: confirm "Last 50 days" is the default range on load, "All data" expands to the earliest taken=true log date, custom From/To + Apply works, and toggling "Date ↑ oldest" / "Date ↓ newest" reorders rows without refetching (should feel instant — no network delay).

- [ ] **Step 6: Empty states**

Deselect all ingredient chips — confirm the table reverts to the "Pick one or more ingredients above..." message. If the picker itself has zero data (only relevant if testing against a fresh DB with no ingredients yet), confirm it shows "No ingredient data yet — add ingredients in Item Catalog." instead of an empty chip row.

No commit for this task — verification only, no code changes expected. If any scenario fails, fix the underlying code in `supplement-history.html` and re-run the failed scenario before moving on.
