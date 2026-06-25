# DeadCamp Systems

This folder is the status-tracked index for the game's major runtime and gameplay systems.

## Status legend

- `planned`: design intent only; no durable runtime implementation or scaffold yet.
- `scaffolded`: repo structure, preview code, or partial runtime hooks exist, but the player-facing system is still incomplete.
- `implemented`: a usable foundation exists in the active repo and participates in the current build or runtime flow.

## Systems

- `Vehicle Platform` (`implemented`)
  - Doc: `docs/systems/vehicle-platform.md`
  - Covers modular RV construction, driving, passenger support, and vehicle runtime behavior.
- `World Generation` (`scaffolded`)
  - Doc: `docs/systems/world-generation.md`
  - Deep docs: `docs/worldgen/architecture.md`, `docs/worldgen/implementation-checklist.md`, `docs/worldgen/validation-playbook.md`
  - Covers the seeded `LandIntent -> Path -> POIs -> Branches -> Terrain -> Hooks` pipeline, optional river-aware landforms, an HTML-derived graph road network with one primary loop plus preserved secondary roads, conflict-aware POI and branch planning, terrain shaping, debug previews, audit summaries, and RV or player placement hooks.
- `Run Planning and Economy` (`planned`)
  - Doc: `docs/systems/run-planning-and-economy.md`
  - Covers resource pressure, loot pacing, checkpoint cadence, and how POIs keep each run tense and rewarding.
- `Round Gameplay` (`planned`)
  - Doc: `docs/systems/round-gameplay.md`
  - Covers round rules, survival needs, inventory, looting, repair, crafting, and checkpoint interactions.
- `Encounters` (`planned`)
  - Doc: `docs/systems/encounters.md`
  - Covers zombies, hordes, combat, barricades, events, and defense tools.
- `Meta Progression` (`planned`)
  - Doc: `docs/systems/meta-progression.md`
  - Covers save data, unlocks, RV upgrades, decoration, cosmetics, and long-term progression.
- `Tooling and Validation` (`implemented`)
  - Doc: `docs/systems/tooling-and-validation.md`
  - Covers the debug panel, preview flows, validation commands, and deterministic smoke-check helpers.

## Maintenance

- Update this index whenever a system changes status or gains a new dedicated doc.
- Keep each system doc concise and structured with `Status`, `Purpose`, `What exists now`, `What does not exist yet`, and `Key files`.
- Keep `AGENTS.md` as the cross-system index. Move subsystem-specific inventories, geometry rules, and step-by-step validation playbooks into the owning system doc instead of expanding `AGENTS.md`.
- If a system has no durable runtime files yet, say `Key files: None yet.` and point to the relevant design docs instead of inventing file references.
