# Run Planning and Economy

Status: `planned`

## Purpose

Control how each run stays tense and rewarding by deciding where pressure comes from, what supplies are scarce, how exciting loot is seeded, and when checkpoints offer relief or upgrades.

## What exists now

- The world-generation scaffold already produces parcel candidates and branch descriptors that this system can eventually score and populate.
- The game pitch and AGENTS notes already define the intended loop of driving, looting, repairing, selling excess, and upgrading at towns or checkpoints.

## What does not exist yet

- No runtime planner currently budgets food, water, fuel, medicine, parts, or tools across a loop.
- No system currently decides POI reward intensity, checkpoint cadence, vendor inventory, sell values, or upgrade access.
- No shortage or comeback logic exists yet to keep runs stressful without becoming impossible.

## Key files

- `PITCH.md`
- `AGENTS.md`
- `src/shared/WorldGen/POIParcelPlanner.luau`
- `src/shared/WorldGen/WorldProfile.luau`

## Suggested file homes

- `src/shared/RunPlanning/`
- `src/server/RunPlanning/`
- `src/shared/Loot/`
- `src/server/POI/`

## Dependencies

- `World Generation` for parcel candidates, route shape, and checkpoint locations.
- `Round Gameplay` for survival consumption, inventory constraints, and repair demand.
- `Meta Progression` for persistent unlocks that should bend, but not break, run pressure.
