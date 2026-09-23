# Lightfield plugin for ChatGPT, Codex, and Grok

Connect ChatGPT, Codex, and Grok to [Lightfield](https://lightfield.app), the
AI-native CRM. The plugin can read and write accounts, contacts,
opportunities, tasks, notes, meetings, and emails in a signed-in workspace. It
also teaches the agent how to build reliable integrations with the Lightfield
API.

Maintained by Lightfield. Documentation: <https://docs.lightfield.app>.

## What's included

This repository packages the same Lightfield workflows for both plugin formats:

- `plugin.json` identifies the plugin and defines its ChatGPT presentation.
- `mcp.json` connects the OAuth-enabled Lightfield MCP server.
- `.grok-plugin/plugin.json` and `.mcp.json` provide the Grok plugin manifest
  and MCP configuration.
- `skills/` contains shared workflows used by both plugin formats.
- `commands/` contains Grok slash commands for briefs, imports, diagnostics,
  and integration scaffolding. Equivalent ChatGPT workflows are packaged as
  skills.
- `assets/` contains Lightfield branding used by plugin surfaces.
- `platforms/` declares each distributable archive without duplicating the
  host manifests or shared capabilities.
- `scripts/package-plugin.sh` builds any declared platform package.

The host entry points intentionally stay at the repository root because each
platform discovers fixed paths there. See [ARCHITECTURE.md](ARCHITECTURE.md)
for the adapter boundary and the steps for adding another platform.

### MCP server

`https://mcp.lightfield.app/mcp` uses Streamable HTTP and OAuth 2.1. Users
authorize as themselves, and every call is constrained by their existing
Lightfield permissions.

| Tool | Access | Purpose |
| --- | --- | --- |
| `get_current_user` | Read | Return the signed-in member and role |
| `search_lightfield_api_docs` | Read | Find API endpoints and guides |
| `get_lightfield_api_details` | Read | Read the current docs for an endpoint |
| `read_from_lightfield` | Read | Make an authorized REST API `GET` |
| `write_to_lightfield` | Write | Make an authorized REST API `POST` |

### Skills

| Skill | Use |
| --- | --- |
| `lightfield` | Route a request to the right Lightfield workflow |
| `lightfield-crm` | Read and update records in a live workspace |
| `lightfield-brief` | Prepare an account or opportunity briefing |
| `lightfield-import` | Dry-run, deduplicate, and import CSV or JSON records |
| `lightfield-doctor` | Diagnose authentication and permissions |
| `lightfield-api` | Build against the REST API, SDKs, or CLI |
| `lightfield-integration` | Scaffold a production-ready integration |

## Install and test

### Grok

The Lightfield listing for the xAI plugin marketplace is tracked in
[xai-org/plugin-marketplace#749](https://github.com/xai-org/plugin-marketplace/pull/749).
Once it is available in the marketplace, open `/plugin` in Grok, search for
**Lightfield**, and install it. The first MCP tool call starts the OAuth flow.

Use `/lightfield-doctor` to check the MCP connection and, when applicable, a
direct API key used for integration development.

### ChatGPT and Codex

Before publication, test the MCP tools directly in ChatGPT developer mode:

1. Open ChatGPT settings, select **Security and login**, and enable
   **Developer mode**.
2. Open **ChatGPT Plugins**, select the plus button, and add
   `https://mcp.lightfield.app/mcp`.
3. Complete the OAuth flow.
4. Start a new Work chat, select the Lightfield connection with `@`, and try a
   read-only request such as “Who am I in Lightfield?”

Test realistic read and write requests, invalid inputs, denied permissions,
and requests that should not call a tool. Do not test writes against production
data without an explicit plan.

## Package the platform adapters

Build either platform from its declarative package spec:

```sh
./scripts/package-plugin.sh chatgpt
./scripts/package-plugin.sh grok
```

The script writes reproducible versioned ZIPs to `dist/`, stages only
allowlisted files, and checks archive integrity. To add a platform, add its
required host files and a `platforms/<name>/package-spec.json`; the packaging
implementation does not need platform-specific branches.

### Publish for ChatGPT and Codex

Submit this repository through the OpenAI plugin submission portal using the
**With MCP** flow and the public endpoint `https://mcp.lightfield.app/mcp`.
Upload `chatgpt-app-submission.json` to the submission-form import control.
Upload `dist/lightfield-chatgpt-1.0.0.zip` separately on the **Skills** tab;
the JSON and ZIP serve different parts of the submission and are not
interchangeable.

Use `fixtures/openai-review/` to seed an isolated reviewer workspace. The
fixture README identifies the two privacy/activity records that require manual
setup and the dry-run CSV that must not be imported in advance.

The root `plugin.json`, `mcp.json`, skills, references, and assets form the
portable package. Public plugins are published once to the shared ChatGPT and
Codex plugin directory. See [SUBMISSION.md](SUBMISSION.md) for the prepared test
cases, tool-annotation justifications, release notes, and portal-only steps.

For local desktop testing of the packaged skills, add the plugin to a local
marketplace as described in the OpenAI plugin packaging documentation, restart
the ChatGPT desktop app, then install it from that marketplace source.

## Credentials

Interactive CRM work uses MCP OAuth; the plugin stores no API key.

Application code that calls the REST API directly uses a scoped key created by
an organization admin at
<https://crm.lightfield.app/crm/settings/api-keys>. Store it only in the
`LIGHTFIELD_API_KEY` environment variable. Keys begin with `sk_lf_` and are
shown once.

## Network endpoints

| Endpoint | Used for | Credential |
| --- | --- | --- |
| `https://mcp.lightfield.app/mcp` | MCP tools | User OAuth token |
| `https://api.stytch.lightfield.app` | OAuth authorization | None supplied by the plugin |
| `https://api.lightfield.app` | Direct API and SDK calls | `LIGHTFIELD_API_KEY` |
| `https://docs.lightfield.app` | Public API documentation | None |

The plugin contains no hooks, executables, install scripts, or telemetry.

## Safety defaults

The skills require the agent to discover organization-specific field keys,
search before creating records, dry-run bulk imports, confirm destructive or
outward-facing operations, and verify writes through fresh retrieve endpoints.
They never ask the agent to guess endpoints, select option IDs, or hidden data.

## Support

- Product and API docs: <https://docs.lightfield.app>
- MCP setup: <https://docs.lightfield.app/getting-started/mcp-quickstart>
- Privacy policy: <https://lightfield.app/privacy>
- Issues: <https://github.com/Lightfld/lightfield-plugin/issues>

## License

MIT. See [LICENSE](LICENSE).
