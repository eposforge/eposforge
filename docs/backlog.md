# Feature Backlog

## LLM Cost Preflight Library

**Area:** Shared library / installed-component template

Provide a thin helper (e.g. `preflight_budget(messages, model, max_usd)`) that estimates input token count, projects total cost against a caller-supplied per-run budget, and aborts with a clear error before any API call is made if the estimate exceeds the threshold.

**Motivation:** Any LLM-driven component (spec graph rebuild, future extractors, agents) can incur large unexpected costs. Provider-side spend caps are account-wide and react slowly; a per-run preflight gives component authors a fine-grained, proactive kill switch.

**Design notes:**
- Ship as a shared utility so any installed component can import it.
- Wire it into the installed-component template by default so new components inherit the guard.
- Keep it opt-in at the framework level (no mandatory chokepoint) until there is broader demand for enforcement.
- Consider exposing a dry-run flag on build scripts (`--dry-run`) that runs the preflight and prints the cost estimate without executing.
