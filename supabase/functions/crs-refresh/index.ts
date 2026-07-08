// Supabase Edge Function: crs-refresh
// Updates two tables from IRCC pages:
//   • crs_pool  — "CRS score distribution of candidates in the pool as of <date>"
//                 from the rounds-of-invitations page
//   • crs_draws — Express Entry rounds of invitations from the official rounds page
//
// Triggered by the "Check now" button and a weekly cron (supabase/crs_cron.sql).
// No DOM library — parses tables with plain string ops. canada.ca (Akamai) blocks
// bots / resets HTTP/2, so we go through jina reader + proxy fallbacks.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const POOL_URL =
  "https://www.canada.ca/en/immigration-refugees-citizenship/services/immigrate-canada/express-entry/rounds-invitations.html";
const DRAWS_URL =
  "https://www.canada.ca/en/immigration-refugees-citizenship/corporate/mandate/policies-operational-instructions-agreements/ministerial-instructions/express-entry-rounds.html";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36";
const HEADERS = { "User-Agent": UA, "Accept": "text/html,application/xhtml+xml", "Accept-Language": "en-CA,en;q=0.9" };

// Fetch `url`, trying jina reader first (flattens JS + bold), then direct h1 and
// proxies. Returns the first response for which ok(html) is true.
async function fetchDoc(url: string, ok: (h: string) => boolean): Promise<string> {
  const t = () => AbortSignal.timeout(15000);
  const attempts: Array<[string, () => Promise<string>]> = [
    ["jina", async () => (await fetch("https://r.jina.ai/" + url, { headers: HEADERS, signal: t() })).text()],
    ["direct", async () => {
      let client: unknown;
      try { client = (Deno as unknown as { createHttpClient?: (o: unknown) => unknown }).createHttpClient?.({ http2: false }); } catch { /* off */ }
      return await (await fetch(url, { headers: HEADERS, signal: t(), ...(client ? { client } : {}) } as RequestInit)).text();
    }],
    ["allorigins", async () => (await fetch("https://api.allorigins.win/raw?url=" + encodeURIComponent(url), { headers: HEADERS, signal: t() })).text()],
    ["corsproxy", async () => (await fetch("https://corsproxy.io/?url=" + encodeURIComponent(url), { headers: HEADERS, signal: t() })).text()],
  ];
  let last = "";
  for (const [name, a] of attempts) {
    try {
      const html = await a();
      if (ok(html)) { console.log(`fetch ok via ${name} (${html.length} bytes) ${url}`); return html; }
      last = `${name}: ${html.length} bytes, predicate failed`;
      console.log(last);
    } catch (e) { last = `${name}: ${String((e as Error)?.message ?? e)}`; console.error(last); }
  }
  throw new Error("all fetch strategies failed — last: " + last);
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

    // ---- draws (separate page) ----
    let drawsCount = 0;
    let drawsInfo: unknown = null;
    try {
      const drawsHtml = await fetchDoc(DRAWS_URL, (h) => parseDraws(h).draws.length > 0);
      const { draws } = parseDraws(drawsHtml);
      if (draws.length) {
        const { error: de } = await supabase.from("crs_draws").upsert(draws, { onConflict: "draw_number" });
        if (de) drawsInfo = "DB upsert (draws) failed: " + de.message;
        else drawsCount = draws.length;
      }
    } catch (e) {
      // draws are best-effort; include a sample so the parser can be tuned
      try {
        const dh = await fetchDoc(DRAWS_URL, () => true);
        drawsInfo = { error: String((e as Error)?.message ?? e), sample: parseDraws(dh).sample };
      } catch (e2) { drawsInfo = "draws fetch failed: " + String((e2 as Error)?.message ?? e2); }
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

// Express Entry draws (rounds of invitations): #, Date, Round type, Invitations, CRS.
function parseDraws(doc: string) {
  const dateRe = /([A-Za-z]+\.?\s+\d{1,2},?\s+\d{4})/;
  const isInt = (s: string) => /^\d[\d,]*$/.test(s.trim());
  const dated = extractRows(doc).filter((c) => c.length >= 3 && c.some((x) => dateRe.test(x)));
  const seen = new Map<number, unknown>();
  for (const cells of dated) {
    const di = cells.findIndex((c) => dateRe.test(c));
    if (di < 1) continue;                                       // draw number must precede the date
    const draw_number = parseInt((cells[0] || "").replace(/[,\s]/g, ""), 10);
    if (!Number.isInteger(draw_number)) continue;
    const iso = toISODate((cells[di].match(dateRe) || [])[1] || "");
    if (!iso) continue;
    const after = cells.slice(di + 1);
    const nums = after.filter(isInt).map((c) => parseInt(c.replace(/[,\s]/g, ""), 10));
    if (nums.length < 2) continue;
    const round_type = (after.find((c) => c.trim() && !isInt(c)) || "").trim();
    seen.set(draw_number, { draw_number, draw_date: iso, round_type, invitations: nums[nums.length - 2], crs_cutoff: nums[nums.length - 1] });
  }
  return { draws: [...seen.values()], sample: dated.slice(0, 3) };
}

function toISODate(s: string): string | null {
  const d = new Date(s.trim());
  return isNaN(d.getTime()) ? null : d.toISOString().slice(0, 10);
}
