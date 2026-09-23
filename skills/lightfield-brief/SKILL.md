---
name: lightfield-brief
description: >-
  Build a read-only briefing on a Lightfield account or opportunity, including
  its owner, stage, contacts, open work, and recent activity. Use when the user
  asks for an account brief, deal brief, meeting prep, renewal summary, or the
  current state of a named account or opportunity.
---

# Build a Lightfield briefing

Use the Lightfield MCP tools. This workflow is read-only: do not create,
update, merge, or send anything.

If the user did not identify an account or opportunity, ask which one to brief.

## Find the record

An `acc_...` or `opp_...` ID goes directly to `read_from_lightfield` at
`/v1/accounts/{id}` or `/v1/opportunities/{id}`.

For a name, search `/v1/accounts?$name[equal]={name}&limit=5`, then try
`$name[startsWith]` if there is no exact match. URL-encode filter values. If
several plausible records match, list their names and `httpLink` values and ask
the user to choose. Do not guess or brief an approximate match.

## Gather

Read the account, opportunity, and task definitions once. Use their actual
relationship slugs and select option labels because they are organization
specific. Then retrieve, with `limit=25` per list call:

- the target record through its individual retrieve endpoint;
- open opportunities for the account, including stage, amount, close date, and
  owner;
- contacts for the account, including name, title, and email;
- open tasks, including status, due date, and assignee; and
- recent notes and meetings.

Resolve owner and assignee IDs through `/v1/members/{id}`. Translate every
`opt_...` value with the definitions response. Skip a section when the needed
relationship does not exist instead of inventing a filter.

## Report

Lead with one sentence covering owner, stage, value, and most recent activity.
Then report open work, people, recent activity, and important data gaps. Put
overdue tasks first and sort recent activity newest first. End with the target
record's `httpLink`.

Only report supported facts. Say that no meetings were returned instead of
inventing activity. If privacy filtering returns metadata-only access, explain
that the content is not visible rather than describing it as empty.
