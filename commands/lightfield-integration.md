---
description: Scaffold a Lightfield API integration: client, definitions cache, pagination, upsert with idempotency, and backoff.
argument-hint: "<python|typescript|go> <what it should do>"
---

Scaffold a working integration against the Lightfield API for the task in
`$ARGUMENTS`. Read the `lightfield-api` skill first, including
`references/sdk-recipes.md`.

If the language is not given, ask. If the task is vague ("sync our data"), ask
what reads and what writes, and in which direction, before writing code: the
shape of the sync determines most of the design.

## Confirm the design first

State in three or four lines: which endpoints it touches, which scopes the key
needs, whether it creates records (and how duplicates are prevented), and how it
is triggered. Get agreement, then write.

## What the scaffold must contain

Match the surrounding project's conventions: its package manager, formatter,
test runner, config layout, error handling. Do not import a new framework for
the sake of it.

1. **Client construction** reading `LIGHTFIELD_API_KEY` from the environment,
   failing with a clear message when it is unset. No key literal anywhere, and
   nothing key-shaped in a committed file.
2. **A startup check** calling `GET /v1/auth/validate`, comparing the returned
   `scopes` against what the integration actually needs, and refusing to start
   on a mismatch. This turns a confusing mid-run `403` into a startup error.
3. **A definitions load** for each object type touched, mapping labels to field
   keys and select option IDs at runtime. No hardcoded `opt_…`: an option ID is
   valid in one organization and wrong in the next.
4. **Pagination** as a generator or iterator: `limit=25`, `offset` advancing,
   stopping on a short page. Never assume `totalCount` holds still.
5. **Upsert, not blind create.** Query the dedupe field, then create or update.
   A sync without this manufactures duplicates on its second run.
6. **An `Idempotency-Key` on every write**, derived deterministically from the
   source record so that a retried run reuses the same key. Reuse the key on
   retry; never reuse it for a different payload.
7. **Rate-limit handling.** 25 requests per second per category. Configure the
   SDK's retries (`max_retries` / `maxRetries`) rather than hand-rolling a loop;
   honour `Retry-After` on anything you do retry; never retry `400`, `401`,
   `403`, `404`, `415` or `422`.
8. **Typed error handling** that branches on `error.code` and `error.param`, not
   on message text, and logs neither the key nor whole request bodies.
9. **Read-back verification** through the Retrieve endpoint wherever the next
   step depends on a value just written: list endpoints lag.
10. **A dry-run mode** that logs the writes it would make without sending them.
    Anything that writes to a CRM should be runnable safely once first.

## Finish

Include a short README section: required scopes, env vars, how to run the dry
run, and what a re-run does. Then run whatever the project uses to check it
(typecheck, lint, tests) and report the result. Do not run the integration
against real data unless the user asks; if they do, run the dry run first and
show the plan.
