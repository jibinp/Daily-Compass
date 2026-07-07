// Supabase Edge Function: crs-refresh
// Fetches the IRCC rounds-of-invitations page, extracts the
// "CRS score distribution of candidates in the pool as of <date>" table,
// and upserts it into crs_pool (keyed by pool_date).
//
// Triggered two ways:
//   • the "Check now" button (browser → supabase.functions.invoke)
//   • a weekly cron (see supabase/crs_cron.sql)
//
// Deploy:  supabase functions deploy crs-refresh
// (uses SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY, injected automatically)
//
// NOTE: IRCC returns 403 to plain bots, so we send a browser User-Agent.
// The parser targets the current page layout — if IRCC restructures the page,
// adjust the selectors in parse() below. Manual "Add snapshot" in the app is the
// fallback whenever this can't parse.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { DOMParser, type Element } from "https://esm.sh/@b-fuze/deno-dom@0.1.48/deno-dom-wasm.ts";

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
    if (!res.ok) return json({ error: `IRCC fetch failed: ${res.status}` }, 502);

    const parsed = parse(await res.text());
    if (!parsed) {
      return json({ error: "Could not locate the distribution table (IRCC layout may have changed)." }, 422);
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

function parse(html: string) {
  const doc = new DOMParser().parseFromString(html, "text/html");
  if (!doc) return null;

  // Heading: "CRS score distribution of candidates in the pool as of <date>"
  const headings = [...doc.querySelectorAll("h2,h3,h4,caption")] as Element[];
  const h = headings.find((el) =>
    /distribution of candidates in the pool as of/i.test(el.textContent ?? "")
  );
  if (!h) return null;

  const dm = (h.textContent ?? "").match(/as of\s+(.+?)\s*$/i);
  const pool_date = dm ? toISODate(dm[1]) : null;
  if (!pool_date) return null;

  // Table usually follows the heading.
  let table: Element | null = null;
  let node = h.nextElementSibling;
  for (let hops = 0; node && hops < 8; hops++) {
    if (node.tagName === "TABLE") { table = node; break; }
    const inner = node.querySelector?.("table");
    if (inner) { table = inner as Element; break; }
    node = node.nextElementSibling;
  }
  if (!table) return null;

  const distribution: { range: string; count: number }[] = [];
  let total: number | null = null;
  for (const tr of [...table.querySelectorAll("tr")] as Element[]) {
    const cells = [...tr.querySelectorAll("th,td")].map((c) => (c.textContent ?? "").trim());
    if (cells.length < 2) continue;
    const label = cells[0];
    const count = parseInt(cells[cells.length - 1].replace(/[,\s]/g, ""), 10);
    if (Number.isNaN(count)) continue;
    if (/^total\b/i.test(label)) { total = count; continue; }
    distribution.push({ range: label, count });
  }
  if (!distribution.length) return null;
  return { pool_date, distribution, total };
}

function toISODate(s: string): string | null {
  const d = new Date(s.trim());
  return isNaN(d.getTime()) ? null : d.toISOString().slice(0, 10);
}
