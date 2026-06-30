# EF-049 — AI Question Method elicitor + "when-needed" prompt-quality gate

Status: plan (open) · Date: 2026-06-18 · Effort: L · Theme: orchestrator

## Vision

A capability that accepts any prompt and, *when the prompt is under-specified*,
draws a sharper prompt out of the author by partnering with them — rather than
silently rewriting (which only pads or mirrors the author's words back). The
value is **elicitation of intent the author hasn't articulated**, not text
expansion.

Two separable parts:

- **Part A — the method (how):** an elicitor that applies the AI Question
  Method (below). Realized either as a *technique* under the existing
  `refine-prompt` skill (EF-031) or, if its interactive/iterative nature exceeds
  EF-031's one-shot batch-slot + single-confirm contract, as a distinct
  interactive elicitation skill modeled on `skills/milestone-elicitation/`.
- **Part B — the gate (when):** a prompt intent-clarity check in the
  Orchestrator (C4, née Router — naming per EF-026) that triggers Part A only
  when a prompt falls below bar, and lets sharp prompts pass straight through.
  This is the piece EF-031 deliberately deferred: EF-031 rejected an *always-on
  interceptor* because no cross-CLI hook exists and a universal gate taxes every
  prompt. The Orchestrator is a single server-side surface with an existing
  prompt-gating hook (see EF-034), so a gate is feasible *there* even though it
  was not across heterogeneous agent CLIs.

## The method (distilled — durable capture, so implementation does not depend on the source)

Mental model shift: treat a frontier model as a **senior partner**, not a junior
one. 2025-era prompting specified tasks tightly for a junior; 2026-era heavy
knowledge work is better served by a sharp *series of questions* that let a
senior partner explore and push back.

Three principles the elicitor should surface and fill:

1. **Flashlight intent.** The prompt must convey the author's *perspective/thesis*
   — the center of the beam (the bullseye to target) and the edges (bounds, and
   explicit exclusions: "we spent 15 min on X; leave X out"). Failure modes:
   over-open-ended ("tell me about the Mona Lisa") or over-closed. The art is a
   clear center *plus* room to explore.
2. **What "good" looks like.** Ask questions that make the model contend with the
   target outcome's quality bar — the implicit standard that is hard to write as
   an eval (e.g. "what makes a good PR/FAQ"). Pose multiple open-ended quality
   questions and let the model synthesize across them, rather than dictating the
   answer.
3. **Wrestle with data + opinions.** Name the concrete artifacts/data the model
   must engage (so it doesn't tunnel into one file) *and* the author's opinions
   that lie across that data — inviting the model to examine the data and push
   back as a senior partner, not mirror the opinion.

Anti-goals baked in (consistent with EF-031): restructure/elicit, never
editorialize; every line of the refined prompt traces to the original prompt or
the author's answers (no fabricated requirements); the model must be free to
disagree with the author's thesis.

## Relationship to existing items

- **EF-031 (refine-prompt skill)** — Part A is most likely a new technique file
  under `skills/refine-prompt/techniques/` (technique discovery is already
  run-time there). Tension to resolve: EF-031's contract is *one-shot* (batch all
  missing slots, rewrite once, single yes/no). The AI Question Method is
  *iterative partnership* — it may need multiple elicitation turns and so strain
  that contract. Decide whether it fits as a technique or needs a sibling skill.
- **EF-032 (per-surface skill install adapters)** — distribution of Part A rides
  on EF-032; no new distribution work here.
- **EF-013 (Orchestrator v0)** — Part B's gate is a stage in the Orchestrator's
  prompt path; its write-side manifest is EF-034.
- **EF-026** — use "Orchestrator" (not "Router") in any new docs.
- **EF-011 / EF-012** — describe any adopter-side install at the adoption layer,
  not as framework-internal paths.

## Open design questions (carried on the backlog item)

1. **Trigger model.** Automatic (Orchestrator gates every prompt) vs. opt-in
   (author invokes the skill, à la EF-031) vs. adaptive (memory-primed nudge:
   the model reminds the author when their prompts stop carrying intent).
2. **Gate signal.** What decides "needs sharpening"? Length/specificity
   heuristics, an LLM-judge scoring against the three principles, or a structured
   check (does the prompt state a thesis? name artifacts? bound scope?).
3. **Scope of target.** Implementer-facing only (an Orchestrator-internal stage)
   vs. a general capability any Dev Product (C3) can call (a published skill with
   a contract).
4. **Method-vs-framework fit.** Does the AI Question Method fit EF-031's one-shot
   slot+confirm contract, or does its iterative partnership nature require a
   distinct interactive elicitation skill?

## Proposed sequencing (architect recommendation, 2026-06-18)

Prototype **Part A first as an opt-in skill/technique** (modeled on
`milestone-elicitation` + EF-031), prove elicitation quality, then add **Part B's
gate**. A great gate triggering a mediocre interview is worse than no gate.

## Source

Method derived from Nate B. Jones, "the AI Question Method" (YouTube talk on
prompting after Opus 4.7 / GPT-5.5, 2026). The three principles above are the
durable distillation — sufficient to implement without the raw source. Operator's
verbatim transcript is archived locally under the `nate-prompt-engineering/`
notes folder (`nate-dead-prompt-engineering.md`); not committed here (verbatim
third-party transcript; this repo is `visibility = "public"`).
