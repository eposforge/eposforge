---
name: role-task-context
summary: Restructures a rough ask into Role/Task/Context/Constraints/Output-Format with mandatory task+context and optional precision fields.
applies-when: The prompt is under-specified and would benefit from explicit task, context, and delivery shape before execution.
slots:
  - name: task
    required: true
    prompt: What is the one-sentence task (imperative verb + deliverable)?
  - name: context
    required: true
    prompt: What facts the agent cannot infer should be included (system, audience, what was tried)?
  - name: role
    required: false
    prompt: What role should the responder take, if perspective materially changes the answer?
  - name: constraints
    required: false
    prompt: What must the answer avoid or not do?
  - name: output-format
    required: false
    prompt: What output format is required (one line)?
---

## Transform shape

Use this exact section order:

1. `Role:` (only if slot provided; omit entirely if empty)
2. `Task:` (required)
3. `Context:` (required)
4. `Constraints:` (only if provided)
5. `Output format:` (only if provided)

Rewrite guidance:

- Keep user terminology.
- Do not add details not found in the raw prompt or slots.
- `constraints` is negative space (what not to do), not a task restatement.
- If `role` is unfilled, do not invent a generic persona.

## Worked example

### Raw prompt

`help me fix flaky tests`

### Elicited slots

- `task` (required): "Diagnose and propose fixes for flaky Jest integration tests in the payments service."
- `context` (required): "Flakes occur in CI on retry 2+, mostly timeout failures around webhook polling. We already increased global timeout to 30s with little effect."
- `role` (optional): "Senior test reliability engineer"
- `constraints` (optional): "Do not suggest increasing global timeout again; avoid replacing integration tests with unit tests."
- `output-format` (optional): "Provide a prioritized action plan with estimated effort per step."

### Refined prompt

```text
Role: Senior test reliability engineer
Task: Diagnose and propose fixes for flaky Jest integration tests in the payments service.
Context: Flakes occur in CI on retry 2+, mostly timeout failures around webhook polling. We already increased global timeout to 30s with little effect.
Constraints: Do not suggest increasing global timeout again; avoid replacing integration tests with unit tests.
Output format: Provide a prioritized action plan with estimated effort per step.
```
