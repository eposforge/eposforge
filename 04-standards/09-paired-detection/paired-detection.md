---
doc_kind: standard
scope: eposforge-pattern
maturity: adopted
source_of_truth: yes
---

# Paired Detection

## Status

- adopted: 2026-06-26
- supersedes: none
- declined-options: "test-suite-per-layer" — rejected; the unit is one
  end-to-end ratchet per layer, not a battery of isolated tests an agent
  will churn (see Normative requirement 4).
- spec-version: n/a

## Scope

This standard governs the **detection half** of a kernel: the habit that
mints, and then keeps, the one-command check that proves an element is
still good. It is the working practice behind the
[Stabilization & Kernels](../../01-architecture/04-stabilization-and-kernels/stabilization-and-kernels.md)
concept — specifically Lehman's "deliberate work" that holds entropy off a
layer in active use.

It is a **sibling of the existing paired-change discipline**: where a
paired change says *"a change to X ships with the matching change to its
contract/spec,"* paired detection says *"a fix to X ships with the matching
check that proves X."*

This standard governs detection at every layer of the bootstrap order. It
is the foundation-and-substrate-layer cousin of the products-layer
guidance in EF-051 (highest-altitude, ungameable definition-of-done
gates): same detection principle, applied at a different altitude. Where
the two layers meet — a product's acceptance gate — EF-051's anti-gaming
requirements govern; this standard governs the cheaper substrate and
factory-internal ratchets beneath it.

This standard does not govern *graded/qualitative* success criteria; those
are rubrics (EF-050), the complement to deterministic detection.

## Normative requirements

1. **Every fix ships a check.** A change that fixes a defect, or that
   stabilizes an element toward kernel status, MUST leave behind a cheap,
   re-runnable check that proves the fixed behavior. "Fixed without a
   check" is incomplete work, not done work.

2. **One command, green or red.** A detection check MUST be runnable in a
   single command and MUST yield an unambiguous pass/fail. A check a human
   has to interpret is not a gate.

3. **One ratchet per layer.** Each layer of the bootstrap order MUST have
   at least one end-to-end check that asserts *"this layer still does its
   one job."* This is a ratchet, not a test suite — see requirement 4.

4. **Altitude over isolation.** Detection MUST assert real end-to-end
   outcomes at the highest practical altitude, not narrow internal proxies.
   In a factory where an agent can rewrite the implementation, isolated
   unit assertions over agent-changed internals are noise that fills
   context and gates nothing; prefer the behavioral ratchet that survives
   a legitimate rewrite.

5. **Cold-start is part of the ratchet.** A layer's ratchet MUST assert the
   layer can **reconstruct cleanly** from source, not merely that it is
   currently healthy. The reconstruction *is* the test: a layer that only
   passes while already running has not proven it is a kernel.

6. **Detection is not gated by the bootstrap order.** Adding a detection
   check to a layer is always-valid work and MUST NOT wait on the layers
   beneath it being kernels. (Trusting that layer's *autonomy* does wait —
   that is the bootstrap rule, a separate concern. See
   [Autonomy Modes — Loop A vs Loop B](../../01-architecture/03-autonomy-modes/autonomy-modes.md#two-loops-autonomy-vs-self-detection).)

7. **External dependencies carry their own detection.** A check that
   depends on an un-kernelable External-tier dependency MUST detect that
   dependency through its Adapter, so vendor drift trips the Adapter's gate
   rather than silently corrupting the layer above.

## Conformance

- Each declared layer has at least one ratchet: an instance can name the
  single command that turns each layer green/red.
- A defect-fix change set includes a check artifact; review rejects a fix
  that lands no re-runnable proof.
- At least one ratchet exercises reconstruction-from-source, not only
  liveness.
- Where a ratchet is a product acceptance gate, it additionally satisfies
  EF-051's anti-gaming requirements (external test authority, spec-derived
  assertions, tamper-evidence).

## Related

- [../../01-architecture/04-stabilization-and-kernels/stabilization-and-kernels.md](../../01-architecture/04-stabilization-and-kernels/stabilization-and-kernels.md)
  — the kernel concept this standard operationalizes.
- [../../01-architecture/03-autonomy-modes/autonomy-modes.md](../../01-architecture/03-autonomy-modes/autonomy-modes.md)
  — Loop A vs Loop B; why detection is ungated while autonomy is gated.
- [08-agent-coding-guidelines/agent-coding-guidelines.md](../08-agent-coding-guidelines/agent-coding-guidelines.md)
  — §4 goal-driven execution (loop until success criteria verified).
- [../../01-architecture/02-components/source-control-ci.md](../../01-architecture/02-components/source-control-ci.md)
  — where ratchets run as required PR status checks.
- [../../01-architecture/02-components/audit-observability.md](../../01-architecture/02-components/audit-observability.md)
  — where gate results are recorded.
