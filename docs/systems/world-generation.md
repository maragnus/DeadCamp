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
- Shared road samples now carry one authoritative centerline and derivative frame contract for terrain and POI systems, while visible road meshes rebuild their own deterministic lateral offsets from the centerline positions instead of trusting stored per-sample ribbon frames.
- Road surfaces now use a dedicated deterministic road-mesh builder that resolves one full-path sample-frame pass, offsets a constant half-width from each stable `Right` vector, chooses the most top-stable split for each road quad, and relies on shared geometry to canonicalize final triangle winding from the declared facing before mesh build.
- Road rendering now keeps one authoritative in-memory road network for server surface generation and publishes one compact serialized road-network descriptor for the main loop plus preserved secondary roads, with the client deterministically rebuilding sample frames from quantized sample positions instead of receiving full `Tangent` or `Right` or `Up` payloads.
- Worldgen road rendering now delegates all EditableMesh lifecycle, fixed-size conversion, cleanup, and mesh validation to the shared `src/shared/Geometry` utilities instead of calling Roblox mesh APIs or hand-rolling winding inside worldgen feature code, and road-surface generation now fails hard instead of degrading to `Part` strips when mesh building breaks.
- Terrain-aligned road rendering now reuses each authoritative road sample's own fitted height plus the shared roadbed raise when rebuilding visible road meshes, instead of re-sampling the stamped terrain field at centerline points and inheriting nearest-sample jitter.
- Verbose road-mesh diagnostics stay behind `WorldConstants.DebugFlags.RoadRenderMeshDiagnostics` so normal worldgen failures remain concise until deeper render debugging is needed.
- POI planning now supports `RoadEdge`, `DriveUp`, and `WalkUp`, with shared reserve padding defined for all three access types, and rejects parcels, reserves, aprons, and paths when they cross the main loop, preserved secondary roads, river water, bank clearance, or accepted POIs.
- Preserved secondary roads are now treated as real network roads from the planner output forward; the old synthetic dead-end and false-intersection templates are no longer authoritative, and blockage dressing is intentionally deferred.
- Final terrain is stamped from the landform field with raised road surfaces, shared visual road clearance, smoother roadside blending, widened intersection flattening, and dedicated intersection mesh sizing from one shared junction builder, plus river water voxels and more off-road material variation instead of physical anti-shortcut terrain walls.
- Full startup generation no longer runs as one blocking script step; `WorldGenService` now advances one active worldgen job over multiple `Heartbeat` frames, with terrain voxel stamping consumed chunk-by-chunk instead of in one monolithic map pass.
- Landform, river, POI, branch, and audit data are stored under the generated root for Studio inspection, and visible previews sample final terrain so they stay above the ground.
- The generated root now stores one authoritative road-network descriptor instead of split loop-only and preserved-road surface payloads.
- The generated world service now places the RV at the world start marker and can keep current players and respawned characters on the RV's right-side exterior entry above terrain.
- The server now publishes replicated loading state in `ReplicatedStorage.DeadCampWorldGenStatus` so clients can observe `IsLoading`, `HasWorld`, `LoadPhase`, `LoadProgress`, and `LoadError` without waiting for a generated root to appear, and the server output now logs phase transitions plus completion or failure for async worldgen jobs.
- Failed path-generation runs still leave behind the best rejected graph-loop attempt, with failure categories limited to planner generation or self-intersection.
- Dedicated implementation and validation docs already exist under `docs/worldgen`.

## What does not exist yet

- POIs are still preview slabs and descriptors rather than authored gameplay spaces.
- The system does not yet own loot composition, resource pressure, or checkpoint pacing.
- Bridge generation and river crossings are intentionally out of scope; layouts retry instead of building across water.
- Environmental dressing and authored roadside or branch-end obstacle sets are still placeholder-level.
- Secondary-road dressing is still simple; preserved network roads render and shape terrain correctly, but blockage dressing, overgrowth, and gameplay-authored closures are still deferred.
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
- `src/shared/WorldGen/WorldMath.luau`
- `src/shared/WorldGen/RoadLoopDiagnostics.luau`
- `src/shared/WorldGen/RoadLoopAttemptRanker.luau`
- `src/shared/WorldGen/RoadLoop.luau`
- `src/shared/WorldGen/RoadJunctionBuilder.luau`
- `src/shared/WorldGen/RoadMeshBuilder.luau`
- `src/shared/WorldGen/RoadNetworkBuilder.luau`
- `src/shared/WorldGen/RoadRibbonSpec.luau`
- `src/shared/WorldGen/RoadSurfaceProfile.luau`
- `src/shared/WorldGen/WorldConflictUtils.luau`
- `src/shared/Geometry/EditableMeshBuilder.luau`
- `src/shared/Geometry/MeshShapePrimitives.luau`
- `src/shared/Geometry/MeshValidation.luau`
- `src/shared/WorldGen/WorldTerrainMasks.luau`
- `src/shared/WorldGen/POIParcelPlanner.luau`
- `src/shared/WorldGen/BranchPlanner.luau`
- `src/shared/WorldGen/WorldSerialization.luau`
- `src/server/WorldGen/WorldGenService.luau`
- `src/server/WorldGen/TerrainBuilder.luau`
- `src/server/WorldGen/LandformPreviewBuilder.luau`
- `src/server/WorldGen/POIPreviewBuilder.luau`
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
