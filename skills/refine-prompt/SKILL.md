---
name: refine-prompt
description: Technique-driven prompt transformation for under-specified asks. Discovers techniques from data files, elicits missing required slots in one batch, rewrites with strict traceability, and gates submission behind explicit yes/no confirmation.
---

Transforms a rough user prompt into a clearer, execution-ready prompt without
inventing requirements. This skill is opt-in and interactive: it selects a
technique, gathers missing required slots, rewrites, then requires explicit
confirmation before any submission action.

## Inputs

- Raw prompt from the user
- Optional user-selected technique name

## Technique catalog (runtime discovery)

Read all `techniques/*.md` files at invocation time. Do not hardcode a
technique list in this file.

Each technique file must provide frontmatter with:

- `name`
- `summary`
- `applies-when`
- `slots` (with required/optional markers)

If a technique is explicitly requested, use it if available.
If no technique is requested:

1. If exactly one technique clearly applies, select it and state why.
2. If multiple techniques could apply (or confidence is low), ask the user to
   choose from the discovered techniques.

## Slot elicitation contract

For the selected technique:

1. Determine which required slots are missing.
2. Ask for **all missing required slots in one batch** (single prompt containing
   all required slot questions).
3. Optional slots may be asked only after required slots are satisfied, and may
   be skipped by the user.

Do not rewrite until all required slots are present.

## Rewrite contract (no fabrication)

Build the refined prompt from:

- the original prompt text
- user-provided slot answers
- deterministic restructuring implied by the selected technique

Rules:

- Restructure; do not editorialize.
- Preserve user terminology and intent.
- Every sentence in the refined prompt must trace to either the original prompt
  or a provided slot answer.
- Do not add fabricated requirements, examples, assumptions, or persona text.
- Keep the refined result as short as the technique allows.

## Output + submit confirmation gate

Always show the refined prompt in a fenced markdown block first.

Then ask an explicit confirmation question:

- `yes` → submit/use the refined prompt
- `no` → do not submit anything; return control without sending the raw prompt
  or refined prompt onward

This gate is mandatory in both directions. Never act on the raw prompt and
never auto-submit without explicit yes.

## Outputs

- Selected technique (or user choice request)
- Batched required-slot elicitation prompt (if needed)
- Refined prompt in fenced block
- Explicit yes/no confirmation handling
