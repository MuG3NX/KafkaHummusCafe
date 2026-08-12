# Supabase setup

The migrations in `migrations/` are the source of truth for the accepted M1 Revenue slice and active M2 Shifts slice. M2 adds database-clock start/end RPCs, shift RLS, and append-only owner correction history without changing the Revenue model.

Database authorization tests live in `tests/rls_scenarios.sql` and run with `supabase test db` after the local database is started/reset. They exercise the employee, submitter, owner, direct-mutation, duplicate, shared-current-day, composite-FK, revenue correction/revision, shift clock, service-day, totals, and shift correction paths.

1. Create a Supabase project and copy its URL and publishable key into `web/.env.local` (never commit that file). Use `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`; never put a secret/service-role key in the browser.
2. Link the project with the Supabase CLI and run `supabase db push`.
3. Create the first user through the app's sign-up form.
4. In the Supabase SQL editor, bootstrap the current restaurant/location and owner membership using that user's Auth UUID:

```sql
with new_restaurant as (
  insert into public.restaurants (name) values ('KAFKA') returning id
), new_location as (
  insert into public.locations (restaurant_id, name, timezone)
  select id, 'Main location', 'Europe/Prague' from new_restaurant returning id, restaurant_id
)
insert into public.restaurant_memberships (restaurant_id, user_id, role)
select restaurant_id, 'REPLACE_WITH_AUTH_USER_UUID'::uuid, 'owner' from new_location;
```

Owners are restaurant-wide. Non-owner users get access through explicit rows in
`membership_location_assignments`, where `can_submit_revenue` can be granted or revoked per location.

## Bootstrap an employee account

M2 uses deliberate SQL setup for the initial employee accounts; this is not an onboarding system. For each employee:

1. Create or invite the account through Supabase Auth and copy its Auth User UUID.
2. Set the employee's display name in `profiles`.
3. Create the employee membership for the KAFKA restaurant.
4. Assign that membership to Main location. Revenue submission remains independent and defaults to false.

Run the following in the Supabase SQL editor after replacing the marked values:

```sql
insert into public.profiles (id, display_name)
values ('REPLACE_WITH_EMPLOYEE_AUTH_UUID'::uuid, 'Employee Name')
on conflict (id) do update set display_name = excluded.display_name;

insert into public.restaurant_memberships (restaurant_id, user_id, role)
values ('REPLACE_WITH_KAFKA_RESTAURANT_UUID'::uuid, 'REPLACE_WITH_EMPLOYEE_AUTH_UUID'::uuid, 'employee')
on conflict (restaurant_id, user_id) do update set role = excluded.role;

insert into public.membership_location_assignments (membership_id, location_id, can_submit_revenue)
select id, 'REPLACE_WITH_MAIN_LOCATION_UUID'::uuid, false
from public.restaurant_memberships
where restaurant_id = 'REPLACE_WITH_KAFKA_RESTAURANT_UUID'::uuid
  and user_id = 'REPLACE_WITH_EMPLOYEE_AUTH_UUID'::uuid
on conflict (membership_id, location_id) do update set can_submit_revenue = excluded.can_submit_revenue;
```

Use `can_submit_revenue = true` only for an employee intentionally authorized to submit the daily revenue entry. The location assignment is also what permits the employee's shift clock RPCs.

## Service-day cutoff: after-midnight closing

The database is the source of truth for the 05:00 local cutoff. From `00:00:00` through `04:59:59.999...`, a close belongs to the previous service day; at exactly `05:00:00` and afterward it belongs to the current local calendar date. The cutoff is interpreted in each location's IANA timezone and is covered by executable pgTAP and client tests.

Do not enable real revenue entry until this migration is applied to the production project. The app uses only the publishable key. RLS and the security-definer functions are the authorization boundary; do not put a service-role key in Vercel or the browser bundle.
