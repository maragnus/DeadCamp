# Meta Progression

Status: `planned`

## Purpose

Track what persists between runs: save data, unlocks, RV cosmetics, long-term upgrades, and any account-level progression that shapes future attempts.

## What exists now

- The design pitch already calls for both run-based survival and persistent unlocks.
- The RV builder provides a natural future target for cosmetic or upgrade-driven configuration, but no persistence layer exists yet.

## What does not exist yet

- No profile save schema, save service, unlock system, persistent RV-upgrade model, or decoration system exists yet.
- No distinction exists yet between run-local progression and account-level progression.

## Key files

- `PITCH.md`
- `AGENTS.md`
- `src/server/RVBuilder/Plans/BaseCamp.luau`

## Suggested file homes

- `src/shared/Progression/`
- `src/server/Progression/`
- `src/shared/SaveData/`
- `src/server/SaveData/`

## Dependencies

- `Vehicle Platform` for upgrade targets and cosmetic application points.
- `Run Planning and Economy` for unlocks that influence starting conditions or vendor access.
- `Round Gameplay` for deciding what persists and what resets each run.
