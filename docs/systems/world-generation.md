# World Generation

Status: `scaffolded`

## Purpose

Generate a cheap but plausible drivable landscape where land intent, roads, branches, POIs, terrain, and RV or player placement all come from one deterministic world plan.

## Path goals

- The main road should be a flowing closed drive that makes strong use of the square map footprint, including meaningful use of both corners and center space.
- Square-map coverage is a goal, not a prescribed topology. The path should not read as a rounded square with one deep dent and one shallower dent just because the planner hard-coded that shape.
- The drive should feel varied and scenic, with broad sweeps and natural inward or outward movement, not long flat sides joined by hairpins or one dominant inward jab.
- The loop still needs to return cleanly to its starting area and preserve the HTML graph planner's non-self-crossing contract after curve backoff.

## What exists now

- The repo now has a deterministic `LandIntent -> Path -> POIs -> Branches -> Terrain -> Hooks` pipeline instead of the older road-on-noise flow.
- `LandIntent` currently generates `1-2` ridge spines, one basin or shelf field, and low-frequency detail noise through a shared `LandformDescriptor`, with river generation available but disabled in the default profile for now.
- The main-loop path now uses an authoritative HTML-derived graph road generator that builds a planar road network, selects one primary non-self-crossing course from its faces, preserves the remaining secondary-road network, then fits heights while preserving the existing sampled-loop contract for downstream systems.
- Road rendering still uses compact loop descriptors and shared chunked ribbon rendering on server and client.
- POI planning now supports `RoadEdge`, `DriveUp`, and `WalkUp`, with shared reserve padding defined for all three access types, and rejects parcels, reserves, aprons, and paths when they cross roads, branch corridors, river water, bank clearance, or accepted POIs.
- Branch and dead-end roads now come only from the preserved secondary-road network generated alongside the primary course; the old synthetic dead-end and false-intersection templates are no longer authoritative.
- Final terrain is stamped from the landform field with contextual shoulders, shallow cut or fill behavior, river water voxels, and more off-road material variation instead of physical anti-shortcut terrain walls.
- Landform, river, POI, branch, and audit data are stored under the generated root for Studio inspection, and visible previews sample final terrain so they stay above the ground.
- The generated world service now places the RV at the world start marker and can keep current players and respawned characters on the RV's right-side exterior entry above terrain.
- Failed path-generation runs still leave behind the best rejected graph-loop attempt, with failure categories limited to planner generation or self-intersection.
- Dedicated implementation and validation docs already exist under `docs/worldgen`.

## What does not exist yet

- POIs are still preview slabs and descriptors rather than authored gameplay spaces.
- The system does not yet own loot composition, resource pressure, or checkpoint pacing.
- Bridge generation and river crossings are intentionally out of scope; layouts retry instead of building across water.
- Environmental dressing and authored roadside or branch-end obstacle sets are still placeholder-level.
- Secondary-road classification is still simple; preserved network roads can become blocked branches, dead ends, or false intersections, but they are not yet dressed or gameplay-authored beyond that.
- Runtime validation still needs Studio-side driving passes for flow, curvature feel, shoulder blending, river visuals, and parcel spacing.

## Key files

- `src/shared/WorldGen/WorldConstants.luau`
- `src/shared/WorldGen/WorldProfile.luau`
- `src/shared/WorldGen/WorldSeed.luau`
- `src/shared/WorldGen/LandformPlanner.luau`
- `src/shared/WorldGen/Hydrology.luau`
- `src/shared/WorldGen/RoadLoopSettings.luau`
- `src/shared/WorldGen/RoadLoopGraphPlanner.luau`
- `src/shared/WorldGen/RoadPathUtils.luau`
- `src/shared/WorldGen/RoadLoopDiagnostics.luau`
- `src/shared/WorldGen/RoadLoopAttemptRanker.luau`
- `src/shared/WorldGen/RoadLoop.luau`
- `src/shared/WorldGen/RoadRibbonSpec.luau`
- `src/shared/WorldGen/WorldConflictUtils.luau`
- `src/shared/WorldGen/WorldTerrainMasks.luau`
- `src/shared/WorldGen/POIParcelPlanner.luau`
- `src/shared/WorldGen/BranchPlanner.luau`
- `src/shared/WorldGen/WorldSerialization.luau`
- `src/server/WorldGen/WorldGenService.luau`
- `src/server/WorldGen/TerrainBuilder.luau`
- `src/server/WorldGen/LandformPreviewBuilder.luau`
- `src/server/WorldGen/POIPreviewBuilder.luau`
- `src/server/WorldGen/BranchPreviewBuilder.luau`
- `src/server/WorldGen/WorldGenAudit.luau`
- `src/server/WorldGen/WorldPlacement.luau`
- `src/server/WorldGen/FailedLoopPreviewBuilder.luau`
- `docs/worldgen/architecture.md`
- `docs/worldgen/implementation-checklist.md`
- `docs/worldgen/validation-playbook.md`

## Dependencies

- `Vehicle Platform` for RV build geometry, tagged entry doors, spawn placement, and driveability validation.
- Future `Run Planning and Economy` for scarcity, reward pacing, and checkpoint cadence.
- Future `Encounters` and authored POI systems for populated gameplay spaces.
