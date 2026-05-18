---
doc_kind: architecture-contract
scope: eposforge-pattern
maturity: draft
source_of_truth: yes
---

# Adoption Strategy

The [phase roadmaps](./platform-factory-phases.md) describe the
destination shape of each maturity plateau. They are silent on **how
a non-greenfield instance gets there from where it stands today.**
This doc fills that gap.

It applies recursively: at every phase transition the same brownfield
problem reappears. An instance moving from Phase 1 to Phase 2 has
existing tier-1-approved categories that need to be reshaped, not just
new ones to add.

---

## The default — opportunistic alignment with completion commitment

The default strategy for adopting eposforge, and for advancing between
phases inside it, is:

**Align ongoing backlog work with the target architecture as it
passes through.** Bug fixes and new features were going to be done
anyway. If each unit of work that touches a component is delivered
against the target shape rather than the legacy shape, the additional
cost is usually small enough to be absorbed by the existing budget.

This is the [strangler fig pattern][fowler-strangler] combined with
opportunistic refactoring. It ships incremental value without the
risk of a big-bang cutover.

[fowler-strangler]: https://martinfowler.com/bliki/StranglerFigApplication.html

### The four obligations

Opportunistic alignment is a strategy — not drift — only when all
four hold:

1. **Alignment.** In-flight work that touches a component is delivered
   against the target architecture, not the legacy shape, unless an
   explicit exception is recorded.
2. **Completion commitment.** The instance has a stated, dated
   commitment to finish the migration. "We'll get to it" is not a
   commitment.
3. **Visibility of remaining debt.** When a developer or agent
   touches something inside an in-flight migration, they can see
   — at the moment of contact, not by remembering — that the
   migration exists, which side they are touching, and where it
   is going. EposForge models this with first-class `Migration`
   entities in the Spec Graph (see
  [ontology](../00-vision/01-ontology.ttl)): anything in the
   graph declares its side via `LEGACY_SHAPE_OF` or
   `TARGET_SHAPE_OF`. How an instance populates those edges —
   frontmatter markers on files, a manifest file, lint rules,
   code annotations — is an instance choice. What is required is
   that visibility is mechanical, not memory-dependent.
4. **Active balance management.** Someone owns the trade-off between
   opportunistic pace and bounded-batch rewrites. When throughput
   stalls or backlog overlap with the migration is low, a larger
   chunk is carved off and done deliberately.

If any of the four lapses, the strategy degrades into permanent
inconsistency.

### Compatibility with phase sequentiality

The phase roadmaps require phases to be adopted in order.
Opportunistic alignment does not violate that:

- It moves the instance **within a phase**, never across one.
- A phase transition still requires the phase's `Done when` criterion
  to be met before advancing.

Opportunistic *adoption* and sequential *advancement* are
orthogonal.

---

## When to choose something else

Opportunistic alignment is the default because it minimizes risk and
fits into existing budget. Other strategies are appropriate when:

- The legacy shape is actively hostile to ongoing work (every touch
  costs more in the old shape than in the new one).
- A regulator, vendor, or platform deadline forces a hard cutover.
- AI-driven mass-transformation tooling (Blitzy and equivalents)
  makes a bounded big-bang on a defined corpus cheaper than carrying
  inconsistency for years. See the note in
  [03-research/adoption-strategies.md](../03-research/adoption-strategies.md)
  on how this changes the menu.
- The component being migrated is small enough that opportunistic
  touch rate is effectively zero.

See [03-research/adoption-strategies.md](../03-research/adoption-strategies.md)
for the menu and tradeoffs.
