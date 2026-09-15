# Field value types and ID prefixes

Source: <https://docs.lightfield.app/using-the-api/fields-and-relationships>

Reads wrap values as `{ "valueType": …, "value": … }`. Writes take the bare
value. `null` clears a field.

| `valueType` | Write format | Notes |
| --- | --- | --- |
| `TEXT` | `string` | |
| `NUMBER` | `number` | Up to 2 decimal places, within safe integer range. |
| `CHECKBOX` | `boolean \| null` | |
| `CURRENCY` | `number \| null` | Currency code comes from `typeConfiguration.currency`; you send only the amount. |
| `DATETIME` | ISO 8601 string with offset | e.g. `"2026-03-16T12:00:00+00:00"`. Stored as UTC. |
| `EMAIL` | `string \| string[] \| null` | Usually an array. Exception: `meeting.$organizerEmail` is a single string; `meeting.$attendeeEmails` stays an array. |
| `TELEPHONE` | `string[]` | See normalization below. |
| `URL` | `string \| string[] \| null` | |
| `ADDRESS` | object or `null` | `null` clears every part. |
| `FULL_NAME` | `{ firstName, lastName }` | |
| `SOCIAL_HANDLE` | profile URL string or `null` | Must match the field's `handleService`. |
| `SINGLE_SELECT` | option ID string or `null` | `opt_…`; `pd_…` for `$pipeline`. |
| `MULTI_SELECT` | array of option IDs | |
| `READONLY_MARKDOWN` | n/a | Not writable. |

## Address

All parts optional: `street`, `street2`, `city`, `state`, `postalCode`,
`country` (ISO 3166-1 alpha-2, exactly 2 characters), `latitude`, `longitude`.

```json
{ "street": "123 Main St", "city": "San Francisco", "state": "CA", "postalCode": "94105", "country": "US" }
```

## Telephone

Validated and normalized on write. With a `+` prefix it must be valid E.164
(`"+12025551234"`). Without one it is tried as a US number, then as a 7–15 digit
local number. Extensions normalize to `;ext=`: `x100`, `ext:100` and `#100` all
become `"+12025551234;ext=100"`.

## Social handle

`typeConfiguration.handleService` is `TWITTER`, `LINKEDIN`, `FACEBOOK` or
`INSTAGRAM`, and the value must be a profile URL for that platform
(`https://x.com/{user}`, `https://linkedin.com/in/{slug}` or
`/company/{slug}`, `https://facebook.com/{user}`,
`https://www.instagram.com/{user}`). Regional subdomains and query strings are
accepted. `null` clears it.

## Select options

Option objects are `{ id, label, description, parentId? }`. `parentId` appears
on dependent selects and points at the owning option in the field named by
`typeConfiguration.parentFieldKey`. Options are org-specific, so read them from
definitions every time rather than caching IDs across organizations.

## Type configuration by type

| Type | Keys |
| --- | --- |
| `CURRENCY` | `currency` (ISO 4217) |
| `EMAIL`, `TELEPHONE`, `URL` | `unique`, `multipleValues` |
| `SOCIAL_HANDLE` | `handleService` |
| `SINGLE_SELECT` | `options`, `parentFieldKey` |
| `MULTI_SELECT` | `options` |

Everything else returns `{}`.

## Field history

Attribute-backed fields keep a value history:

```
GET /v1/accounts/{id}/fields/{fieldKey}/history
GET /v1/contacts/{id}/fields/{fieldKey}/history
GET /v1/opportunities/{id}/fields/{fieldKey}/history
GET /v1/objects/{entitySlug}/values/{id}/fields/{fieldKey}/history
```

Use `$stage` for a system field, a bare slug for a custom one. Newest first,
consecutive identical values collapsed, default 20 entries, `limit` up to 100,
`nextCursor` feeds the `after` parameter. Entries carry `value`, `displayValue`,
`recordedAt` and `isCreate`: **not** who made the change. Column-backed system
fields and relationships have no history.

## ID prefixes

| Entity | Prefix |
| --- | --- |
| Account | `acc_` |
| Contact | `con_` |
| Opportunity | `opp_` |
| Member | `mem_` |
| File | `fil_` |
| Email | `eml_` |
| Field definition | `ad_` |
| Relationship definition | `rd_` |
| Select option | `opt_` |
| Pipeline | `pd_` |
| Attribute value | `av_` |
| Relationship value | `rv_` |

A prefix mismatch (passing a `con_` where an `acc_` belongs) surfaces as
`referenced_resource_missing` or `relationship_entity_missing`, not as a type
error, so check the prefix first when you see either.
