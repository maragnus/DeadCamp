# Encounters

Status: `planned`

## Purpose

Provide the hostile pressure that turns travel and looting into a survival game: zombies, hordes, events, barricade pressure, and reactive threats around the RV and POIs.

## What exists now

- The design pitch already defines likely enemy types, night defense pressure, and random-event ideas.
- The RV, world generation, and future round systems already create the spaces where encounter logic will eventually run.

## What does not exist yet

- No NPC runtime, zombie AI, horde director, combat rules, or barricade damage system exists yet.
- No event spawner, alarm system, roaming threat model, or POI-specific threat authoring exists yet.

## Key files

- `PITCH.md`
- `AGENTS.md`

## Suggested file homes

- `src/shared/Encounters/`
- `src/server/Encounters/`
- `src/shared/NPC/`
- `src/server/NPC/`

## Dependencies

- `World Generation` for encounter spaces and route structure.
- `Round Gameplay` for player health, resources, and defense interactions.
- `Run Planning and Economy` for threat-reward balancing and pacing.
