# Common Lightfield read and write sequences

Paths below are what you pass to `read_from_lightfield` / `write_to_lightfield`.
Over HTTP, prefix `https://api.lightfield.app` and add the auth and version
headers.

**Relationship slugs and option IDs in these examples are placeholders.** Only
`$task-account` and `$account-contact` appear in the public docs; every other
slug and every `opt_…` / `pd_…` below stands for whatever
`GET /v1/{objectType}/definitions` returns for that organization. Read
definitions once per object type and substitute. A guessed slug fails with
`400 unknown_relationship`.

## Resolve "me"

```
get_current_user                      → membershipId (mem_…), email, role
/v1/tasks?{assignee-relationship-slug}[contains]=mem_…&$status[equal]=TODO
```

Always resolve the member ID before filtering by owner or assignee. Never
match on a name string. Confirm the relationship slug against
`/v1/tasks/definitions` for the org; assignee and owner slugs vary.

## Find an account by name, then its 360

```
/v1/accounts?$name[equal]=Acme%20Corp&limit=5     → acc_abc123 (verify the match)
/v1/accounts/acc_abc123                            → current field values, httpLink
/v1/opportunities?{account-relationship-slug}[contains]=acc_abc123&limit=25
/v1/contacts?$account-contact[contains]=acc_abc123&limit=25
/v1/tasks?$task-account[contains]=acc_abc123&$status[equal]=TODO&limit=25
/v1/notes?{account-relationship-slug}[contains]=acc_abc123&limit=10
/v1/meetings?limit=10
```

Two cautions. Relationship slugs are org-specific: read
`/v1/{objectType}/definitions` once and reuse them for the rest of the
sequence. And `$name[equal]` can return several plausible matches; when it does,
show the candidates with their `httpLink` and ask rather than picking the first.

## Create a contact without making a duplicate

```
1. /v1/contacts?$email[contains]=alex@customer.com
2. if a row comes back → POST /v1/contacts/{id} with just the changed fields
3. otherwise           → POST /v1/contacts
   { "fields": { "$name": {"firstName": "Alex", "lastName": "Rivera"},
                 "$email": ["alex@customer.com"], "$title": "VP Ops" },
     "relationships": { "$account": ["acc_abc123"] } }
4. GET /v1/contacts/{id} to confirm (the list index may still be stale)
```

Check email before name. Names collide; addresses mostly do not.

## Move an opportunity to a new stage

```
1. /v1/opportunities/definitions     → $stage options, and $pipeline if enabled
2. pick the option whose label matches, and whose parentId is the right pipeline
3. POST /v1/opportunities/opp_abc123
   { "fields": { "$stage": "{stage-option-id}" } }
4. GET /v1/opportunities/opp_abc123   → confirm $stage.value
```

Prefer the option ID over a label. Labels repeat across pipelines, and outside
opportunities a label alone is rejected.

## Log a task against an account

```
1. /v1/tasks/definitions              → $status options, assignee/account slugs
2. POST /v1/tasks
   { "fields": { "$name": "Send renewal proposal",
                 "$dueDate": "2026-10-01T17:00:00+00:00",
                 "$status": "{todo-option-id}" },
     "relationships": { "$account": ["acc_abc123"], "{assignee-slug}": ["mem_abc123"] } }
```

## Attach a note

```
POST /v1/notes
{ "fields": { "$title": "Renewal call recap", "$body": "…markdown…" },
  "relationships": { "$account": ["acc_abc123"], "$opportunity": ["opp_abc123"] } }
```

Note bodies are markdown.

## Read a meeting and its transcript

```
/v1/meetings?limit=25                          → pick the meeting
/v1/meetings/{id}                              → $transcript relationship → fil_…
/v1/files/fil_abc123/url                       → signed download URL
```

The signed URL expires; fetch it when you are ready to read, not in advance.

## Send an email (confirm first)

```
1. /v1/emails/send docs via get_lightfield_api_details
2. POST /v1/emails/send
   { "from": "sam@example.com", "to": ["alex@customer.com"],
     "subject": "Renewal next steps",
     "messageBody": { "contentType": "TEXT", "content": "…" } }
```

`from` must be a connected mailbox owned by the caller. Show the user the exact
draft and get an explicit yes before sending; there is no unsend. Replies and
forwards are not supported: sends and drafts create new messages only. For a
safer default, use `POST /v1/emails/draft` and let the user send it themselves.

## Custom objects

```
/v1/objects                                    → available custom object types
/v1/objects/{entitySlug}/definitions           → its fields and relationships
/v1/objects/{entitySlug}?limit=25              → list records
/v1/objects/{entitySlug}/values/{id}           → retrieve one
POST /v1/objects/{entitySlug}/values           → create ({ fields, relationships })
```

Note the asymmetry: listing is `/v1/objects/{entitySlug}`, but a single record
lives under `/v1/objects/{entitySlug}/values/{id}`.

## Merging duplicates (irreversible)

```
POST /v1/accounts/merge
{ "primaryId": "acc_keep", "duplicateId": "acc_drop", "fieldResolutions": { … } }
```

Also available for contacts, opportunities, and custom objects. Show the user
both records and which one survives, and get explicit confirmation. Poll
`GET /v1/merges/{id}` for status.
