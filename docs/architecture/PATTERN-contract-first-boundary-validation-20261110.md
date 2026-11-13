# Pattern: contract-first validation at boundaries

Status: Proposed. Use when untrusted requests, events or model outputs cross into code with side effects.

## Problem

A parsable payload need not match an expected structure. JSON Schema defines instance validation; OpenAPI describes HTTP interfaces. Validate before committing effects. [JSON Schema](https://json-schema.org/draft/2020-12/json-schema-validation.html); [OpenAPI](https://spec.openapis.org/oas/v3.1.1.html).

## Context

HTTP APIs, queue consumers, attached services and structured model outputs. Proposed policy: one reviewed contract per boundary, with explicit versioning and a durable event identity where retries are possible. [HTTP interface descriptions](https://spec.openapis.org/oas/v3.1.1.html); [Caller-provided request identity](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/).

## Solution

1. Write or retain a versioned boundary contract and fixtures before changing the handler. For HTTP interchange OAS 3.1.1 / JSON Schema 2020-12 is an option, **not a required rewrite**. Existing Zod/Pydantic/golden JSON contracts are accepted when they map explicitly to the boundary, share compatibility fixtures and have named owners/versioning. ModMe already documents Zod/Pydantic parsing of `genui-agent-contract.golden.json`; retain it and `packages/intake-contracts/`. Record an explicit mapping/waiver for any OAS-only criterion. Pin validator behaviour, including coercion, extra fields and whether `format` is asserted. [ModMe contract-parity architecture](https://github.com/Ditto190/modme-ui-01/blob/5dbdc39f8a0012ea4b05dfa20852eec165ec5b60/docs/codebase/ARCHITECTURE.md#L53); [Zod parse/safeParse](https://zod.dev/basics); [Pydantic validation](https://docs.pydantic.dev/latest/concepts/models/).
   The sources below describe an available interchange format, not a requirement to replace the accepted runtime schemas. [OAS schema dialect](https://spec.openapis.org/oas/v3.1.1.html); [Validation and format vocabularies](https://json-schema.org/draft/2020-12/json-schema-validation.html).
2. Reject invalid shape/size before work; check authorisation, business invariants and intent separately. These additional checks are proposed local controls, not properties bestowed by schemas. [Scope of structural validation](https://json-schema.org/draft/2020-12/json-schema-validation.html).
3. **Binding runtime constraint:** validate against the approved endpoint/model and pinned router/validator versions, not another provider's feature table. LiteLLM documents per-model `get_supported_openai_params` / `supports_response_schema` checks and optional client-side JSON Schema validation; supported format, keywords and failure handling need endpoint-specific fixtures. xAI limits here are reference-only, not automatically inherited by LiteLLM routes. No new paid API or endpoint is authorised. [LiteLLM structured-output support](https://docs.litellm.ai/docs/completion/json_mode).
   Validate structured AI output locally too: some accepted xAI schema keywords are best-effort and supported limits matter **only for that endpoint**. Do not assume any OpenAPI schema works unchanged as a model-output schema. [Supported subset and limits](https://docs.x.ai/developers/model-capabilities/text/structured-outputs).
4. Persist request identity atomically with the mutation/result. Retrying one event is not permission to repeat its side effect. [Atomic idempotency](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/).

## Trade-offs

More upfront contract/fixture work; schema evolution and duplicate validation can drift. A valid JSON object can still be false, unauthorised or stale. Keep semantic tests separate from structural conformance. [Validation scope](https://json-schema.org/draft/2020-12/json-schema-validation.html); [Model guarantees are conditional](https://docs.x.ai/developers/model-capabilities/text/structured-outputs).

## Official source

Fetched 10 November 2026 AEDT: [OpenAPI](https://spec.openapis.org/oas/v3.1.1.html): “interface description for HTTP APIs”. [xAI](https://docs.x.ai/developers/model-capabilities/text/structured-outputs): “We support a practical subset of JSON Schema.” [AWS](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/): “unique caller-provided client request identifier”.

## Example

Illustrative JSON Schema alternative; not a deployed endpoint or instruction to replace existing Zod/Pydantic/golden JSON. `eventId` names an identity, but uniqueness still needs persistent enforcement.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["schemaVersion", "eventId", "kind"],
  "additionalProperties": false,
  "properties": {
    "schemaVersion": {"const": 1},
    "eventId": {"type": "string", "minLength": 1},
    "kind": {"enum": ["order.requested"]}
  }
}
```

The `$schema` URI is a dialect identifier, not an extra cited claim. See [validation specification](https://json-schema.org/draft/2020-12/json-schema-validation.html).

## Test

Not run — draft. Existing-contract acceptance: both language validators must accept/reject shared golden fixtures consistently, with explicit differences documented; test the actual approved router/model response shape rather than raw xAI limits. No new provider call is authorised. [ModMe contract-parity architecture](https://github.com/Ditto190/modme-ui-01/blob/5dbdc39f8a0012ea4b05dfa20852eec165ec5b60/docs/codebase/ARCHITECTURE.md#L53); [Binding endpoint checks](https://docs.litellm.ai/docs/completion/json_mode). Fixtures: valid event accepted; missing ID, wrong type, unknown version and unexpected property rejected before handler invocation; unauthorised but structurally valid request rejected; duplicate same-intent ID returns recorded result; same ID/different intent rejected; best-effort model constraint violation rejected locally. Assert zero writes for rejected fixtures and exactly one committed write after replay. [Schema test basis](https://json-schema.org/draft/2020-12/json-schema-validation.html); [Replay/intent basis](https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/); [Local validation basis](https://docs.x.ai/developers/model-capabilities/text/structured-outputs).
