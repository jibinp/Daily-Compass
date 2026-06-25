# Daily Compass — High-Level Design (HLD)

**Date:** 2026-06-24
**Status:** Approved (high-level)
**Owner:** jp

## 1. Purpose

Daily Compass is a personal, single-user web app for recording dated and timed
events across different aspects of the owner's life (e.g. work, health,
personal). The owner enters events, views them, and sees upcoming events
highlighted on the page. The app is reachable from any device the owner uses —
personal laptop, company laptop, phone — and always shows the same data.

## 2. Goals and Non-Goals

### Goals (v1)
- Log in securely from any device.
- Add an event with an aspect, title, date/time, and optional notes.
- View events as a list and on a calendar.
- See upcoming events highlighted on the page (on-page reminder).
- Run on free hosting with no recurring cost.

### Non-Goals (v1 — deferred to later phases)
- Offline use and install-to-home-screen (PWA).
- External reminders (email or push notifications).
- Statistics and charts across aspects.
- Export to CSV / git backup.
- Native iOS/Android store apps.

## 3. Architecture

Two layers with a clean boundary between them.

### System Block Diagram

![Daily Compass system block diagram](block-diagram.png)

```
Frontend (web app)  ──HTTPS + Supabase SDK──►  Backend
   GitHub Pages                                  Supabase
   (free static host)                            (free tier)
```

Devices open the same app URL; data lives in the backend, not on any device, so
every device sees identical data.

```
company laptop ─┐
personal laptop ─┼─ open same URL ─► GitHub Pages (the app)
phone ──────────┘                          │
                                           ▼
                                    Supabase (the data)
```

### 3.1 Frontend
- Static web app hosted on **GitHub Pages** (free, static-only).
- App URL: `https://<user>.github.io/daily-compass` (default GitHub Pages URL;
  no custom domain needed).
- Implementation tech (plain HTML/CSS/JS vs. a light framework) is decided at
  the planning stage. Constraint: must build to static files hostable on GitHub
  Pages.

### 3.2 Backend — Supabase
- **Database:** Postgres, holds the events table.
- **Auth:** magic-link email login. Built-in.
- **API:** the frontend talks to Supabase over HTTPS using the Supabase JS SDK.
- **Security:** Row Level Security (RLS) restricts every row to its owning user.
  The browser uses the public **anon key**, which is safe to expose because it
  can do nothing without a valid login, and RLS blocks cross-user access. The
  secret service key is never placed in the browser.

## 4. Authentication Flow

1. On a new device, the user enters their email.
2. Supabase emails a one-time magic link.
3. The user clicks the link and is logged in.
4. The session token is stored in that browser and auto-refreshes, keeping the
   user logged in for weeks/months.
5. Subsequent opens on the same device are silent (no re-login).

Re-authentication is required only on a new device, after manual logout, after
a long session expiry, or if browser data is cleared.

## 5. Data Model

Starting schema for v1. Minimal and intended to be extended later (additional
aspects and fields refined in a later phase; not blocking v1).

**Table: `events`**

| Column       | Type        | Notes                                  |
|--------------|-------------|----------------------------------------|
| `id`         | uuid        | Primary key.                           |
| `user_id`    | uuid        | Owner; FK to auth user. RLS key.       |
| `aspect`     | text        | Category, e.g. work / health / personal. |
| `title`      | text        | What the event is.                     |
| `datetime`   | timestamptz | When the event occurs.                 |
| `notes`      | text        | Optional free text.                    |
| `created_at` | timestamptz | Row creation time; default now().      |

**RLS policy:** a user may read and write only rows where
`user_id = auth.uid()`.

## 6. Core Features (v1)

1. **Log in** — magic-link, persistent session.
2. **Add event** — aspect, title, date/time, optional notes.
3. **View events** — list view and calendar view.
4. **On-page reminder** — upcoming events highlighted when the app is open.

## 7. Later Phases (not v1)

- **PWA:** add `manifest.json`, a service worker (`sw.js`), and app icons to make
  the web app installable to the home screen (iPhone via Safari → Share → Add to
  Home Screen; Android via Chrome install prompt) and usable offline. No backend
  change.
- **External reminders:** email or push notifications before an event.
- **Stats/charts:** aggregate across aspects (Postgres SQL makes this easy).
- **Export:** dump events to CSV / commit to git for backup.
- **Native apps:** Supabase already provides iOS/Android/Flutter SDKs, so native
  store apps can reuse the same backend and data.

## 8. Reminders & Scheduling (Later Phase)

The system can trigger reminders and run tasks on a schedule without the owner
operating any server. Scheduling uses managed ("serverless") compute that the
provider runs on a timer and shuts down again — no VPS, no uptime to maintain.

### Reminder types

- **On-page reminder** (app open): pure client-side JavaScript. Already part of
  v1.
- **Push reminder** (app closed / phone idle): needs a scheduler plus a delivery
  channel. This is the later-phase work described here.

### Scheduling engines (free)

- **GitHub Actions cron:** a scheduled job in the repo runs a small script every
  N minutes (minimum 5-minute interval; may lag a few minutes). The script
  queries Supabase, decides, and sends reminders. Free quota: 2000 run-minutes /
  month on private repos, unlimited on public repos. Typical personal use (a
  ~30-second check every 15–30 minutes) stays well under the limit.
- **Supabase scheduled jobs (pg_cron + Edge Functions):** Supabase runs SQL or a
  serverless function on a schedule, close to the data. Included in the free
  tier.

### Delivery channels (free)

| Channel                     | Notes                                  |
|-----------------------------|----------------------------------------|
| Email (e.g. Resend/SendGrid)| ~100/day free; simplest, reliable.     |
| Web Push (browser notif)    | Free; requires the PWA service worker. |
| Telegram bot                | Free, instant; easy for personal use.  |

### Example flows

- If no wakeup logged by 09:00, send a nudge.
- A daily 22:00 "log sleep" reminder.
- Periodic reminders during the eating window.

### Data flow

```
GitHub Actions / Supabase cron ──fires on timer──► run script
        │ reads Supabase, applies rule
        ▼
   send Email / Telegram / Web Push   (provider's managed compute, free)
```

The v1 static app stays static; only this scheduling piece borrows managed
compute on a timer. Cost remains $0.

## 9. Cost

| Item                         | Cost        |
|------------------------------|-------------|
| GitHub account + Pages host  | $0          |
| Supabase free tier           | $0          |
| Magic-link login             | $0          |
| PWA (later)                  | $0          |
| **Total**                    | **$0**      |

Notes:
- A free Supabase project pauses after 7 days of zero activity; one click wakes
  it. Daily use avoids this.
- Free tier limits (e.g. 500 MB DB) are far beyond single-user needs.
- Optional paid extras, not required by this design: custom domain (~$10/yr,
  cosmetic) and native store fees (Apple $99/yr, Google $25 once).

## 10. Open Questions (resolve at planning stage)

- Frontend tech: plain HTML/CSS/JS or a light framework.
- Aspects: fixed list defined up front vs. freely added.
- Whether v1 needs any fields beyond the starting schema (e.g. location,
  done-checkbox, end-time).
