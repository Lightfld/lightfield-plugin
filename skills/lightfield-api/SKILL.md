---
name: lightfield-api
description: >-
  Write code against the Lightfield REST API: authenticate with an API key and
  scopes, install and use the official Python, TypeScript, Go SDKs or the
  lightfield CLI, paginate and filter list endpoints, retry safely with
  idempotency keys, handle 429s and typed errors, upload files, and send email.
  Use when building a script, sync job, service, or integration that calls
  api.lightfield.app, rather than when reading or writing records interactively.
---

# Building against the Lightfield API

Base URL `https://api.lightfield.app`, current version `2026-03-01`. Every
request needs two headers:

```http
Authorization: Bearer $LIGHTFIELD_API_KEY
Lightfield-Version: 2026-03-01
```

Requests with a body also need `Content-Type: application/json`, or the API
returns `415`. The SDKs and CLI set the version header for you.

The API is in beta: methods, parameters, and response schemas can still change.
Check <https://docs.lightfield.app/api> for the current shape rather than
relying on memory, and append `/index.md` to any docs path for its markdown
source.

## Clients

| Client | Install | Docs |
| --- | --- | --- |
| Python | `pip install lightfield` | <https://docs.lightfield.app/api/python> |
| TypeScript | `npm install lightfield` | <https://docs.lightfield.app/api/typescript> |
| Go | `go get -u github.com/Lightfld/lightfield-go` | <https://docs.lightfield.app/getting-started/go-quickstart> |
| CLI | `brew install Lightfld/lightfield/lightfield` | <https://docs.lightfield.app/api/cli> |
| HTTP | curl, or any client | <https://docs.lightfield.app/getting-started/http-quickstart> |

Prefer an SDK over raw HTTP: they carry the version header, expose typed errors,
and track schema changes. Reach for curl only for a one-off probe or where no
SDK exists. The CLI does **not** support list filtering, so use an SDK or HTTP
when you need a filter.

Working code for each client, including the pagination and retry loops, is in
`references/sdk-recipes.md`.

## Credentials

An org admin creates a key at
<https://crm.lightfield.app/crm/settings/api-keys>. It is shown once and starts
with `sk_lf_`.

- Read it from `LIGHTFIELD_API_KEY` in the environment. Never commit a key, log
  it, interpolate it into an error message, or put it in client-side code. If
  one leaks, revoke it in settings. Revocation is immediate and permanent.
- **Grant the narrowest scopes.** Scopes are `{object}:{create|update|read}` for
  accounts, contacts, opportunities, meetings, tasks, notes, lists, files,
  emails, and `members:read`. A missing scope is a `403`, not a `401`.
- A key inherits the roles of the admin who created it, at creation time.
- Use a separate key per integration so one can be revoked alone.

`GET /v1/auth/validate` needs no scope and returns `active`, `tokenType`,
`subjectType` (`user` or `workspace`), and `scopes` (empty means full access).
Call it at startup to fail fast with a clear message instead of a confusing
`403` later.

## Reading

Lists take `limit` (1–25) and `offset`. Page until a response returns fewer rows
than `limit`; never assume `totalCount` is stable across pages. Filters are
query parameters shaped `key[operator]=value`: the operator matrix and
relationship filtering are in the `lightfield-crm` skill's
`references/filtering.md`.

Two properties of list endpoints shape any integration:

- **The index lags.** Lists are served from a search index that may not reflect
  recent writes. Read back through `GET /v1/{objectType}/{id}` when correctness
  depends on freshness: after a write, or before a decision to update.
- **Field and relationship keys are org-specific.** Fetch
  `GET /v1/{objectType}/definitions` at startup and map labels to keys and
  select option IDs there. Hardcoding an `opt_…` works in one org and silently
  mismatches in the next.

## Writing

`POST /v1/{objectType}` creates, `POST /v1/{objectType}/{id}` updates with only
the changed fields. Both take `{ "fields": …, "relationships": … }` with bare
values (reads wrap values in `{ valueType, value }`; writes do not).

**Search before creating.** Query the list endpoint for an existing record
(`$email[contains]` for a contact, `$name[equal]` for an account), and update it
when one exists. A sync job without this step manufactures duplicates on every
run.

**Send an `Idempotency-Key` on every write.** Any `POST` accepts it (up to 255
characters; a UUID v4 is right). A retry with the same key returns the original
cached response instead of acting twice; keys expire after 24 hours and are
scoped per organization and operation type. Two concurrent requests sharing a
key get `409 idempotency_conflict` on the second. Wait, then retry with the
same key. If the original request *failed*, reusing the key re-attempts it.
Never reuse a key with a different payload: you get the old response, not the
new operation.

**Relationship writes cap at 25.** At most 25 entity IDs referenced and 25 link
changes per request, counted across the whole body. Over either limit is `422`
`relationship_write_limit_exceeded`. Batch accordingly.

## Rate limits

25 requests per second per organization, in each of three categories: write
(create, update), read (retrieve, definitions), and search (list). Every
response carries `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and
`X-RateLimit-Reset` (unix seconds).

On `429`, honour `Retry-After` then back off exponentially. Retry `429`, `5xx`,
connection errors, and `409 idempotency_conflict` (the first request with that
key is still in flight, so wait and retry with the *same* key). Do not retry
`400`, `401`, `403`, `404`, `415` or `422`: they need a changed request, not a
second attempt.

The Python and TypeScript SDKs already retry connection errors, `408`, `409`,
`429` and `5xx` twice with exponential backoff. Tune it with `max_retries` /
`maxRetries` rather than wrapping the call in your own loop, and add a retry
layer of your own only around the parts an SDK does not cover. Keep concurrency
bounded and watch `X-RateLimit-Remaining` instead of discovering the limit by
hitting it.

## Errors

Every error body is `{ "error": { type, message, code?, param? } }`. `type`
selects the class; on `400` and `422`, `code` and `param` name the exact field
or header at fault. Branch on `code`, not on message text. The SDKs surface
these as typed exceptions (`AuthenticationError`, `PermissionDeniedError`,
`BadRequestError`, `NotFoundError`, …) carrying the same fields. Full status and
code tables are in `references/errors.md`.

## Files and email

File upload is a three-step lifecycle: create a session, `PUT` the bytes to the
returned presigned URL with exactly the returned headers, then complete the
file. Email sends and drafts go through a connected mailbox and take completed
file IDs as attachments. Both, with their limits, are in
`references/files-and-email.md`.

## Checklist for a production integration

- [ ] Key from the environment, never from source; startup check via `/v1/auth/validate`.
- [ ] `Lightfield-Version` on every request (automatic in the SDKs).
- [ ] Definitions fetched at startup; no hardcoded field keys or option IDs.
- [ ] Search-before-create on every upsert path.
- [ ] `Idempotency-Key` on every write, with the same key reused across retries.
- [ ] Retry only `429`, `5xx` and `409 idempotency_conflict`, honouring `Retry-After`.
- [ ] Relationship batches split at 25.
- [ ] Reads verified through Retrieve where freshness matters.
- [ ] Errors branched on `code`/`param`, and logged without the key.
