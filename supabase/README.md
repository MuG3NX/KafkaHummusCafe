# Supabase setup

The migration in `migrations/20260812090000_m1_revenue.sql` is the source of truth for M1. It creates the tenant, service-day, revenue, RLS, and append-only correction model.

Database authorization tests live in `tests/rls_scenarios.sql` and run with `supabase test db` after the local database is started/reset. They exercise the employee, submitter, owner, direct-mutation, duplicate, shared-current-day, composite-FK, and correction/revision paths.

1. Create a Supabase project and copy its URL and publishable/anon key into `web/.env.local` (never commit that file).
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

## Deployment gate: after-midnight closing

M1 currently defines a service day as the calendar date in the location timezone. If the restaurant closes after midnight, do not deploy revenue entry until an explicit closing cutoff/business-day rule is added and covered by database tests; otherwise a 01:00 close will be recorded as the next calendar day by design.

The app uses only the publishable/anon key. RLS and the security-definer functions are the authorization boundary; do not put a service-role key in Vercel or the browser bundle.
