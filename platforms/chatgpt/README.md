# ChatGPT and Codex package

This package follows the portable Agent Plugins layout. The archive root must
contain `plugin.json`, `mcp.json`, `skills/`, and `assets/`; keep those paths
unchanged. It intentionally excludes the Grok manifest, compatibility MCP
configuration, and slash commands.

The public submission uses two separate uploads:

- `chatgpt-app-submission.json` imports listing details, tool annotations, and
  test cases into the submission form.
- `dist/lightfield-chatgpt-1.0.0.zip` supplies the portable skills bundle on
  the **Skills** tab.

Build it with:

```sh
./scripts/package-plugin.sh chatgpt
```
