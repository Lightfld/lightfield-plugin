---
name: lightfield
description: >-
  Entry point for anything Lightfield, the AI-native CRM. Use when "Lightfield"
  is mentioned, when a request touches accounts, contacts, opportunities, tasks,
  notes, meetings, emails or lists in Lightfield, or when a lightfield.app URL
  (crm.lightfield.app, api.lightfield.app, docs.lightfield.app) is pasted.
  Routes to `lightfield-crm` for reading and writing records in a live
  workspace, and to `lightfield-api` for writing integration code against the
  REST API, SDKs, or CLI.
---

# Lightfield

Lightfield is an AI-native CRM. Its objects are accounts, contacts,
opportunities, tasks, notes, meetings, emails, messages, channels, files, lists
and members, plus custom objects. Everything in the product is reachable through
one versioned REST API (`https://api.lightfield.app/v1`), and the same API backs
the official MCP server, SDKs, and CLI.

## Pick the right path

There are two ways to work with Lightfield, and they solve different problems.

| You want to… | Use | Skill |
| --- | --- | --- |
| Look up, create, or update records in the user's own workspace, now | The `lightfield` MCP server tools | `lightfield-crm` |
| Write code that talks to Lightfield (script, service, sync job, webhook consumer) | The REST API via SDK, CLI, or curl with an API key | `lightfield-api` |

If the request is "what's the status of the Acme renewal" or "create a follow-up
task", that is the MCP path. If it is "write a script that syncs our accounts
into Lightfield nightly", that is the API path. A request can need both: explore
the data model over MCP, then write the integration.

## Non-negotiable rules

These hold on both paths. Violating them is the usual cause of a wrong write.

1. **Never guess an endpoint, field key, query parameter, or select option ID.**
   Field and relationship keys are org-specific. Read them from the definitions
   endpoint (`GET /v1/{objectType}/definitions`), or over MCP from
   `search_lightfield_api_docs` → `get_lightfield_api_details`.
2. **Search before you create.** Duplicate accounts and contacts are the most
   expensive mistake in a CRM and they are not trivially reversible. Filter the
   list endpoint for an existing record first; see `lightfield-crm`.
3. **Writes are real customer data.** Confirm with the user before a create,
   update, merge, or email send that they did not explicitly ask for. Merges
   cannot be undone.
4. **Every HTTP request carries `Lightfield-Version: 2026-03-01`.** Requests may
   error without it. The SDKs and MCP server set it for you.
5. **List results come from a search index that can lag.** To verify a write, or
   to read a record you just changed, use the individual Retrieve method
   (`GET /v1/{objectType}/{id}`), not the list method.

## Connecting

**MCP (no API key):** Streamable HTTP with OAuth 2.1 at
`https://mcp.lightfield.app/mcp`. This plugin ships that server in its
`.mcp.json`, so installing the plugin is enough. Approve the OAuth prompt on
first use. Tools: `get_current_user`, `search_lightfield_api_docs`,
`get_lightfield_api_details`, `read_from_lightfield`, `write_to_lightfield`.
Access is scoped to the signed-in member's own permissions.

**API key (for code):** an org admin creates a scoped key at
<https://crm.lightfield.app/crm/settings/api-keys>. It is shown once, starts
with `sk_lf_`, and belongs in `LIGHTFIELD_API_KEY` in the environment, never in
source, a config file that is committed, or a log line. Verify a key with
`GET /v1/auth/validate`, which returns `active`, `subjectType`, and the granted
`scopes`.

## Docs

<https://docs.lightfield.app> is the source of truth and is more current than
any model's training data. Useful pages:

- API reference: <https://docs.lightfield.app/api>
- Fields and relationships: <https://docs.lightfield.app/using-the-api/fields-and-relationships>
- List methods (pagination and filtering): <https://docs.lightfield.app/using-the-api/list-endpoints>
- Errors: <https://docs.lightfield.app/using-the-api/errors>
- Scopes: <https://docs.lightfield.app/using-the-api/scopes>

Any page is available as markdown by appending `/index.md` to its path, e.g.
<https://docs.lightfield.app/using-the-api/errors/index.md>.

## Commands in this plugin

- `/lightfield-doctor`: check the MCP connection and API key, and report scopes.
- `/lightfield-brief`: assemble a briefing on an account or opportunity.
- `/lightfield-import`: load records from a local file, deduped and rate-limited.
- `/lightfield-integration`: scaffold a production-shaped API integration.
