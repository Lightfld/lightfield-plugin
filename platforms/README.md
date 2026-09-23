# Platform packaging definitions

Each child directory declares one distributable plugin package in
`package-spec.json`:

- `artifactName`: archive name without the version or `.zip` suffix.
- `versionManifest`: repository-relative JSON manifest containing the
  package's top-level `version` field.
- `include`: repository-relative files and directories copied to the archive
  root.

Run `./scripts/package-plugin.sh <platform>` from anywhere in the repository.
Artifacts are written to `dist/` and are not committed. The package specs are
distribution metadata only; host-discovered manifests remain in their required
locations at the repository root.
