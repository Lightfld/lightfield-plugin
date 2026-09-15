# Filtering and pagination

Source: <https://docs.lightfield.app/using-the-api/list-endpoints>

## Pagination

`limit` (1–25, default applies when omitted) and `offset`. A page shorter than
`limit` means there is nothing left. Do not persist offsets between runs:
records are created and deleted underneath you.

List responses are served from a search index that lags writes. Use
`GET /v1/{objectType}/{id}` when you need the current value.

## Filter syntax

```
?{key}[{operator}]={value}
```

The key is a field key (`$name`, `icp-score`) or a relationship definition slug
(`$task-account`). Multiple filters are AND-ed. Any operator can be negated with
a leading `-`: `$name[-equal]=Acme` matches everything that is not Acme.

If no operator is given, `equal` is used when valid for the type, otherwise
`contains`.

## Operators by value type

| Value type | `equal` | `greaterThan` / `greaterThanOrEqual` / `lessThan` / `lessThanOrEqual` | `startsWith` | `contains` |
| --- | --- | --- | --- | --- |
| `NUMBER` | yes | yes | no | no |
| `CURRENCY` | yes | yes | no | no |
| `DATETIME` | yes | yes | no | no |
| `TEXT` | yes | no | yes | no |
| `FULL_NAME` | yes | no | yes | no |
| `SOCIAL_HANDLE` | yes | no | yes | no |
| `ADDRESS` | yes | no | yes | no |
| `CHECKBOX` | yes | no | no | no |
| `SINGLE_SELECT` | yes | no | no | no |
| `EMAIL` | no | no | no | yes |
| `TELEPHONE` | no | no | no | yes |
| `URL` | no | no | no | yes |
| `MULTI_SELECT` | not filterable | | | |
| `MARKDOWN` | not filterable | | | |

A `startsWith` filter with an empty value matches records where the field is set
and non-empty: the way to ask "has a LinkedIn URL at all".

## Relationship filters

Use the relationship **definition slug** from
`GET /v1/{objectType}/definitions`, not the key that appears in a record's
`relationships` object. `contains` and `equal` behave identically here.

```bash
# Tasks on an account
curl https://api.lightfield.app/v1/tasks -G \
  -H "Authorization: Bearer $LIGHTFIELD_API_KEY" \
  -H "Lightfield-Version: 2026-03-01" \
  --data-urlencode '$task-account[contains]=acc_abc123'

# Accounts linked to a contact
curl https://api.lightfield.app/v1/accounts -G \
  -H "Authorization: Bearer $LIGHTFIELD_API_KEY" \
  -H "Lightfield-Version: 2026-03-01" \
  --data-urlencode '$account-contact[contains]=con_def456'
```

## Pipeline and stage filters (beta)

Check definitions for `$pipeline` before using these; if it is absent, the
capability is not enabled for that org and object type.

- Filter values must be **IDs**: `$pipeline[equal]=pd_…`. Pipeline *names* are
  accepted as write hints, not as filter values.
- A stage option ID (`$stage[equal]=opt_…`) identifies a stage on its own.
- A stage *label* (`$stage[equal]=Qualified`) is matched case-insensitively with
  whitespace collapsed, but returns `400 ambiguous_stage_label` when the label
  exists in more than one pipeline. Add a positive `$pipeline[equal]`, or use
  the option ID.
- Only one positive pipeline filter is allowed. `$pipeline[-equal]` excludes but
  does not disambiguate.
- Filters are AND-ed, so a stage option ID plus a pipeline that does not own it
  matches nothing.
- Unlike opportunity label *writes*, label *filters* never fall back to the
  default pipeline.

## Worked examples

```bash
# Does this account already exist? (run before creating)
/v1/accounts?$name[equal]=Acme%20Corp

# Does this contact already exist?
/v1/contacts?$email[contains]=alex@customer.com

# Big opportunities touched since March
/v1/opportunities?$amount[greaterThanOrEqual]=100000&$lastInteractionAt[greaterThanOrEqual]=2026-03-01T00:00:00.000Z

# Open tasks on one account
/v1/tasks?$task-account[contains]=acc_abc123&$status[equal]=TODO

# Contactable C-suite with an Instagram presence, excluding one person
/v1/contacts?$doNotContact[equal]=false&$instagram[startsWith]=&$title[startsWith]=Chief&$name[-equal]=Alice%20Bob
```

Values must be URL-encoded. With curl use `-G --data-urlencode`; `$` and `[]`
also need quoting in the shell.
