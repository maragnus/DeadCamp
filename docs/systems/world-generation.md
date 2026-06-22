# World Generation

Status: `scaffolded`

## Purpose

Generate the drivable loop, terrain, parcel layout, and branch structure that the round uses as its physical world.

## What exists now

- The repo already has a deterministic world-generation pipeline with a seedable closed road loop that now uses broad square-covering corner sweeps and smooth side deviations instead of a simple round ring.
- The loop generator now reserves 1 to 2 deeper center-reaching sides so the route can meaningfully utilize the middle of the map instead of only orbiting the perimeter.
- Road rendering exists on both server and client from the same compact quantized loop descriptor, and the road surface is chunked into smaller seamless pieces instead of one oversized mesh.
- Terrain shaping, POI parcel planning, branch descriptors, blocker hooks, and client or server preview rendering all exist.
- Terrain stamping now uses partial voxel occupancy, road-aware height fitting, and softer hill or valley shortcut barriers instead of harsh rock-spike bands.
- Branch previews now follow the same sampled-road pathing approach as the main road, so false intersections and dead ends read like plausible roads.
- The generated world uses folder-based roots and a runtime service that can place the RV at the published start marker.
- Failed path-generation runs now leave behind a debug preview of the best rejected loop attempt, including anchors, sampled loop path, and failure markers for intersections or the tightest curve.
- Dedicated implementation and validation docs already exist under `docs/worldgen`.

## What does not exist yet

- POIs are still preview slabs and descriptors rather than authored gameplay spaces.
- The system does not yet own loot composition, resource pressure, or checkpoint pacing.
- Environmental dressing, blocker decorators, and branch-content follow-through are still placeholder-level.
- Runtime validation still needs Studio-side driving passes to tune curvature, mesh seam quality, and final POI spacing.

## Key files

- `src/shared/WorldGen/WorldConstants.luau`
- `src/shared/WorldGen/WorldProfile.luau`
- `src/shared/WorldGen/WorldSeed.luau`
- `src/shared/WorldGen/RoadPathUtils.luau`
- `src/shared/WorldGen/RoadLoop.luau`
- `src/shared/WorldGen/RoadRibbonSpec.luau`
- `src/shared/WorldGen/WorldTerrainMasks.luau`
- `src/shared/WorldGen/POIParcelPlanner.luau`
- `src/shared/WorldGen/BranchPlanner.luau`
- `src/shared/WorldGen/WorldSerialization.luau`
- `src/server/WorldGen/WorldGenService.luau`
- `src/server/WorldGen/TerrainBuilder.luau`
- `src/server/WorldGen/POIPreviewBuilder.luau`
- `src/server/WorldGen/BranchPreviewBuilder.luau`
- `src/server/WorldGen/FailedLoopPreviewBuilder.luau`
- `docs/worldgen/architecture.md`
- `docs/worldgen/implementation-checklist.md`
- `docs/worldgen/validation-playbook.md`

## Dependencies

- `Vehicle Platform` for spawn placement and driveability validation.
- Future `Run Planning and Economy` for scarcity, reward pacing, and checkpoint cadence.
- Future `Encounters` and authored POI systems for populated gameplay spaces.
