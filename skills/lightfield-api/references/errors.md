# Errors

Source: <https://docs.lightfield.app/using-the-api/errors>

Every error response is wrapped:

```json
{
  "error": {
    "type": "bad_request",
    "message": "Unrecognized field 'bogus' for 'accounts'.",
    "code": "unknown_field",
    "param": "fields.bogus"
  }
}
```

`type` is always present. `code` and `param` appear on `400` and `422` and are
what you branch on: `message` is for humans and its wording is not a contract.

## Status codes

| Status | `type` | Cause | Retry? |
| --- | --- | --- | --- |
| 400 | `bad_request` | Wrong field, relationship, or parameter. Read `code` and `param`. | No: fix the request |
| 401 | `unauthorized` | Missing or invalid key. | No |
| 403 | `forbidden` | Valid key, missing scope. | No |
| 404 | `not_found` | Resource or entity type does not exist, or was deleted. | No |
| 409 | `conflict` | Duplicate definition, locked resource, concurrent update, or an idempotency key still in flight. | Only for `idempotency_conflict`, after a wait |
| 415 | `unsupported_media_type` | Body is not JSON: add `Content-Type: application/json`. | No |
| 422 | `unprocessable_content` | Valid JSON, failed business validation. | No |
| 429 | `too_many_requests` | Rate limited. Honour `Retry-After`. | Yes, with backoff |
| 500 | `internal_server_error` | Server error. | Yes, with backoff |
| 503 | `service_unavailable` | Temporarily unavailable. | Yes, with backoff |

## Codes on 400 and 422

| Code | Meaning and fix |
| --- | --- |
| `unknown_field` | Field not defined for this object type. Re-read definitions; `param` names it. |
| `unknown_relationship` | Same, for a relationship. |
| `referenced_resource_missing` | A field references an ID that does not exist. Check the ID prefix first. |
| `relationship_entity_missing` | An ID in a relationship does not exist. |
| `relationship_entity_inactive` | An ID refers to a deleted or inactive entity. |
| `relationship_write_limit_exceeded` | More than 25 IDs referenced or 25 links changed in one request. Split it. |
| `invalid_type` | Wrong value type for the field: e.g. a string where an object belongs. |
| `parameter_missing` | A required parameter is absent; `param` names it. |
| `invalid_configuration` | Invalid field or relationship configuration. |
| `idempotency_key_too_long` | `Idempotency-Key` exceeds 255 characters. |
| `version_header` | `Lightfield-Version` missing or invalid. |
| `ambiguous_stage_label` | A stage label exists in more than one pipeline. |
| `stage_unresolved_in_pipeline` | The stage does not identify one active stage in the selected pipeline. |
| `unknown_pipeline` | The pipeline does not resolve to an active one for this object type. |

## Pipeline and stage errors

These carry extra detail inside `error`:

- `ambiguous_stage_label`: `400` when filtering, `422` when writing.
  `candidates` lists `{ stageOptionId, stageLabel, pipelineId, pipelineName }`.
  Pick an exact option ID or supply the pipeline. Do **not** silently take the
  first candidate.
- `stage_unresolved_in_pipeline`: `422`. `pipelineId` is the selected pipeline;
  `candidates` shows the possible stages and their owners.
- `unknown_pipeline`: `400` filtering, `422` writing. `activePipelineIds` lists
  what is available.

`truncated: true` means the candidate list is capped, so refresh definitions for
the full picture. An empty candidate list usually means the label does not
exist at all.

If `$pipeline` is absent from definitions, writing it returns `400`
`unknown_field`. That is a capability signal, not a transient failure: pipelines
being visible in the Lightfield UI does not mean they are enabled in the API for
that org and object type.

## Handling pattern

```python
from lightfield import BadRequestError, RateLimitError, UnprocessableEntityError

try:
    client.opportunity.update(opp_id, fields={"$stage": stage_label})
except UnprocessableEntityError as err:
    body = err.body or {}
    error = body.get("error", {})
    if error.get("code") == "ambiguous_stage_label":
        # choose among error["candidates"] by pipelineId, then retry
        ...
    else:
        raise
except RateLimitError:
    # SDK already retried; treat as sustained pressure and slow the worker down
    raise
```

Log `type`, `code`, `param` and the request ID. Never log the API key, and
remember that SDK `debug` logging prints request and response bodies.
