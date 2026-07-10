// Supabase Edge Function: crs-refresh
// Updates two tables from IRCC pages:
//   • crs_pool  — "CRS score distribution of candidates in the pool as of <date>"
//                 from the rounds-of-invitations page
//   • crs_draws — Express Entry rounds of invitations, from the dedicated rounds
//                 page's table (# / Date / Round type / Invitations issued / CRS)
//
// Triggered by the "Check now" button and a weekly cron (supabase/crs_cron.sql).
// No DOM library — parses tables with plain string ops. canada.ca (Akamai) blocks
// bots / resets HTTP/2, so we fetch through the jina reader (renders JS, proven
// reliable) with a direct-h1 fallback. corsproxy.io is NOT used — free tier is
// paywalled (403). allorigins kept as a last resort.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const POOL_URL =
  "https://www.canada.ca/en/immigration-refugees-citizenship/services/immigrate-canada/express-entry/rounds-invitations.html";
const DRAWS_PAGE_URL =
  "https://www.canada.ca/en/immigration-refugees-citizenship/corporate/mandate/policies-operational-instructions-agreements/ministerial-instructions/express-entry-rounds.html";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36";
const HEADERS = { "User-Agent": UA, "Accept": "text/html,application/xhtml+xml", "Accept-Language": "en-CA,en;q=0.9" };

// Fetch `url`, trying jina reader first (renders JS, flattens bold/markdown —
// proven reliable for the pool table), then direct h1, then allorigins.
// Returns the first response for which ok(html) is true. On total failure, throw
// with EVERY attempt's status/bytes/snippet — not just the last — so the real
// cause is visible.
// diagPhrases: on failure, search the doc for these and show a snippet around
// the first hit — reveals whether/where real content landed even if `ok()`
// (the strict parser) didn't recognize it.
async function fetchDoc(url: string, ok: (h: string) => boolean, diagPhrases: string[] = []): Promise<string> {
  const t = () => AbortSignal.timeout(20000);
  const attempts: Array<[string, () => Promise<string>]> = [
    // No spoofed browser UA here — jina uses its own fetch internally, and
    // forwarding our headers to jina's own request changes its behavior.
    ["jina", async () => {
      const r = await fetch("https://r.jina.ai/" + url, { signal: t() });
      return `[${r.status}] ` + await r.text();
    }],
    ["direct", async () => {
      let client: unknown;
      try { client = (Deno as unknown as { createHttpClient?: (o: unknown) => unknown }).createHttpClient?.({ http2: false }); } catch { /* off */ }
      const r = await fetch(url, { headers: HEADERS, signal: t(), ...(client ? { client } : {}) } as RequestInit);
      return `[${r.status}] ` + await r.text();
    }],
    ["allorigins", async () => {
      const r = await fetch("https://api.allorigins.win/raw?url=" + encodeURIComponent(url), { headers: HEADERS, signal: t() });
      return `[${r.status}] ` + await r.text();
    }],
  ];
  const log: string[] = [];
  for (const [name, a] of attempts) {
    try {
      const tagged = await a();
      const html = tagged.replace(/^\[\d+\]\s*/, "");
      if (ok(html)) { console.log(`fetch ok via ${name} (${html.length} bytes) ${url}`); return html; }
      let hint = "";
      for (const p of diagPhrases) {
        const i = html.toLowerCase().indexOf(p.toLowerCase());
        if (i >= 0) { hint = ` | found "${p}" at ${i}: ${html.slice(i, i + 200).replace(/\s+/g, " ")}`; break; }
      }
      if (!hint && diagPhrases.length) hint = " | none of the diag phrases found in doc";
      log.push(`${name}: ${tagged.length} bytes, head: ${tagged.slice(0, 100).replace(/\s+/g, " ")}${hint}`);
    } catch (e) { log.push(`${name}: threw ${String((e as Error)?.message ?? e)}`); }
  }
  console.error(`fetchDoc all attempts for ${url}:\n` + log.join("\n"));
  throw new Error("all fetch strategies failed — " + log.join(" | "));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // ---- pool distribution ----
    const poolHtml = await fetchDoc(POOL_URL, (h) => /distribution of candidates in the pool as of/i.test(h));
    const parsed = parsePool(poolHtml);
    if (!parsed) return json({ error: "Could not locate the distribution table." }, 200);
    if (!parsed.distribution.length) return json({ error: "No known CRS bands matched.", sawLabels: parsed.sawLabels }, 200);

    const { error } = await supabase.from("crs_pool").upsert({
      pool_date: parsed.pool_date, distribution: parsed.distribution, total: parsed.total,
      source_url: POOL_URL, fetched_at: new Date().toISOString(),
    }, { onConflict: "pool_date" });
    if (error) return json({ error: "DB upsert (pool) failed: " + error.message }, 200);

    // ---- draws: scrape the official rounds table (header-anchored parse) ----
    let drawsCount = 0;
    let drawsInfo: unknown = null;
    try {
      const drawsDoc = await fetchDoc(
        DRAWS_PAGE_URL,
        (h) => parseDrawsTable(h).draws.length > 0,
        ["Round type", "Invitations issued", "lowest-ranked"],
      );
      const dt = parseDrawsTable(drawsDoc);
      if (dt.draws.length) {
        const { error: de } = await supabase.from("crs_draws").upsert(dt.draws, { onConflict: "draw_number" });
        if (de) drawsInfo = "DB upsert (draws) failed: " + de.message;
        else drawsCount = dt.draws.length;
      } else drawsInfo = dt.diag;
    } catch (e) {
      drawsInfo = "draws failed: " + String((e as Error)?.message ?? e);
    }

    return json({ pool_date: parsed.pool_date, rows: parsed.distribution.length, total: parsed.total, drawsCount, drawsInfo });
  } catch (e) {
    return json({ error: "Function error: " + String((e as Error)?.message ?? e) }, 200);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

const TOP = ["601-1200", "501-600", "451-500", "401-450", "351-400", "301-350", "0-300"];
const SUB = ["491-500", "481-490", "471-480", "461-470", "451-460", "441-450", "431-440", "421-430", "411-420", "401-410"];
const KNOWN = new Set([...TOP, ...SUB]);

const stripTags = (s: string) =>
  s.replace(/<[^>]*>/g, "").replace(/&nbsp;/gi, " ").replace(/&amp;/gi, "&")
    .replace(/[*_`]/g, "").replace(/\s+/g, " ").trim();
const normBand = (s: string) => s.replace(/[‒-―−]/g, "-").replace(/\s+/g, "");

// All table rows in the document (HTML tables, or markdown pipe lines).
function extractRows(doc: string): string[][] {
  const tables = doc.match(/<table[\s\S]*?<\/table>/gi);
  if (tables && tables.length) {
    const rows: string[][] = [];
    for (const tbl of tables) {
      for (const tr of tbl.match(/<tr[\s\S]*?<\/tr>/gi) ?? []) {
        rows.push((tr.match(/<t[hd](?:\s[^>]*)?>([\s\S]*?)<\/t[hd]>/gi) ?? []).map(stripTags));
      }
    }
    return rows;
  }
  return doc.split("\n").filter((l) => l.includes("|")).map((l) => l.split("|").map((c) => stripTags(c)).filter((c) => c !== ""));
}

function parsePool(doc: string) {
  const idx = doc.search(/distribution of candidates in the pool as of/i);
  if (idx < 0) return null;
  const win = stripTags(doc.slice(idx, idx + 260));
  const dm = win.match(/as of\s*[:\-]?\s*([A-Za-z]+\.?\s+\d{1,2},?\s+\d{4}|\d{1,2}\s+[A-Za-z]+\.?,?\s+\d{4})/i);
  const pool_date = dm ? toISODate(dm[1]) : null;
  if (!pool_date) return null;

  const found = new Map<string, number>();
  const sawLabels: string[] = [];
  for (const cells of extractRows(doc)) {
    if (cells.length < 2) continue;
    const label = normBand(cells[0]);
    const count = parseInt(cells[cells.length - 1].replace(/[,\s]/g, ""), 10);
    if (Number.isNaN(count)) continue;
    sawLabels.push(cells[0]);
    if (KNOWN.has(label) && !found.has(label)) found.set(label, count);
  }
  const distribution = [...TOP, ...SUB].filter((k) => found.has(k)).map((k) => ({ range: k, count: found.get(k)! }));
  const total = TOP.filter((k) => found.has(k)).reduce((a, k) => a + found.get(k)!, 0) || null;
  return { pool_date, distribution, total, sawLabels };
}

// Parse the draws table by locating its header row (the official column names:
// #, Date, Round type, Invitations issued, CRS score of lowest-ranked candidate
// invited) and reading columns by index — sturdier than guessing row shape.
function parseDrawsTable(doc: string) {
  const rows = extractRows(doc);
  const norm = (s: string) => (s || "").toLowerCase().replace(/\s+/g, " ").trim();
  let headerIdx = -1, col = { num: -1, date: -1, type: -1, inv: -1, crs: -1 };
  for (let i = 0; i < rows.length; i++) {
    const cells = rows[i].map(norm);
    const numI = cells.findIndex((c) => c === "#" || c === "draw" || c === "draw #" || c === "draw number");
    const dateI = cells.findIndex((c) => c === "date");
    const typeI = cells.findIndex((c) => c.includes("round type") || c.includes("category"));
    const invI = cells.findIndex((c) => c.includes("invitations"));
    const crsI = cells.findIndex((c) => c.includes("crs score") || c === "crs" || c.includes("lowest-ranked"));
    if (numI >= 0 && dateI >= 0 && invI >= 0 && crsI >= 0) {
      headerIdx = i; col = { num: numI, date: dateI, type: typeI, inv: invI, crs: crsI };
      break;
    }
  }
  if (headerIdx < 0) return { draws: [], diag: { headerFound: false, rowSample: rows.slice(0, 5) } };

  const isInt = (s: string) => /^\d[\d,]*$/.test((s || "").trim());
  const seen = new Map<number, unknown>();
  for (const cells of rows.slice(headerIdx + 1)) {
    const numRaw = (cells[col.num] || "").replace(/[,\s]/g, "");
    const draw_number = parseInt(numRaw, 10);
    if (!Number.isInteger(draw_number)) continue;
    const draw_date = toISODate(cells[col.date] || "");
    if (!draw_date) continue;
    const invitations = isInt(cells[col.inv]) ? parseInt(cells[col.inv].replace(/[,\s]/g, ""), 10) : null;
    const crsCell = (cells[col.crs] || "").replace(/[,\s]/g, "");
    const crs_cutoff = /^\d+$/.test(crsCell) ? parseInt(crsCell, 10) : null;
    const round_type = col.type >= 0 ? (cells[col.type] || "").trim() || null : null;
    seen.set(draw_number, { draw_number, draw_date, round_type, invitations, crs_cutoff });
  }
  const draws = [...seen.values()];
  return { draws, diag: { headerFound: true, col, rowsAfterHeader: rows.length - headerIdx - 1, parsed: draws.length } };
}

function toISODate(s: string): string | null {
  const d = new Date(s.trim());
  return isNaN(d.getTime()) ? null : d.toISOString().slice(0, 10);
}
