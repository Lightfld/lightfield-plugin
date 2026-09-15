# Lightfield plugin

Connect your coding agent to [Lightfield](https://lightfield.app), the AI-native
CRM. Read and write accounts, contacts, opportunities, tasks, notes, meetings
and emails in your workspace, and build integrations against the Lightfield API
without guessing at endpoints or field keys.

Maintained by Lightfield. Docs: <https://docs.lightfield.app>.

## Install

In Grok Build, open `/plugin`, search for **Lightfield**, and install.

The plugin ships the Lightfield MCP server, so there is nothing else to
configure. The first tool call opens an OAuth flow in your browser; approve it
and you are connected as yourself, with your own permissions.

Writing integration code additionally needs an API key: see
[Credentials](#credentials).

Run `/lightfield-doctor` to confirm both paths.

## What it contains

### MCP server

`https://mcp.lightfield.app/mcp`: Streamable HTTP with OAuth 2.1
(authorization server: `api.stytch.lightfield.app`). No API key, no secret in
any config file. Five tools:

| Tool | Access | Purpose |
| --- | --- | --- |
| `get_current_user` | read | Your name, email, membership ID, role |
| `search_lightfield_api_docs` | read | Endpoint catalog and API guides |
| `get_lightfield_api_details` | read | Full docs for one endpoint |
| `read_from_lightfield` | read | `GET` against the Lightfield REST API |
| `write_to_lightfield` | write | `POST` against the Lightfield REST API |

Every call runs as the signed-in member and is limited to what that member can
already see and do in Lightfield.

### Skills

| Skill | Use |
| --- | --- |
| `lightfield` | Entry point. Explains the product and routes to the other two. |
| `lightfield-crm` | Reading and writing records in a live workspace: definitions, filters, pagination, relationship writes, pipelines and stages, dedupe, privacy-filtered reads. |
| `lightfield-api` | Writing code against the REST API: keys and scopes, the Python, TypeScript and Go SDKs and the CLI, idempotency, rate limits, typed errors, file upload, email. |

### Commands

| Command | Does |
| --- | --- |
| `/lightfield-doctor` | Checks the MCP connection and API key, and reports granted scopes |
| `/lightfield-brief` | Assembles a briefing on an account or opportunity |
| `/lightfield-import` | Imports a CSV or JSON file, mapped and deduped, dry run first |
| `/lightfield-integration` | Scaffolds a production-shaped API integration |

## Credentials

**MCP** uses OAuth: nothing to store.

**API key**, for code that calls the API directly: an org admin creates one at
<https://crm.lightfield.app/crm/settings/api-keys> with the narrowest
[scopes](https://docs.lightfield.app/using-the-api/scopes) the integration
needs. It is shown once and starts with `sk_lf_`. The skills and commands here
read it from the `LIGHTFIELD_API_KEY` environment variable and never write it to
a file, a log, or a command line.

## Network endpoints

This plugin talks to exactly three hosts, all operated by Lightfield:

| Endpoint | When | Credential |
| --- | --- | --- |
| `https://mcp.lightfield.app/mcp` | Every MCP tool call | OAuth 2.1 token, obtained interactively |
| `https://api.stytch.lightfield.app` | OAuth authorization during connection | n/a |
| `https://api.lightfield.app` | Only when you ask for direct API or SDK calls | `LIGHTFIELD_API_KEY` from your environment |

The MCP server may fetch public pages from `https://docs.lightfield.app` to
answer documentation lookups.

The plugin ships no hooks, no executables, no install scripts, and no telemetry.
The skills and commands are markdown. Nothing here reads credentials from your
filesystem or sends data anywhere except the endpoints above.

## Safety defaults

The skills tell the agent to search before creating records, to confirm before
any merge or email send, to read field definitions rather than guess at keys,
and to verify writes through the individual Retrieve endpoint because list
results come from a lagging search index. `/lightfield-import` always dry-runs
and waits for approval before writing.

## Support

- Docs: <https://docs.lightfield.app>
- API reference: <https://docs.lightfield.app/api>
- MCP setup: <https://docs.lightfield.app/getting-started/mcp-quickstart>
- Issues: <https://github.com/Lightfld/lightfield-plugin/issues>

## License

MIT. See [LICENSE](LICENSE).
