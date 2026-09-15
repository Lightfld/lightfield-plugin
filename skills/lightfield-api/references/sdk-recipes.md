# SDK and CLI recipes

The clients are generated with Stainless, so the shape is the same everywhere:
one resource per object type (`account`, `contact`, `opportunity`, `task`,
`note`, `meeting`, `email`, `file`, `list`, `member`, `object`, `merge`,
`message`, `channel`, `auth`, `workflowRun`) and methods `create`, `update`,
`retrieve`, `list`, `delete`, `definitions`, `fieldHistory` where the resource
supports them.

Neither SDK reads the API key from the environment on its own, so pass it
explicitly. Package versions are pre-1.0 and the API is in beta; pin a version.

## Python (`pip install lightfield`)

```python
import os
import uuid

from lightfield import Lightfield

client = Lightfield(api_key=os.environ["LIGHTFIELD_API_KEY"])

# Fail fast on a bad key or missing scope.
auth = client.auth.validate()
print(auth.subject_type, auth.scopes)

# Definitions: the only correct source of field keys and option IDs.
definitions = client.account.definitions()

# Page through a filtered list. `limit` maxes out at 25.
def iter_accounts(**filters):
    offset = 0
    while True:
        page = client.account.list(limit=25, offset=offset, extra_query=filters)
        yield from page.data
        if len(page.data) < 25:
            return
        offset += 25

existing = list(iter_accounts(**{"$name[equal]": "Acme Corp"}))

# Upsert, with a stable idempotency key so a retry cannot double-create.
if existing:
    account = client.account.update(
        existing[0].id,
        fields={"$website": ["https://acme.com"]},
        extra_headers={"Idempotency-Key": f"acme-update-{existing[0].id}"},
    )
else:
    account = client.account.create(
        fields={"$name": "Acme Corp", "$website": ["https://acme.com"]},
        extra_headers={"Idempotency-Key": f"acme-create-{uuid.uuid4()}"},
    )

# List results come from a lagging index: read back to confirm.
print(client.account.retrieve(account.id))
```

Filters are not typed parameters, so they go through `extra_query` with the
`key[operator]` string as the key. `extra_headers`, `extra_query` and
`extra_body` exist on every method. `AsyncLightfield` is the same API with
`await`.

Errors are typed: `AuthenticationError` (401), `PermissionDeniedError` (403),
`BadRequestError` (400), `NotFoundError` (404), `UnprocessableEntityError`
(422), `RateLimitError` (429), `InternalServerError` (5xx),
`APIConnectionError`.

```python
from lightfield import BadRequestError

try:
    client.account.create(fields={"bogus": 1})
except BadRequestError as err:
    print(err.status_code)  # 400
    print(err.message)      # "Unrecognized field 'bogus' for 'accounts'."
```

## TypeScript (`npm install lightfield`)

```ts
import Lightfield from 'lightfield';
import { randomUUID } from 'node:crypto';

const apiKey = process.env.LIGHTFIELD_API_KEY;
if (!apiKey) throw new Error('LIGHTFIELD_API_KEY is not set');

const client = new Lightfield({ apiKey, maxRetries: 3 });

const auth = await client.auth.validate();

async function* iterAccounts(filters: Record<string, string> = {}) {
  for (let offset = 0; ; offset += 25) {
    const page = await client.account.list({ limit: 25, offset }, { query: filters });
    yield* page.data;
    if (page.data.length < 25) return;
  }
}

const matches = [];
for await (const account of iterAccounts({ '$name[equal]': 'Acme Corp' })) {
  matches.push(account);
}

const created = await client.account.create(
  {
    fields: { $name: 'Acme Corp', $website: ['https://acme.com'] },
    relationships: { $owner: 'mem_abc123' },
  },
  { headers: { 'Idempotency-Key': randomUUID() } },
);

const fresh = await client.account.retrieve(created.id);
```

The second argument to every method is request options: `headers`, `query`,
`body`, `timeout`, `maxRetries`. Errors subclass `Lightfield.APIError` with
`status`, `name` and `headers`; the names match the Python list above except
that 422 is `UnprocessableEntityError`. The client sends
`Lightfield-Version: 2026-03-01` for you.

## Go (`go get -u github.com/Lightfld/lightfield-go`)

```go
package main

import (
	"context"
	"errors"
	"fmt"
	"os"

	"github.com/Lightfld/lightfield-go"
	"github.com/Lightfld/lightfield-go/option"
)

func main() {
	client := githubcomlightfldlightfieldgo.NewClient(
		option.WithAPIKey(os.Getenv("LIGHTFIELD_API_KEY")),
	)

	accounts, err := client.Account.List(context.TODO(), githubcomlightfldlightfieldgo.AccountListParams{
		Limit: githubcomlightfldlightfieldgo.Int(25),
	})
	if err != nil {
		var apierr *githubcomlightfldlightfieldgo.Error
		if errors.As(err, &apierr) {
			fmt.Println(apierr.StatusCode, apierr.Message)
		}
		panic(err)
	}
	fmt.Printf("%+v\n", accounts)
}
```

The generated package name is `githubcomlightfldlightfieldgo`: that is not a
typo, it is how the module identifier is derived.

## CLI (`brew install Lightfld/lightfield/lightfield`)

```bash
export LIGHTFIELD_API_KEY="sk_lf_..."

lightfield account list --limit 25 --format json
lightfield account create --fields '{"$name": "Acme Corp", "$website": ["https://acme.com"]}'
lightfield account list --limit 1 --debug          # full HTTP request and response
```

Shape is `lightfield <resource> <command> [flags]`. Global flags: `--api-key`
(overrides the env var), `--base-url`, `--format`
(`auto|json|jsonl|pretty|raw|yaml`), `--debug`.

**The CLI cannot filter lists.** Anything needing `$field[operator]=value` has
to go through an SDK or plain HTTP. On macOS the binary is not yet notarized; if
Gatekeeper blocks it, clear the quarantine attribute or allow it in System
Settings → Privacy & Security.

Go installs work too: `go install github.com/Lightfld/lightfield-cli/cmd/lightfield@latest`.

## curl

```bash
curl "https://api.lightfield.app/v1/accounts?limit=25" \
  -H "Authorization: Bearer $LIGHTFIELD_API_KEY" \
  -H "Lightfield-Version: 2026-03-01"

curl https://api.lightfield.app/v1/accounts \
  -X POST \
  -H "Authorization: Bearer $LIGHTFIELD_API_KEY" \
  -H "Lightfield-Version: 2026-03-01" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"fields": {"$name": "Acme Corp"}}'

# Filters need -G --data-urlencode; $ and [] must be single-quoted.
curl https://api.lightfield.app/v1/contacts -G \
  -H "Authorization: Bearer $LIGHTFIELD_API_KEY" \
  -H "Lightfield-Version: 2026-03-01" \
  --data-urlencode '$email[contains]=alex@customer.com'
```

Never paste a key inline in a command you write into a file or a log. Read it
from the environment.
