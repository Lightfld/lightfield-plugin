# Multi-platform plugin architecture

This repository has one shared Lightfield capability module and thin adapters
for each agent platform. The adapter boundary is the platform's required
manifest and presentation format; skills, references, the MCP endpoint, and
brand assets stay shared wherever the host formats permit it.

## Repository layers

| Layer | Paths | Responsibility |
| --- | --- | --- |
| Shared capabilities | `skills/`, `assets/`, `LICENSE` | Lightfield workflows, reference material, source branding, and platform-ready exports |
| ChatGPT and Codex adapter | `plugin.json`, `mcp.json`, `skills/*/agents/openai.yaml` | Portable Agent Plugins identity, MCP transport, and OpenAI presentation metadata |
| Grok adapter | `.grok-plugin/plugin.json`, `.mcp.json`, `commands/` | xAI manifest, MCP transport, and Grok slash commands |
| Distribution adapters | `platforms/<platform>/package-spec.json` | Files and version source for each package |
| Packaging implementation | `scripts/package-plugin.sh` | Builds any declared platform without platform-specific logic |

The host-facing files intentionally remain at the repository root. OpenAI
requires `plugin.json`, `mcp.json`, `skills/`, and `assets/` at the package
root, while Grok expects `.grok-plugin/plugin.json` and `.mcp.json`. Moving
either set beneath `platforms/` would make the repository look tidier but break
host discovery.

## Adapter seam

Platform adapters may describe or expose the shared capabilities, but they
must not fork the underlying Lightfield workflow unless a platform genuinely
requires different behavior. A workflow change should normally land in
`skills/` once and flow into every package.

OpenAI-specific skill metadata belongs in `skills/<skill>/agents/openai.yaml`.
Grok-specific interactive entry points belong in `commands/`. Shared prose and
API guidance belong in the relevant `SKILL.md` or `references/` directory.

## Add another platform

1. Add only the manifest or presentation files required by the new host.
2. Reuse `skills/` and `assets/`; add narrowly scoped host metadata alongside
   the shared content only when the host requires it.
3. Create `platforms/<platform>/package-spec.json` and a README describing the
   host-specific installation and validation process.
4. Run `./scripts/package-plugin.sh <platform>` and inspect the archive.

The packaging script validates paths, reads the version from the declared JSON
manifest, stages only the allowlisted files, normalizes timestamps for
reproducible output, and tests the resulting ZIP. A new platform therefore
adds data and documentation, not platform branches to the packaging
implementation.
