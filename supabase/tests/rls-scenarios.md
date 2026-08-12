# RLS scenarios

Run these scenarios against a disposable Supabase project with three Auth users: an employee without revenue permission, an authorized submitter, and the owner.

- The unauthorized employee cannot select another user's revenue or execute a successful submit.
- The authorized submitter can execute `submit_revenue_entry` for the current location/service day, then can select that submitted row.
- A second submit with different values is rejected by the database-side idempotency/duplicate guard.
- A submitted row cannot be updated or deleted through the REST table API because no insert/update/delete policy exists.
- The owner can select history and execute `correct_revenue_entry` only with a non-empty reason.
- A correction creates one `revenue_revisions` row containing the previous values; the revision table has no client insert/update/delete policy.
