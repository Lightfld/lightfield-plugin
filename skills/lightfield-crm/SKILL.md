---
name: lightfield-crm
description: >-
  Read and write records in a live Lightfield CRM workspace through the
  Lightfield MCP tools: look up accounts, contacts, opportunities, tasks,
  notes, meetings and emails, filter and paginate list endpoints, discover
  org-specific field and relationship keys, create or update records without
  making duplicates, and handle pipelines and stages. Use whenever the request
  is about data that lives in the user's Lightfield workspace rather than about
  writing integration code.
---

# Working with Lightfield CRM data

The `lightfield` MCP server exposes the whole REST API through five tools. Two
of them are documentation lookups, two are the actual read and write, and one
identifies the caller.

| Tool | Use |
| --- | --- |
| `get_current_user` | Name, email, membership ID, role of the signed-in member. Call this first for anything scoped to "me": "my tasks", "accounts I own". |
| `search_lightfield_api_docs` | The endpoint catalog plus the fields/relationships and list-method guides. Takes no arguments. |
| `get_lightfield_api_details` | Full docs for one endpoint. Only accepts docs paths returned by the catalog. |
| `read_from_lightfield` | `GET` with a path like `/v1/accounts?limit=25`. |
| `write_to_lightfield` | `POST` with a path and a JSON body. Creates and updates. |

## The loop

1. `search_lightfield_api_docs` to find the endpoint family.
2. `get_lightfield_api_details` on that endpoint for its exact parameters and
   body schema.
3. `read_from_lightfield` / `write_to_lightfield`.

Never skip to step 3 with a guessed path or parameter. Paths must start with
`/`. This skill front-loads the stable parts (filter syntax, value types,
response shape) so you spend tool calls on the parts that are org-specific.

### Read field definitions before writing

Field and relationship keys differ per organization. Before the first write to
an object type in a session, read its definitions:

```
GET /v1/accounts/definitions
GET /v1/contacts/definitions
GET /v1/opportunities/definitions
GET /v1/objects/{entitySlug}/definitions
```

The response gives `fieldDefinitions` and `relationshipDefinitions`, each with
`slug`, `label`, `valueType`, `system`, `readOnly`, and `typeConfiguration`. It
is the only correct source for:

- **Select option IDs.** `SINGLE_SELECT` and `MULTI_SELECT` values are option
  IDs (`opt_…`), not labels, and options are org-specific. Never hardcode one.
- **Which keys exist.** System keys are `$`-prefixed (`$name`, `$stage`,
  `$owner`); custom keys are bare (`priority`, `icp-score`).
- **Relationship slugs for filtering**, which differ from response keys.
- **`readOnly: true` fields** (AI-generated summaries and similar): writing one
  fails.

## Record shape

Reads wrap every field value:

```json
{
  "id": "opp_abc123",
  "createdAt": "2026-05-01T16:00:00.000Z",
  "httpLink": "https://crm.lightfield.app/...",
  "fields": {
    "$name": { "valueType": "TEXT", "value": "Acme renewal" },
    "$stage": { "valueType": "SINGLE_SELECT", "value": "opt_abc123" }
  },
  "relationships": {
    "$account": { "cardinality": "HAS_ONE", "objectType": "account", "values": ["acc_abc123"] }
  }
}
```

Writes take **bare values**, not the wrapper:

```json
{ "fields": { "$name": "Acme renewal", "$stage": "opt_abc123" } }
```

`httpLink` is the record's URL in the Lightfield UI: always include it when
reporting a record back to the user.

Value types and their formats (addresses, phone numbers, social handles, names)
are in `references/field-types.md`.

## Finding records

`GET /v1/{objectType}` lists records. `limit` is **1–25** (25 is the maximum,
not a suggestion) and `offset` walks pages. Stop when a page returns fewer rows
than `limit`. Do not store offsets between runs; the index shifts.

Filters are query parameters shaped `key[operator]=value`:

```
/v1/contacts?$email[contains]=alex@customer.com
/v1/opportunities?$amount[greaterThanOrEqual]=100000&$stage[equal]=opt_abc123
/v1/tasks?$task-account[contains]=acc_abc123&$status[equal]=TODO
```

Which operator is legal depends on the field's `valueType`, any operator can be
negated with a `-` prefix (`$name[-equal]=…`), and relationship filters use the
relationship **definition slug**. The full operator matrix, relationship
filtering, and pipeline/stage filtering are in `references/filtering.md`.

**List results are served from a search index that may not have recent
changes.** After a write, and any time freshness matters, read the record back
with `GET /v1/{objectType}/{id}`.

## Writing

Creates are `POST /v1/{objectType}`; updates are `POST /v1/{objectType}/{id}`
with only the fields being changed. Both take `fields` and optionally
`relationships`.

**Search before you create.** Duplicates are the standard way to damage a CRM.
Check for an existing record first (by `$name[equal]` for an account, by
`$email[contains]` for a contact), and update it instead when one exists.

**Relationships.** On create, pass an ID or array of IDs. On update, pass
`add`, `remove`, or `replace`:

```json
{ "relationships": { "$contact": { "add": ["con_abc123"] } } }
```

One request may reference at most **25** entity IDs and change at most 25 links,
counted across all relationships in the request. Over either limit returns `422`
`relationship_write_limit_exceeded`, so split the change.

**Stages and pipelines.** Write a `$stage` option ID and the pipeline follows
automatically. A stage *label* is only safe for opportunities; for accounts,
contacts and custom objects a label needs a `$pipeline` hint, because labels
repeat across pipelines. `$pipeline` is a write hint only: it is not stored,
and sending it without a stage is rejected. If `$pipeline` is absent from
definitions, the beta is not enabled for that org and object type. Do not send
it, and do not treat the resulting `400 unknown_field` as retryable.

**Deletes are not reachable over MCP.** `write_to_lightfield` issues `POST`
only, so `DELETE /v1/{objectType}/{id}` is out of reach here by design. If a
record genuinely needs deleting, say so and point the user at the Lightfield UI
or an API key with the right scope. Do not approximate a delete by blanking
fields.

**Confirm destructive or outward-facing writes.** Merges
(`POST /v1/{objectType}/merge`) are permanent. Sends
(`POST /v1/emails/send`) leave the building. Ask first unless the user asked for
that exact action.

## Privacy-aware reads

Emails, messages and channels are filtered by what the calling member may see.
An email read with metadata-only access returns `null` for `$subject` and
`$body`, omits `relationships.$attachment`, and reports
`accessLevel: "METADATA"`. A private channel the caller cannot see is
indistinguishable from one that does not exist. Report what you actually got.
Never present a redacted record as empty or missing.

## Errors

`400`/`422` bodies carry `code` and `param` that name the exact problem:
`unknown_field` and `unknown_relationship` mean re-read definitions;
`referenced_resource_missing` and `relationship_entity_missing` mean an ID in
the body does not exist; `ambiguous_stage_label` returns `candidates` to choose
from. Read `param` before retrying, and change the input, since retrying the
same body produces the same error.

## Recipes

Multi-step reads that come up constantly (an account 360, open pipeline by
owner, contact lookup by email, logging a meeting outcome) are in
`references/recipes.md`.
