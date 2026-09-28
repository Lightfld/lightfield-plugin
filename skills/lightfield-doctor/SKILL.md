---
name: lightfield-doctor
description: >-
  Diagnose a Lightfield connection, OAuth session, API key, scopes, and current
  user identity, then report exactly what works. Use when Lightfield tools are
  missing, authentication fails, permissions are unclear, or the user asks to
  check or troubleshoot their Lightfield setup.
---

# Diagnose a Lightfield connection

Check both connection paths unless the user asks about only one. Do not change
configuration or credentials without permission.

## MCP path

1. Call `get_current_user`.
   - Success: report the member's name, email, membership ID, and role.
   - Tools missing: the Lightfield MCP server is not loaded. Ask the user to
     enable or reinstall the Lightfield plugin. During development, have them
     confirm that `https://mcp.lightfield.app/mcp` is connected in ChatGPT
     developer mode.
   - Authentication error: OAuth has not been completed or has expired. Ask the
     user to reconnect the plugin and approve the browser authorization flow.
2. Confirm read access with one cheap call: use `read_from_lightfield` on
   `/v1/accounts?limit=1`. Report the status, not the record contents.

## Direct API path

Only inspect `LIGHTFIELD_API_KEY` when the current environment provides shell
or environment-variable access. ChatGPT's MCP connection does not expose or
need this key.

1. Report whether the variable is set without printing, logging, or echoing its
   value.
2. If set, validate it with `GET https://api.lightfield.app/v1/auth/validate`
   using the bearer token and `Lightfield-Version: 2026-03-01`.
3. A `200` response reports `subjectType` and granted `scopes`; an empty scope
   array means full access. A `401` means the key is invalid or revoked. For
   other responses, report the HTTP status and `error.type`.
4. If the user names a task, compare its required scopes with the returned
   scopes. Scopes are `{object}:{create|update|read}`, plus `members:read`.

Never place the key in a command argument, output, file, or log. If the current
environment cannot inspect variables, say that direct API-key validation must
run in the user's development environment; do not infer its status.

## Report

Return one short table with each check, its result, and one next action for any
failure. Distinguish the OAuth-backed MCP path used for interactive CRM work
from the API-key path used by application code.
