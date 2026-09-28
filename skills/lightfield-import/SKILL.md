---
name: lightfield-import
description: >-
  Import CRM records from an attached or local CSV or JSON file into Lightfield
  with real field mappings, duplicate detection, idempotent writes, and a dry
  run before execution. Use when the user asks to import or bulk upsert
  accounts, contacts, opportunities, tasks, or notes.
---

# Import records into Lightfield

This workflow writes production CRM data. Always produce a dry-run plan first
and wait for explicit approval before executing writes.

If no file is available, ask the user to attach one or provide its accessible
path. If the object type is unclear, infer it from the columns and ask the user
to confirm the inference.

## 1. Inspect the source

Parse the CSV or JSON and report its row count, columns, and a two-row sample.
Redact credentials or sensitive values that are not needed for mapping. Flag
rows missing an identity value such as account name or contact email; skip or
fix those rows rather than guessing.

## 2. Map fields

Read `/v1/{objectType}/definitions` and map columns to fields by label. Never
invent a field key.

- List unmapped columns and ask whether to omit or manually map them.
- Map single- and multi-select text to exact option IDs from
  `typeConfiguration.options`. Ask about unmatched or ambiguous labels.
- Exclude `readOnly: true` fields and explain why.
- Validate formats against each field's `valueType`.

Show the final source-column to Lightfield-field mapping before continuing.

## 3. Dry run

Choose a documented identity filter: normally `$email[contains]` for contacts
and `$name[equal]` for accounts. Query existing records and classify every row
as create, update, skip unchanged, or ambiguous. Show counts and every
ambiguous match, then stop for approval. Do not write during this step.

## 4. Execute after approval

- Create with `POST /v1/{objectType}` and update with
  `POST /v1/{objectType}/{id}`, sending only changed fields.
- Give every write a deterministic `Idempotency-Key` based on the import and
  stable row identity. Reuse that key for retries but never for another payload.
- Keep requests below 25 per second, use bounded concurrency, and honor
  `Retry-After` on `429`.
- Keep relationship writes within 25 referenced IDs and 25 link changes per
  request.
- Record the source row, outcome, and resulting record ID.

Do not blindly retry validation failures. Re-read definitions for
`unknown_field` or `unknown_relationship`; report the row, `code`, and `param`
for missing referenced records.

## 5. Report

Return created, updated, unchanged, and failed counts; a few resulting
`httpLink` values for spot checks; and every failure with its reason. If the
run stops partway through, identify exactly which rows landed and explain that
the same idempotency keys make a retry safe.
