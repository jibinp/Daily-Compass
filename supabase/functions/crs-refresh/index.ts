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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const res = await fetch(IRCC_URL, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml",
        "Accept-Language": "en-CA,en;q=0.9",
      },
    });
    if (!res.ok) return json({ error: `IRCC fetch failed: ${res.status}` }, 200);

    const parsed = parse(await res.text());
    if (!parsed) {
      return json({ error: "Could not locate the distribution table (IRCC layout may have changed)." }, 200);
    }
    if (!parsed.distribution.length) {
      return json({ error: "Table found but no known CRS bands matched.", pool_date: parsed.pool_date, sawLabels: parsed.sawLabels }, 200);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { error } = await supabase.from("crs_pool").upsert({
      pool_date: parsed.pool_date,
      distribution: parsed.distribution,
      total: parsed.total,
      source_url: IRCC_URL,
      fetched_at: new Date().toISOString(),
    }, { onConflict: "pool_date" });
    if (error) return json({ error: error.message }, 500);

    return json({ pool_date: parsed.pool_date, rows: parsed.distribution.length, total: parsed.total });
  } catch (e) {
    return json({ error: String((e as Error)?.message ?? e) }, 500);
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

function parse(html: string) {
  // Heading: "... distribution of candidates in the pool as of <date>"
  const hm = html.match(/distribution of candidates in the pool as of\s*([^<]+?)\s*</i);
  if (!hm) return null;
  const pool_date = toISODate(stripTags(hm[1]));
  if (!pool_date) return null;

  // First <table> after the heading.
  const after = html.slice(hm.index ?? 0);
  const tm = after.match(/<table[\s\S]*?<\/table>/i);
  if (!tm) return null;

  const rows = tm[0].match(/<tr[\s\S]*?<\/tr>/gi) ?? [];
  const found = new Map<string, number>();
  const sawLabels: string[] = [];
  for (const rowHtml of rows) {
    const cells = (rowHtml.match(/<t[hd](?:\s[^>]*)?>([\s\S]*?)<\/t[hd]>/gi) ?? []).map(stripTags);
    if (cells.length < 2) continue;
    const label = normBand(cells[0]);
    const count = parseInt(cells[cells.length - 1].replace(/[,\s]/g, ""), 10);
    if (Number.isNaN(count)) continue;
    sawLabels.push(cells[0]);
    if (KNOWN.has(label)) found.set(label, count);
  }

  const distribution = [...TOP, ...SUB].filter((k) => found.has(k)).map((k) => ({ range: k, count: found.get(k)! }));
  const total = TOP.filter((k) => found.has(k)).reduce((a, k) => a + found.get(k)!, 0) || null;
  return { pool_date, distribution, total, sawLabels };
}

function toISODate(s: string): string | null {
  const d = new Date(s.trim());
  return isNaN(d.getTime()) ? null : d.toISOString().slice(0, 10);
}
