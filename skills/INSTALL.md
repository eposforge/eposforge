# Installing EposForge skills into agent CLIs

Use `skills/install.sh` to project canonical `skills/<name>/` into a target agent surface with one command.

## Quick start

```bash
# List skills + surfaces
bash skills/install.sh --list

# Claude Code user skill (directory projection)
bash skills/install.sh maintain-ontology --surface claude-code-user --mode consume

# Copilot workspace skill wrapper in a repo
bash skills/install.sh maintain-ontology --surface copilot-workspace-skill --repo /path/to/repo

# Copilot user prompt (remote-server user profile)
bash skills/install.sh maintain-ontology --surface copilot-user-remote
```

## Adoption modes

- `--mode consume` (default): source is `EPOSFORGE_HOME/skills/<name>` (or this clone).
- `--mode fork`: source is `<current-repo>/skills/<name>`.

## Surfaces

Run `bash skills/install.sh --list` for the current table. Surface behavior is data-driven inside `install.sh` (`SURFACES` array): add a row to add a new surface.

Current minimum coverage:
- Claude Code user scope (`~/.claude/skills/`, `~/.claude/commands/`)
- Copilot workspace (`.github/skills/`, `.github/prompts/`)
- Copilot user scope prompt dirs (remote and local)

Symlink/copy is a surface property. Copy surfaces stamp a provenance header:

```text
# source: <canonical-path>@<commit>
```

Re-running is idempotent. If a copied projection diverges from canonical content, the installer reports drift and refreshes the projection.

## Uninstall

```bash
bash skills/install.sh maintain-ontology --surface copilot-user-remote --uninstall
```
