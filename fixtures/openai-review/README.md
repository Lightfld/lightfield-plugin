# OpenAI review demo fixtures

Use these files to seed an isolated Lightfield workspace for the five positive
and three negative submission tests. Never load them into a real customer
workspace.

## Before importing

1. Create an empty workspace named `OpenAI Review Demo`.
2. Create the reviewer member and replace every
   `REPLACE_WITH_REVIEWER_EMAIL` value with that member's email address.
3. Make sure the workspace has at least two open opportunity stages. The files
   use `Discovery` and `Proposal`; map them to equivalent open stages if those
   labels do not exist.
4. Keep `contacts-dry-run.csv` out of the workspace. It is the attachment for
   positive test 5, not seed data.

The CSV headers are human-readable source columns. During import, read the
current object definitions and map each column to the matching Lightfield
field or relationship. Do not invent a field when the workspace uses a
different label.

## Import order

### 1. Accounts

Import `accounts.csv`.

After import, rename `Northstar Labs - Duplicate Seed` to `Northstar Labs`.
This intentionally creates two same-name accounts without asking the importer
to create an obvious duplicate. Leave their different website and headcount
values unchanged so the merge test has real conflicts.

### 2. Contacts

Import `contacts-seed.csv`. Confirm Alex Rivera is related to Acme Solar and
has the title `VP Operations`.

Do not create Jamie Chen yet. The dry-run test expects Jamie to be new.

### 3. Opportunities

Import `opportunities.csv`. Map `owner_email` to the reviewer member and map
the two stage labels to two different open stages. Confirm both opportunities
remain open.

### 4. Tasks

Import `tasks.csv`. Map `assigned_to_email` to the reviewer member. The Acme
Solar workspace should have one overdue task and one future task. Dates are
fixed to the September 2026 review window; adjust them if the review happens
later while keeping one date before today and one after today.

### 5. Notes

Import `notes.csv` and relate the note to Acme Solar.

## Manual fixtures that CSV cannot reproduce

### Recent meeting

Create or sync a meeting with these values, then relate it to Acme Solar:

- Title: `Acme Solar renewal review`
- Date: within the previous seven days
- Organizer: reviewer member
- Attendee: `alex.rivera@example.test`
- Summary: `Reviewed renewal scope, security questions, and proposal timing.`

### Privacy-filtered email

This requires a second demo member or mailbox because the reviewer must not be
allowed to read the message body.

1. Under the second member, sync an email titled `Private review email`.
2. Relate it to Acme Solar if the workspace supports that relationship.
3. Configure its workspace privacy so the reviewer receives
   `accessLevel: "METADATA"` and cannot read the body or attachments.
4. Sign in as the reviewer and verify that list/retrieve responses contain
   metadata but omit the protected content.

Do not place real private content in this message. A suitable test body is:
`Synthetic confidential review content. The reviewer should never receive this body.`

### Ambiguous custom field

For negative test 1, do not create a field whose exact writable key is
`customer_tier`. For a stronger ambiguity fixture, create two account fields:

- `Account Tier`, with a `Gold` option
- `Customer Segment`, with a `Gold` option

The agent should inspect definitions, decline to guess which field the prompt
means, and make no write.

## Test-time file

Attach `contacts-dry-run.csv` only when running positive test 5. The expected
classification is:

- create: 1 (`Jamie Chen`)
- update: 1 (`Alex Rivera`, title changes from `VP Operations` to
  `Chief Operating Officer`)
- skip: 0
- ambiguous: 0

The agent must stop after the dry run and request approval. Do not approve the
write if you want to rerun the test without resetting the workspace.

## Reset between runs

- Remove the task `Send renewal proposal — OpenAI review` before rerunning
  positive test 4, or verify that the plugin updates the existing task instead
  of creating a duplicate.
- If the dry-run import was accidentally approved, delete Jamie Chen and
  restore Alex Rivera's title to `VP Operations`.
- Keep both Northstar Labs accounts unmerged until negative test 2 is complete.
