# Production Backup and Recovery Policy

## Purpose

KAFKA OS stores real restaurant financial, labor, document, and operational evidence. Git history protects application/schema source; it does **not** protect production business rows. This document defines the backup/recovery operating policy separately from product milestones.

Tracked by Issue #15.

## Current state

- Production database is Supabase Postgres in `eu-central-1`.
- Schema changes are committed migrations and production rollout is database-first.
- A secure manual pre-M3 database backup exists outside the repository and must remain private until a newer recovery policy is proven.
- No database dump, backup location, database password, access token, service-role secret, or restore credential belongs in GitHub.
- PITR/automatic-backup entitlement and current project configuration must be verified from the live Supabase project before changing services or incurring cost.

## Recovery objectives

### Current minimum target

Until automated/PITR recovery is deliberately enabled and tested:

- **RPO target:** no more than one business day of production data.
- **RTO target:** same business day where practical, with correctness preferred over a rushed destructive restore.

### Future preferred target

When production usage justifies PITR and the Supabase plan supports it economically:

- reduce RPO materially below one day;
- retain the ability to restore to a point before a bad migration/operator action;
- prove the restore process in an isolated non-production environment before treating PITR as operationally accepted.

These are internal continuity targets, not contractual SLAs.

## Backup layers

KAFKA should rely on multiple independent recovery layers rather than one mechanism.

### 1. Git / migration history

Protects:
- application source;
- SQL migrations;
- tests;
- architecture/spec history.

Does not protect:
- Auth users as live state;
- production Revenue/Shifts/Invoices/Costs/Closings/reservations;
- Storage originals;
- runtime configuration/secrets.

### 2. Supabase-managed database recovery

Use the project’s available automatic backups/PITR capability when deliberately enabled/accepted.

Before relying on it, verify live:
- plan entitlement;
- retention window;
- whether restore is full-project or database-only;
- operational restore procedure;
- expected downtime/limitations;
- cost impact.

Do not infer current entitlement from old project status or generic documentation.

### 3. Owner-controlled manual logical backup

Keep a periodic encrypted/logically exported database backup outside GitHub and outside the production app runtime.

Requirements:
- generated using a trusted authenticated process;
- non-empty archive verified after creation;
- restore contents/listing can be inspected without exposing production rows in logs;
- filesystem/cloud access restricted to the owner/recovery operator;
- no credentials embedded in the dump filename, Git history, shell history, CI log, or documentation;
- oldest backup retirement only after a newer backup is verified and retention policy permits removal.

### 4. Supabase Storage originals

Invoice originals are business evidence and need a recovery policy independent of relational rows.

Before retiring the current manual database backup or calling recovery complete, verify whether the selected Supabase backup/PITR product also covers Storage objects. If not, define a separate private Storage export/replication procedure.

Never commit invoice originals to GitHub.

## Proposed retention

Until real storage size/cost indicates otherwise:

- daily logical recovery point: keep 7;
- weekly recovery point: keep 4;
- monthly recovery point: keep 6;
- preserve at least one known-good pre-major-migration backup until the subsequent milestone has completed real production acceptance and a newer restore test passes.

Do not delete the existing secure pre-M3 backup merely because newer code has shipped.

## Backup cadence

### While KAFKA is still low-volume

Minimum:
- take/verify a manual logical backup before any migration that introduces a new high-value financial/operational evidence model;
- take a fresh backup after a milestone is production-accepted if no managed PITR/automatic backup gives equivalent recovery confidence;
- review backup freshness at least weekly while production data is changing.

### As KAFKA becomes daily-critical

Move to an automated owner-controlled or managed recovery path so continuity does not depend on remembering a manual export.

Do not implement an ad-hoc cron job with production credentials in GitHub Actions merely to say backups are automated. Secret handling, encrypted destination, retention and restore verification must be solved together.

## Restore procedure

Never use production as the first restore test.

### Non-production restore drill

1. Identify exact backup/recovery point.
2. Create/select an isolated non-production database/project.
3. Restore using documented credentials kept outside Git.
4. Apply no speculative schema edits during restore.
5. Verify key structural invariants:
   - expected migrations/schema exist;
   - RLS remains enabled;
   - critical RPCs/functions exist;
   - Auth-related references are coherent for the chosen restore method.
6. Verify sanitized row counts / relational coherence without copying sensitive row contents into GitHub/chat.
7. Verify a representative private Storage original can be recovered if Storage is part of the drill.
8. Run application smoke tests against the isolated restore where practical.
9. Record only sanitized evidence: date, recovery point, success/failure, counts/invariants, duration, anomalies.
10. Destroy or secure the isolated restored environment according to the data-handling policy.

### Production restore

A destructive/full production restore requires explicit owner authorization after:
- incident scope is understood;
- current state is preserved if possible;
- chosen recovery point is identified;
- expected data loss window is stated;
- DNS/application writes are paused if required;
- rollback/forward-fix alternatives are considered.

Do not restore production merely to repair one ordinary application bug if a safer audited forward correction exists.

## Migration safety

Before a production migration:

1. Git head and exact reviewed SQL must be frozen.
2. Confirm current production migration history.
3. Confirm recoverability/backup freshness appropriate to the migration risk.
4. Apply database migration before merging frontend that depends on it.
5. Verify schema/RLS/grants and zero unexpected business-row writes.
6. Reconcile MCP-assigned migration versions to Git with byte-identical SQL when required.
7. Run exact-head CI before merge.
8. Verify post-merge CI/Vercel.

This is the already-proven M4B1/M4B2 rollout pattern and remains the default.

## Incident classes

### Application bug, database structurally healthy

Prefer:
- disable/contain affected path;
- inspect audit evidence;
- ship a focused forward fix;
- use existing audited correction workflows for business data.

Avoid full restore.

### Bad migration / destructive schema or data operation

Priorities:
- stop further writes if needed;
- preserve evidence/current state where possible;
- identify pre-incident recovery point;
- validate recovery on isolated environment where time permits;
- restore/forward-repair only with explicit owner decision.

### Credential compromise

Backup restoration alone does not solve this.

Also rotate/revoke affected credentials and inspect access/audit evidence.

### Storage/original-document loss

Treat invoice originals separately from relational metadata. Do not mark structured invoice data as equivalent replacement evidence.

## Access and secret handling

Recovery access should be minimal:
- owner / explicitly designated recovery operator only;
- temporary PAT/access tokens preferred for one-off operations;
- tokens never pasted into GitHub issues, PRs, chat, logs, docs or committed env files;
- revoke temporary tokens immediately after use;
- production DB password/service-role secrets remain outside Git and browser code.

## Evidence log

Issue #15 should record sanitized operational evidence only:
- backup date;
- backup type;
- non-empty/structural verification result;
- retention class (daily/weekly/monthly/pre-migration);
- restore drill date/result;
- Supabase PITR/backup entitlement decision;
- unresolved recovery gaps.

Do not record file paths, secret values, invoice contents, customer/staff personal data, or database rows.

## Definition of done for Issue #15

Issue #15 can close only when:

1. current Supabase managed-backup/PITR capability and cost are explicitly reviewed;
2. accepted backup cadence/retention is recorded;
3. database + Storage coverage is understood;
4. owner-controlled recovery credentials/storage are secure;
5. at least one non-production restore drill succeeds;
6. sanitized restore evidence is recorded;
7. the existing pre-M3 backup has an explicit keep/retire decision based on newer verified recovery evidence.
