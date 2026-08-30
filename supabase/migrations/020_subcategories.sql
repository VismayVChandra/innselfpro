-- Subcategories: tapping a category with real variety (e.g. Appliance
-- Repair) now offers a second step -- Fridge Repair, Washing Machine
-- Repair, etc, plus an explicit "(Other)" catch-all -- instead of
-- lumping every technician into one broad bucket. Implemented as a
-- self-referencing parent_category_id on the existing table rather
-- than a separate concept, so bidding, price guidance, and every other
-- category_id-keyed feature needs zero changes -- a subcategory is
-- just a more specific row in the same table.
--
-- categories.name is unique, so each parent's catch-all is stored as
-- its own fully-qualified name ("Plumber (Other)") rather than a bare
-- "Other" that would collide across parents.
alter table categories add column if not exists parent_category_id int references categories(id);

do $$
declare
  v_appliance int; v_plumber int; v_electrician int; v_cleaning int; v_pest int;
begin
  select id into v_appliance from categories where name = 'Appliance Repair';
  select id into v_plumber from categories where name = 'Plumber';
  select id into v_electrician from categories where name = 'Electrician';
  select id into v_cleaning from categories where name = 'Cleaning';
  select id into v_pest from categories where name = 'Pest Control';

  insert into categories (name, parent_category_id)
  values
    ('Fridge Repair', v_appliance),
    ('Washing Machine Repair', v_appliance),
    ('Microwave Repair', v_appliance),
    ('Water Purifier Repair', v_appliance),
    ('Appliance Repair (Other)', v_appliance),

    ('Tap & Faucet Repair', v_plumber),
    ('Pipe Leakage', v_plumber),
    ('Bathroom Fitting', v_plumber),
    ('Water Heater Repair', v_plumber),
    ('Plumber (Other)', v_plumber),

    ('Wiring & Switchboard', v_electrician),
    ('Fan Installation', v_electrician),
    ('Inverter & UPS', v_electrician),
    ('MCB & Fuse Repair', v_electrician),
    ('Electrician (Other)', v_electrician),

    ('Deep House Cleaning', v_cleaning),
    ('Bathroom Cleaning', v_cleaning),
    ('Sofa & Carpet Cleaning', v_cleaning),
    ('Water Tank Cleaning', v_cleaning),
    ('Cleaning (Other)', v_cleaning),

    ('General Pest Control', v_pest),
    ('Termite Treatment', v_pest),
    ('Rodent Control', v_pest),
    ('Cockroach Control', v_pest),
    ('Pest Control (Other)', v_pest)
  on conflict (name) do nothing;
end $$;

-- Broadens the wave 6 fan-out (migration 014) so a technician skilled
-- at the parent level ("Appliance Repair") still gets notified about a
-- job posted under one of its subcategories ("Fridge Repair") --
-- technician_skills only ever holds top-level ids (the app doesn't
-- offer picking a specific subcategory as a skill), so without this a
-- subcategorized job would silently stop reaching anyone.
create or replace function public.notify_matching_technicians()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.invited_technician_id is not null then
    return new;
  end if;

  insert into notifications (user_id, type, job_id, message)
  select
    ts.profile_id,
    'new_job',
    new.id,
    'New ' || c.name || ' job posted near you'
  from technician_skills ts
  join technician_details td on td.profile_id = ts.profile_id
  join categories c on c.id = new.category_id
  where (ts.category_id = new.category_id or ts.category_id = c.parent_category_id)
    and ts.profile_id <> new.customer_id
    and td.is_available
    and (
      (
        td.base_lat is not null and td.base_lng is not null
        and new.lat is not null and new.lng is not null
        and public.distance_km(td.base_lat, td.base_lng, new.lat, new.lng) <= td.service_radius_km
      )
      or (
        (td.base_lat is null or td.base_lng is null or new.lat is null or new.lng is null)
        and (
          td.service_area is null
          or td.service_area = ''
          or new.location ilike '%' || td.service_area || '%'
        )
      )
    )
  limit 50;

  return new;
end;
$$;
