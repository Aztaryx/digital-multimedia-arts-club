/* ═══════════════════════════════════════════════════════════════════
   dmac-calendar-date-ranges.sql
   ═══════════════════════════════════════════════════════════════════
   Adds an optional `event_end_date` to school_events so a single
   entry can span multiple consecutive days (Foundation Day, the
   Valenciana Festival, a multi-day class-suspension stretch) instead
   of needing one row per day. event_date stays the start date and,
   for a single-day event, the only date — event_end_date is simply
   left null.

   Non-contiguous spans (e.g. class suspensions on the 5th–7th AND the
   10th–11th) are still two separate rows, same title/tags — a genuine
   gap in the middle isn't "one event," it's two.

   IDEMPOTENT — safe to run against a fresh database or one that's
   already had this applied. Run AFTER
   dmac-admin-calendar-content-features.sql (school_events.tags/color
   + the CRUD RPCs this migration extends already need to exist).
   ═══════════════════════════════════════════════════════════════════ */

alter table public.school_events
  add column if not exists event_end_date date;

alter table public.school_events
  drop constraint if exists school_events_end_after_start;
alter table public.school_events
  add constraint school_events_end_after_start check (event_end_date is null or event_end_date >= event_date);


drop function if exists public.create_school_event(uuid, text, date, text, text, text[], text);

create or replace function public.create_school_event(
  p_session_token uuid,
  p_title         text,
  p_event_date    date,
  p_description   text default null,
  p_location      text default null,
  p_tags          text[] default '{}',
  p_color         text default null,
  p_end_date      date default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me   uuid := public._resolve_member_id(p_session_token);
  v_role text;
  v_id   uuid;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;
  select site_role into v_role from public.members where id = v_me;
  if v_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Admins only.');
  end if;
  if p_event_date is null then
    return json_build_object('success', false, 'message', 'A date is required.');
  end if;
  if p_end_date is not null and p_end_date < p_event_date then
    return json_build_object('success', false, 'message', 'End date can''t be before the start date.');
  end if;
  if p_color is not null and p_color !~* '^#[0-9a-f]{3}([0-9a-f]{3})?$' then
    return json_build_object('success', false, 'message', 'Color must be a hex code, like #38bdf8.');
  end if;

  insert into public.school_events (title, description, event_date, event_end_date, location, created_by, tags, color)
  values (
    trim(p_title),
    nullif(trim(coalesce(p_description, '')), ''),
    p_event_date,
    p_end_date,
    nullif(trim(coalesce(p_location, '')), ''),
    v_me,
    coalesce(p_tags, '{}'),
    nullif(trim(coalesce(p_color, '')), '')
  )
  returning id into v_id;

  return json_build_object('success', true, 'event_id', v_id);
end;
$$;

grant execute on function public.create_school_event(uuid, text, date, text, text, text[], text, date) to anon, authenticated;


drop function if exists public.admin_update_school_event(uuid, uuid, text, date, text, text, text[], text);

create or replace function public.admin_update_school_event(
  p_session_token uuid,
  p_event_id      uuid,
  p_title         text,
  p_event_date    date,
  p_description   text default null,
  p_location      text default null,
  p_tags          text[] default '{}',
  p_color         text default null,
  p_end_date      date default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me   uuid := public._resolve_member_id(p_session_token);
  v_role text;
begin
  if v_me is null then
    return json_build_object('success', false, 'message', 'Not logged in.');
  end if;
  select site_role into v_role from public.members where id = v_me;
  if v_role is distinct from 'admin' then
    return json_build_object('success', false, 'message', 'Admins only.');
  end if;
  if p_event_date is null then
    return json_build_object('success', false, 'message', 'A date is required.');
  end if;
  if p_end_date is not null and p_end_date < p_event_date then
    return json_build_object('success', false, 'message', 'End date can''t be before the start date.');
  end if;
  if p_color is not null and p_color !~* '^#[0-9a-f]{3}([0-9a-f]{3})?$' then
    return json_build_object('success', false, 'message', 'Color must be a hex code, like #38bdf8.');
  end if;
  if not exists (select 1 from public.school_events where id = p_event_id) then
    return json_build_object('success', false, 'message', 'That event no longer exists.');
  end if;

  update public.school_events
     set title          = trim(p_title),
         description    = nullif(trim(coalesce(p_description, '')), ''),
         event_date     = p_event_date,
         event_end_date = p_end_date,
         location       = nullif(trim(coalesce(p_location, '')), ''),
         tags           = coalesce(p_tags, '{}'),
         color          = nullif(trim(coalesce(p_color, '')), '')
   where id = p_event_id;

  return json_build_object('success', true);
end;
$$;

grant execute on function public.admin_update_school_event(uuid, uuid, text, date, text, text, text[], text, date) to anon, authenticated;
