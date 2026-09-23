---
name: lightfield-integration
description: >-
  Design and scaffold a production-ready Lightfield API integration in Python,
  TypeScript, or Go with scoped credentials, definitions, pagination, upserts,
  idempotency, retries, dry-run support, and tests. Use when the user asks to
  build a script, sync, service, or webhook consumer for Lightfield.
---

# Build a Lightfield API integration

Read the `lightfield-api` skill and its `references/sdk-recipes.md` before
writing code. If the language or data flow is unclear, ask what reads, what
writes, and in which direction.

## Confirm the design

Briefly state the endpoints, required API-key scopes, duplicate-prevention
strategy, and trigger. Resolve material ambiguity before implementing.

## Implementation requirements

Match the existing project's package manager, formatter, test runner, config,
and error conventions when project context is available.

1. Read `LIGHTFIELD_API_KEY` from the environment and fail clearly when it is
   absent. Never write or log the key.
2. Validate the key at startup and compare its returned scopes with the
   integration's required scopes.
3. Load definitions for every object type touched and map labels, field keys,
   and select options at runtime. Never hardcode an `opt_...` ID.
4. Implement pagination with `limit=25`, advancing `offset` until a short page.
5. Search by a stable identity before create and update an existing record when
   appropriate.
6. Send a deterministic `Idempotency-Key` on every write and reuse it only for
   retries of the same payload.
7. Configure SDK retry behavior for retryable failures and honor
   `Retry-After`. Do not retry `400`, `401`, `403`, `404`, `415`, or `422`.
8. Branch on typed error codes and parameters, not message text. Do not log
   secrets or complete request bodies.
9. Verify fresh writes through individual retrieve endpoints because lists can
   lag.
10. Include a dry-run mode and meaningful tests of behavior and failure cases.

Add concise usage documentation covering scopes, environment variables, dry
run, normal execution, and safe reruns. Run the project's relevant typecheck,
lint, and tests when execution tools are available. Never run the integration
against live data unless the user explicitly asks; show the dry-run plan first.
