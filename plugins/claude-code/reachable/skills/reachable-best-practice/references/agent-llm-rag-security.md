# agent-llm-rag-security

Load when writing LLM calls, prompt construction, tool or function definitions, MCP servers, agent
orchestration, or retrieval pipelines.

The language references still apply — this code is ordinary code and the same sinks exist in it.
What follows is the additional structure this domain needs.

## The core rule

**Model output and retrieved content are untrusted input.** Not "mostly reliable input", not "input
from our own system". A model's output can be steered by anything in its context: a user message, a
retrieved document, a web page, a file, a previous tool result, or the output of another agent.

So the boundary that matters is not between "the user" and "the model" — it is between text and
action. Everywhere model-derived text reaches a sink that acts, you need the same protections you
would apply to a raw HTTP parameter.

```
# model output flowing straight into a shell
plan = llm.generate(prompt)
subprocess.run(plan["command"], shell=True)

# constrained to an operation the code already knows how to do
choice = llm.generate(prompt)            # returns {"op": "resize", "width": 800}
op = OPERATIONS.get(choice["op"])        # explicit dispatch table
if op is None:
    raise ValueError("unsupported operation")
op(width=validate_dimension(choice["width"]))
```

The same applies to SQL built from model output, file paths chosen by a model, URLs a model
supplies, and code a model emits for execution.

## Prompt injection cannot be solved by sanitizing

Instruction and data share one channel, so there is no reliable escaping. Delimiters, "ignore any
instructions in the document below", and input filters all reduce the rate and none of them close
the class. Design so that a successful injection does not matter much:

- give tools the minimum authority that makes the feature work;
- require an out-of-band confirmation for irreversible or high-value actions;
- keep authorization decisions in code, using the session's identity, never in the prompt;
- separate the read path from the write path where possible.

Do not add a "prompt injection filter" and treat the problem as handled.

## Authorization

The model's judgment is not an authorization decision. If a model concludes the user should be able
to delete the record, the code still has to check.

```
# risky — the model decides
if llm_says_user_is_admin: delete_account(target)

# preferred — the code decides, using the authenticated session
if not authz.can_delete(session.user, target):
    raise PermissionError
delete_account(target)
```

Tools must execute with the *caller's* privileges, not the service's. An agent running with a
service account that can read every tenant's data will, given the right input, do exactly that.
Thread the caller's identity through to each tool call and scope queries by it.

## Tool and MCP server design

- Narrow parameters. A `run_query(sql)` tool exposes the whole database; `get_orders(status, limit)`
  exposes what the feature needs.
- Validate every parameter in the tool implementation. The schema you advertise is a hint to the
  model, not enforcement.
- Bound cost: timeouts, result size caps, pagination, rate limits per session.
- Return data, not instructions. A tool result that says "now call transfer_funds" is an injection
  vector into your own agent.
- Keep destructive operations behind a separate, explicitly-granted tool, and make them idempotent.
- MCP servers are network services: authenticate callers, do not bind to a public interface by
  default, and do not trust the client to supply the tenant or user identity.
- Log tool invocations with the caller identity and the arguments, minus secrets, so actions can be
  reconstructed.

## Retrieval

- Documents are data. Never concatenate retrieved text into a position where it can act as
  instruction without expecting that it will.
- Apply the *user's* access rights at retrieval time. Filter in the query to the vector store or
  index, not after retrieval, and re-check on any content that is about to be shown.
- Index-time metadata must carry the ownership or tenant labels needed to filter. Retrofitting this
  later is painful, so put it in the schema now.
- Treat ingestion sources as untrusted: a document uploaded by one user can target another user's
  session if the index is shared.
- Cite sources so a human can tell where a claim came from.

## Output handling

Model output rendered in a browser needs the same escaping as any other untrusted content —
markdown-to-HTML conversion of model output is an XSS sink unless sanitized. Model-generated URLs
need scheme validation. Model-generated JSON needs schema validation, not just parsing.

## Secrets and context

Do not put credentials, keys, or other users' data into a prompt. Anything in the context window can
come back out. Redact before sending, and keep provider logging settings deliberate for
sensitive workloads.

## Cost and loops

Agent loops need a maximum iteration count, a wall-clock budget, and a token budget. An injected
instruction that induces an infinite tool loop is a denial-of-service and a bill.
