# Round Gameplay

Status: `planned`

## Purpose

Own the playable loop once the RV and world exist: drive, stop, loot, survive, repair, recover, and reach the next checkpoint without the run collapsing.

## What exists now

- The repo already has the physical foundations for driving through a generated world and supporting passengers on the RV.
- Design intent already exists for food, water, fuel, parts, tools, checkpoints, upgrades, and player roles.

## What does not exist yet

- No round-state authority, win or loss rules, or checkpoint flow currently exists.
- No survival-need runtime exists for hunger, thirst, fatigue, injury, or treatment.
- No inventory, storage, carrying, looting, repair, crafting, or checkpoint-service systems exist yet.

## Key files

- `PITCH.md`
- `AGENTS.md`
- `src/server/Build_RV_BaseCamp.server.luau`

## Suggested file homes

- `src/shared/GameRules/`
- `src/server/GameRules/`
- `src/shared/Survival/`
- `src/server/Survival/`
- `src/shared/Inventory/`
- `src/server/Inventory/`

## Dependencies

- `Vehicle Platform` for repair targets, storage surfaces, and travel pacing.
- `Run Planning and Economy` for scarcity, loot budgets, and checkpoint value.
- `Encounters` for the threats that interrupt or pressure the loop.
