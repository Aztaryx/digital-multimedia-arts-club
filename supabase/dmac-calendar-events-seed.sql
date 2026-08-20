/* ═══════════════════════════════════════════════════════════════════
   dmac-calendar-events-seed.sql
   ═══════════════════════════════════════════════════════════════════
   One-time data load — every entry marked "Pending" in the school-
   year calendar list (2026–2027 school year: June 2026 → May 2027,
   matching the already-"Done" June entries this list also documents).
   "Done" rows aren't repeated here on the assumption they were already
   entered in an earlier pass; re-run is still safe (`on conflict do
   nothing` below) if that assumption turns out wrong for a given row.

   Requires dmac-calendar-date-ranges.sql to have been run first
   (event_end_date). created_by is left null — there's no admin
   session token in a SQL Editor run, and school_events.created_by is
   nullable for exactly this reason.

   IDEMPOTENT: guarded by a unique index on (title, event_date) so
   re-running this file doesn't duplicate rows. Non-contiguous
   suspension stretches (e.g. Aug 5–7 AND Aug 10–11) are intentionally
   separate rows sharing the same title — the unique index is on
   (title, event_date), so each start date still gets its own row.
   ═══════════════════════════════════════════════════════════════════ */

create unique index if not exists school_events_title_date_uniq
  on public.school_events (title, event_date);

insert into public.school_events (title, description, event_date, event_end_date, location, tags, color) values

  -- ── JUNE 2026 ──────────────────────────────────────────────────
  ('FLAG CEM (Back-to-School)', null, '2026-06-08', null, null, array['Assembly'], '#38bdf8'),
  ('FLAG CERM',                 null, '2026-06-19', null, null, array['Assembly'], '#38bdf8'),
  ('PTC',                       null, '2026-06-26', null, null, array['Meeting'],  '#38bdf8'),
  ('FLAG RETREAT',              null, '2026-06-26', null, null, array['Assembly'], '#38bdf8'),

  -- ── JULY 2026 — two non-contiguous class-suspension days ────────
  ('Class Suspension', null, '2026-07-10', null, null, array['Suspension'], '#f97316'),
  ('Class Suspension', null, '2026-07-24', null, null, array['Suspension'], '#f97316'),

  -- ── AUGUST 2026 — four non-contiguous suspension stretches ──────
  ('Class Suspension', null, '2026-08-05', '2026-08-07', null, array['Suspension'], '#f97316'),
  ('Class Suspension', null, '2026-08-10', '2026-08-11', null, array['Suspension'], '#f97316'),
  ('Class Suspension', null, '2026-08-13', '2026-08-14', null, array['Suspension'], '#f97316'),
  ('Class Suspension', null, '2026-08-17', '2026-08-20', null, array['Suspension'], '#f97316'),
  ('Ninoy Aquino Day',    null, '2026-08-21', null, null, array['Holiday'],  '#ef4444'),
  ('Birthday – Rojan',    null, '2026-08-22', null, null, array['Birthday'], '#a855f7'),
  ('National Heroes Day', null, '2026-08-31', null, null, array['Holiday'],  '#ef4444'),

  -- ── SEPTEMBER 2026 ───────────────────────────────────────────────
  ('Birthday – Mark',     null, '2026-09-17', null, null, array['Birthday'], '#a855f7'),
  ('Birthday – Clarence', null, '2026-09-28', null, null, array['Birthday'], '#a855f7'),

  -- ── OCTOBER 2026 ─────────────────────────────────────────────────
  ('Birthday – Clarisse', null, '2026-10-10', null, null, array['Birthday'], '#a855f7'),
  ('Birthday – Athena',   null, '2026-10-27', null, null, array['Birthday'], '#a855f7'),
  ('Birthday – Jemwell',  null, '2026-10-31', null, null, array['Birthday'], '#a855f7'),

  -- ── NOVEMBER 2026 ────────────────────────────────────────────────
  ('All Saints'' Day', null, '2026-11-01', null, null, array['Holiday'],  '#ef4444'),
  ('All Souls'' Day',  null, '2026-11-02', null, null, array['Holiday'],  '#ef4444'),
  ('Birthday – Nico', null, '2026-11-17', null, null, array['Birthday'], '#a855f7'),
  ('Foundation Day',  null, '2026-11-27', '2026-11-28', null, array['School Event'], '#eab308'),
  ('English Month (Parade of Literary Characters)', 'Month-long observance.', '2026-11-01', '2026-11-30', null, array['School Event'], '#eab308'),

  -- ── DECEMBER 2026 ────────────────────────────────────────────────
  ('Birthday – Keitharine', null, '2026-12-11', null, null, array['Birthday'],     '#a855f7'),
  ('Valenciana Festival',   null, '2026-12-11', '2026-12-13', null, array['School Event'], '#eab308'),
  ('Birthday – Jyryn',      null, '2026-12-21', null, null, array['Birthday'], '#a855f7'),
  ('Christmas Day',         null, '2026-12-25', null, null, array['Holiday'],  '#ef4444'),
  ('New Year''s Eve',        null, '2026-12-31', null, null, array['Holiday'],  '#ef4444'),

  -- ── JANUARY 2027 ─────────────────────────────────────────────────
  ('New Year''s Day',         null, '2027-01-01', null, null, array['Holiday'],  '#ef4444'),
  ('Birthday – Jaywin',       null, '2027-01-08', null, null, array['Birthday'], '#a855f7'),
  ('Birthday – Mary Jeanelle', null, '2027-01-31', null, null, array['Birthday'], '#a855f7'),

  -- ── FEBRUARY 2027 ────────────────────────────────────────────────
  ('Birthday – Liane', null, '2027-02-10', null, null, array['Birthday'], '#a855f7'),

  -- ── MARCH 2027 ───────────────────────────────────────────────────
  ('Birthday – Micah',   null, '2027-03-05', null, null, array['Birthday'], '#a855f7'),
  ('Birthday – Ysabel',  null, '2027-03-06', null, null, array['Birthday'], '#a855f7'),
  ('Birthday – Alianna', null, '2027-03-14', null, null, array['Birthday'], '#a855f7'),
  ('Birthday – Ethan',   null, '2027-03-19', null, null, array['Birthday'], '#a855f7'),

  -- ── APRIL 2027 ───────────────────────────────────────────────────
  ('Birthday – Rhycel', null, '2027-04-04', null, null, array['Birthday'], '#a855f7'),
  ('Birthday – Jez',    null, '2027-04-23', null, null, array['Birthday'], '#a855f7'),

  -- ── MAY 2027 ─────────────────────────────────────────────────────
  ('Birthday – Sofia', null, '2027-05-30', null, null, array['Birthday'], '#a855f7')

on conflict (title, event_date) do nothing;
