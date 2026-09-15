---
description: Build a briefing on a Lightfield account or opportunity: owner, stage, people, open work, and recent activity.
argument-hint: "<account or opportunity name, or acc_/opp_ ID>"
---

Assemble a briefing on the account or opportunity named in `$ARGUMENTS` using
the `lightfield` MCP tools. Read-only: do not create, update, or merge anything.

If `$ARGUMENTS` is empty, ask what to brief on before doing anything else.

## Find the record

An `acc_…` or `opp_…` ID goes straight to
`read_from_lightfield` on `/v1/accounts/{id}` or `/v1/opportunities/{id}`.

Otherwise search: `/v1/accounts?$name[equal]={name}&limit=5`, falling back to
`$name[startsWith]={name}` when nothing comes back. If several plausible records
match, list them with their `httpLink` and ask which one. Do not guess. If none
match, say so and stop rather than briefing on an approximate match.

## Gather

Read `/v1/accounts/definitions`, `/v1/opportunities/definitions` and
`/v1/tasks/definitions` once, and take the relationship slugs and select option
labels from there, since they are org-specific and must not be guessed. Then, with
`limit=25` per call:

- The record itself, via its Retrieve endpoint (fresher than any list).
- Open opportunities on the account: stage, amount, close date, owner.
- Contacts on the account: name, title, email.
- Open tasks: name, status, due date, assignee.
- Recent notes and meetings.

Resolve every owner and assignee ID through `/v1/members/{id}` so the brief
names people, and map every `opt_…` to its label from definitions. Skip a
section whose relationship slug does not exist for the org rather than inventing
a filter.

## Report

Lead with the one-line state: who owns it, what stage it is in, what it is
worth, when it was last touched. Then:

- **Open work**: tasks and their due dates, oldest first, flagging anything overdue.
- **People**: contacts with titles, marking the primary point of contact if the data says who it is.
- **Recent activity**: the last few notes and meetings, most recent first.
- **Gaps**: empty fields that matter for a deal of this shape (no close date, no owner, no next step, stage untouched for a long time).

End with the record's `httpLink`. Keep it to what the data supports: say "no
meetings recorded" rather than filling the section, and if a read was blocked by
privacy filtering (`accessLevel: "METADATA"`), say the content was not visible
instead of reporting it as absent.
