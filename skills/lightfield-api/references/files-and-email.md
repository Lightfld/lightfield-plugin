# Files, attachments, meetings, and email

Sources: <https://docs.lightfield.app/using-the-api/file-uploads>,
<https://docs.lightfield.app/using-the-api/emails-and-attachments>

## File upload lifecycle

Three steps. The middle one does **not** go to the Lightfield API.

**1. Create the session**: `POST /v1/files` with `purpose`, `filename`,
`mimeType`, `sizeBytes`. Requires `files:create`.

| `purpose` | For |
| --- | --- |
| `meeting_transcript` | A transcript to attach to a meeting. |
| `knowledge_user` | A file in the caller's personal uploads area, readable by the chat agent. |
| `knowledge_workspace` | The organization's shared uploads area. Org admin only. |
| `email_attachment` | An attachment for a send or draft. 20 MiB per file; Gmail caps 20 MiB per message, Outlook 3 MiB per attachment. |

The response carries `id` (`fil_…`), `status: "PENDING"`, `uploadUrl`,
`uploadHeaders`, and `expiresAt`. Each purpose has its own MIME and size limits.

**2. `PUT` the bytes to `uploadUrl`** using exactly the headers in
`uploadHeaders` and no Lightfield auth headers. Knowledge uploads include
`if-none-match: *`; stripping it invalidates the signature and the PUT fails.
Expect `200`, `201`, or `204` depending on the storage backend.

**3. Complete**: `POST /v1/files/{id}/complete`, body `{}`, or
`{"md5": "…"}` if you computed a checksum while uploading. A file is only usable
once completed. `POST /v1/files/{id}/cancel` abandons a session.

Read back with `GET /v1/files/{id}` and get a signed download URL from
`GET /v1/files/{id}/url` (`files:read`). Signed URLs expire, so fetch one when you
are about to use it.

**Knowledge uploads never overwrite.** `POST /v1/files` stamps the filename with
an epoch-millisecond suffix before the extension (`playbook.md` →
`playbook_1713045600000.md`; `archive.tar.gz` → `archive.tar_1713045600000.gz`)
and the presigned PUT is conditional, so a collision returns `412 Precondition
Failed`. There is no overwrite flag. Re-upload and the new name lands beside
the old one. Always use the `filename` from the response, not the one you sent.

## Meeting transcripts

Upload with `purpose: "meeting_transcript"`, complete the file, then attach it
through the meeting's `$transcript` relationship. To read one back: retrieve the
meeting, follow `$transcript` to its `fil_…`, then
`GET /v1/files/{id}/url`. See
<https://docs.lightfield.app/using-the-api/uploading-meeting-transcripts> and
<https://docs.lightfield.app/using-the-api/retrieving-meeting-transcripts>.

## Sending email

`POST /v1/emails/send` needs `emails:create`, a user-backed key (or a workspace
key whose creator resolves to a user), and a connected Google or Microsoft
mailbox for `from`.

```json
{
  "from": "sam@example.com",
  "to": ["alex@customer.com"],
  "subject": "Renewal next steps",
  "messageBody": { "contentType": "TEXT", "content": "Hi Alex, …" },
  "attachments": ["fil_abc123"]
}
```

| Field | Send | Notes |
| --- | --- | --- |
| `from` | required | Bare address of a connected mailbox owned by the key's user. |
| `to` | required | Array of bare addresses. |
| `cc`, `bcc` | optional | Arrays of bare addresses. |
| `subject` | required | Must be non-empty on a send. |
| `messageBody.contentType` | optional | `HTML` (default) or `TEXT`. |
| `messageBody.content` | required | Must be non-empty on a send. |
| `attachments` | optional | Completed file IDs. Maximum 5. |

Up to 500 addresses per list and 500 combined across `to`, `cc` and `bcc`. A
successful send returns `{ "sentAt": … }`.

`POST /v1/emails/draft` takes the same body, but only `from` is required: with
at least one of `to`, `cc`, `bcc`, `subject`, `messageBody.content` or
`attachments`, otherwise `400`. It returns `{ "draftedAt": … }`.

Sends and drafts create **new** messages only; replies and forwards are not
supported yet. Send an `Idempotency-Key`: retry protection on the remote
provider is best effort, so a blind retry without one risks a duplicate send.

**Confirm before sending.** Show the user the exact recipients, subject and body
and get an explicit yes. When in doubt create a draft and let the user press
send.

## Reading email

`GET /v1/emails/{id}` returns the body when the caller has full access.
`GET /v1/emails` omits `fields.$body` from rows, so retrieve individually for
bodies. Both are privacy-filtered: with metadata-only access `$subject` and
`$body` are `null`, `relationships.$attachment` is omitted, and `accessLevel` is
`METADATA` instead of `FULL`. Branch on `accessLevel` rather than treating a
null body as an empty email. Messages and channels behave the same way; a
private channel the caller cannot see looks exactly like one that does not
exist.
