---
description: Check the Lightfield connection (MCP server, API key, scopes, identity) and report exactly what works.
argument-hint: "[mcp|api] (optional: check only one path)"
---

Diagnose the user's Lightfield setup and report what is usable. Check both paths
unless `$ARGUMENTS` names one. Do not change any configuration without asking.

## MCP path

1. Call `get_current_user`.
   - Success → report name, email, membership ID and role. The connection works.
   - Tools missing → the `lightfield` MCP server is not loaded. It ships in this
     plugin's `.mcp.json` at `https://mcp.lightfield.app/mcp`; tell the user to
     reload or reinstall the plugin, or add it manually:
     `claude mcp add --transport http lightfield https://mcp.lightfield.app/mcp`.
   - Auth error → OAuth has not been completed or has expired. Tell the user to
     re-run the connection flow and approve it in the browser.
2. Confirm read access with one cheap call: `read_from_lightfield` on
   `/v1/accounts?limit=1`. Report the status, not the record contents.

## API key path

1. Check whether `LIGHTFIELD_API_KEY` is set. Report set/unset only. Never
   print the value, and never echo the variable.
2. If set, validate it:

   ```bash
   curl -s -o /tmp/lf-auth.json -w '%{http_code}' https://api.lightfield.app/v1/auth/validate \
     -H "Authorization: Bearer $LIGHTFIELD_API_KEY" \
     -H "Lightfield-Version: 2026-03-01"
   ```

   - `200` → report `subjectType` (`user` or `workspace`) and the granted
     `scopes` from the body. An empty `scopes` array means full access.
   - `401` → the key is invalid or revoked. A new one is created at
     <https://crm.lightfield.app/crm/settings/api-keys> (admin only) and shown
     once.
   - Anything else → report the status and the `error.type` from the body.
3. If the user named a task ("send email", "upload files"), say whether the
   granted scopes cover it. Scopes are `{object}:{create|update|read}`, plus
   `members:read`.

## Report

One short table: each check, its result, and the single next action for anything
broken. Say which path is ready to use for what: MCP for interactive reads and
writes, an API key for code. If both are unavailable, the fix is the MCP OAuth
flow first; it needs no admin.
