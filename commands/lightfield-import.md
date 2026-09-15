---
description: Import records from a CSV or JSON file into Lightfield: mapped to real field keys, deduped, idempotent, and dry-run first.
argument-hint: "<path to file> [accounts|contacts|opportunities|tasks|notes]"
---

Import the records in the file named by `$ARGUMENTS` into Lightfield. This
writes to a production CRM, so it runs as a dry run first and only executes
after the user approves the plan.

If no path is given, ask for one. If the object type is not given, infer it from
the columns and state the inference for confirmation.

## 1. Read the source

Parse the file and report: row count, column names, and a two-row sample. Flag
rows with an empty identity column (account name, contact email): they cannot
be deduplicated and should be skipped or fixed, not guessed at.

## 2. Map columns to real field keys

Read `GET /v1/{objectType}/definitions` and map each column to a field key by
`label`. Never invent a key.

- Unmapped columns: list them and ask whether to drop them or map them by hand.
  Do not silently discard data.
- `SINGLE_SELECT` / `MULTI_SELECT` columns: map each source value to an option
  `id` from `typeConfiguration.options`. Report any value with no matching
  option and ask. Do not pick the nearest label.
- `readOnly: true` fields cannot be written; drop them and say so.
- Check formats against the field's `valueType`: `DATETIME` needs ISO 8601 with
  an offset, `EMAIL` and `URL` are usually arrays, `ADDRESS` and `FULL_NAME` are
  objects, `country` is a 2-letter code.

Show the final mapping as a table before proceeding.

## 3. Plan, and dry-run

Pick the dedupe key: `$email[contains]` for contacts, `$name[equal]` for
accounts, the documented identity field otherwise. Query the list endpoint for
each row and classify it **create**, **update**, or **skip (unchanged)**.

Report the counts and every ambiguous case (a row matching more than one
existing record) and **stop for approval**. Do not write anything yet.

## 4. Execute

After explicit approval:

- `POST /v1/{objectType}` for creates, `POST /v1/{objectType}/{id}` for updates
  with only the changed fields.
- An `Idempotency-Key` on every write, derived deterministically from the source
  row (e.g. `import-{file}-{row-identity}`) so a re-run of a partial import
  cannot double-create.
- Stay under 25 requests per second. Serialize, or cap concurrency at a handful,
  and back off on `429` using `Retry-After`.
- At most 25 relationship IDs per request; split larger link sets.
- Keep a running log of row → result → record ID.

On an error, do not retry the same body. `unknown_field` and
`unknown_relationship` mean the mapping is wrong. Stop and re-map.
`referenced_resource_missing` means an ID in the row does not exist. Report the
row, the `code` and the `param`.

## 5. Report

A table of created / updated / skipped / failed with counts, the `httpLink` for
a few created records so the user can spot-check, and the full list of failures
with their reasons. If the import stopped partway, say exactly which rows landed
and which did not, and that re-running with the same keys is safe.
