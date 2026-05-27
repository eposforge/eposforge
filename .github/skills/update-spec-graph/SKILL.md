---
name: update-spec-graph
description: Updates the Cognee Spec Graph (Component 6) knowledge graph. Use to sync the KG after doc changes (incremental), rebuild from scratch or after editing the ontology (full rebuild + KG wipe), or when recall is stale or entities are not ontology-anchored.
---

Thin wrapper for the canonical repo-level skill.

- Canonical skill: [../../../skills/update-spec-graph/SKILL.md](../../../skills/update-spec-graph/SKILL.md)

Use the canonical skill for all Spec Graph update behavior — it owns both the
incremental sync path and the full rebuild path, and decides which a given
change requires.
