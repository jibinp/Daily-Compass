// Supabase Edge Function: crs-refresh
// Fetches the IRCC rounds-of-invitations page, extracts the
// "CRS score distribution of candidates in the pool as of <date>" table,
// and upserts it into crs_pool (keyed by pool_date).
//
// Triggered two ways:
//   • the "Check now" button (browser → supabase.functions.invoke)
//   • a weekly cron (see supabase/crs_cron.sql)
//
// No DOM library — parses the table with plain string ops so it bundles cleanly.
// IRCC returns 403 to plain bots, so we send a browser User-Agent.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const IRCC_URL =
  "https://www.canada.ca/en/immigration-refugees-citizenship/services/immigrate-canada/express-entry/rounds-invitations.html";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36";
const HEADERS = { "User-Agent": UA, "Accept": "text/html,application/xhtml+xml", "Accept-Language": "en-CA,en;q=0.9" };
const hasTable = (h: string) => /distribution of candidates in the pool as of/i.test(h);

// canada.ca (Akamai) resets Deno's HTTP/2 stream. Try direct over HTTP/1.1, then
// server-side proxies (which reach canada.ca over h1). Return the first response
// that actually contains the distribution section.
async function fetchHtml(): Promise<{ html: string; via: string }> {
  const t = () => AbortSignal.timeout(15000);      // fail fast, try next
  const attempts: Array<[string, () => Promise<string>]> = [
    ["direct", async () => {
      let client: unknown;
      try { client = (Deno as unknown as { createHttpClient?: (o: unknown) => unknown }).createHttpClient?.({ http2: false }); } catch { /* unstable API off */ }
      const r = await fetch(IRCC_URL, { headers: HEADERS, signal: t(), ...(client ? { client } : {}) } as RequestInit);
      return await r.text();
    }],
    ["allorigins", async () => (await fetch("https://api.allorigins.win/raw?url=" + encodeURIComponent(IRCC_URL), { headers: HEADERS, signal: t() })).text()],
    ["corsproxy", async () => (await fetch("https://corsproxy.io/?url=" + encodeURIComponent(IRCC_URL), { headers: HEADERS, signal: t() })).text()],
    ["jina", async () => (await fetch("https://r.jina.ai/" + IRCC_URL, { headers: HEADERS, signal: t() })).text()],
  ];
  let last = "";
  for (const [name, a] of attempts) {
    try {
      const html = await a();
      if (hasTable(html)) { console.log(`fetch ok via ${name} (${html.length} bytes)`); return { html, via: name }; }
      last = `${name}: got ${html.length} bytes, no distribution section`;
      console.log(last);
    } catch (e) {
      last = `${name}: ${String((e as Error)?.message ?? e)}`;
      console.error(last);
    }
  }
  throw new Error("all fetch strategies failed — last: " + last);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const { html, via } = await fetchHtml();
    // Diagnostics: is the top-level summary even in what we fetched?
    const s601 = html.search(/601[\s\S]{0,10}1200/);
    const snippet = s601 >= 0 ? stripTags(html.slice(s601 - 40, s601 + 340)) : "(no 601…1200 in payload)";
    const diag = { via, htmlLen: html.length, tables: (html.match(/<table/gi) ?? []).length, has601: s601 >= 0 };
    console.log("diag", JSON.stringify(diag), "snippet:", snippet);

    const parsed = parse(html);
    if (!parsed) {
      return json({ error: "Could not locate the distribution table.", ...diag, snippet }, 200);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    if (parsed.distribution.length) {
      const { error } = await supabase.from("crs_pool").upsert({
        pool_date: parsed.pool_date,
        distribution: parsed.distribution,
        total: parsed.total,
        source_url: IRCC_URL,
        fetched_at: new Date().toISOString(),
      }, { onConflict: "pool_date" });
      if (error) return json({ error: "DB upsert failed: " + error.message }, 200);
    }

    console.log("matched:", parsed.distribution.map((d) => d.range).join(", "));
    console.log("saw:", parsed.sawLabels.join(" | "));
    return json({
      pool_date: parsed.pool_date, rows: parsed.distribution.length, total: parsed.total,
      saw: parsed.sawLabels, ...diag, snippet,
    });
  } catch (e) {
    return json({ error: "Function error: " + String((e as Error)?.message ?? e) }, 200);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

const TOP = ["601-1200", "501-600", "451-500", "401-450", "351-400", "301-350", "0-300"];
const SUB = ["491-500", "481-490", "471-480", "461-470", "451-460",
             "441-450", "431-440", "421-430", "411-420", "401-410"];
const KNOWN = new Set([...TOP, ...SUB]);

const stripTags = (s: string) =>
  s.replace(/<[^>]*>/g, "").replace(/&nbsp;/gi, " ").replace(/&amp;/gi, "&").replace(/\s+/g, " ").trim();
const normBand = (s: string) => s.replace(/[‒-―−]/g, "-").replace(/\s+/g, "");

function parse(doc: string) {
  const idx = doc.search(/distribution of candidates in the pool as of/i);
  if (idx < 0) return null;
  // Date may be wrapped in tags after "as of" — strip tags in a window, then read it.
  const win = stripTags(doc.slice(idx, idx + 260));
  const dm = win.match(/as of\s*[:\-]?\s*([A-Za-z]+\.?\s+\d{1,2},?\s+\d{4}|\d{1,2}\s+[A-Za-z]+\.?,?\s+\d{4})/i);
  const pool_date = dm ? toISODate(dm[1]) : null;
  if (!pool_date) return null;

  // Scan EVERY table in the document — summary and detailed sub-band tables can
  // live in different sections. The KNOWN-band filter below keeps only the
  // distribution rows, so unrelated tables (draw history etc.) are ignored.
  let rows: string[][] = [];
  const tables = doc.match(/<table[\s\S]*?<\/table>/gi);
  if (tables && tables.length) {
    for (const tbl of tables) {
      for (const tr of tbl.match(/<tr[\s\S]*?<\/tr>/gi) ?? []) {
        rows.push((tr.match(/<t[hd](?:\s[^>]*)?>([\s\S]*?)<\/t[hd]>/gi) ?? []).map(stripTags));
      }
    }
  } else {
    rows = doc.split("\n")
      .filter((l) => l.includes("|"))
      .map((l) => l.split("|").map((c) => stripTags(c)).filter((c) => c !== ""));
  }
  console.log(`tables=${tables?.length ?? 0} rows=${rows.length}`);

  const found = new Map<string, number>();
  const sawLabels: string[] = [];
  for (const cells of rows) {
    if (cells.length < 2) continue;
    const label = normBand(cells[0]);
    const count = parseInt(cells[cells.length - 1].replace(/[,\s]/g, ""), 10);
    if (Number.isNaN(count)) continue;
    sawLabels.push(cells[0]);
    if (KNOWN.has(label) && !found.has(label)) found.set(label, count);   // first occurrence wins
  }

  const distribution = [...TOP, ...SUB].filter((k) => found.has(k)).map((k) => ({ range: k, count: found.get(k)! }));
  const total = TOP.filter((k) => found.has(k)).reduce((a, k) => a + found.get(k)!, 0) || null;
  return { pool_date, distribution, total, sawLabels };
}

function toISODate(s: string): string | null {
  const d = new Date(s.trim());
  return isNaN(d.getTime()) ? null : d.toISOString().slice(0, 10);
}
