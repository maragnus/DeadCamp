# WorldGen Implementation Checklist

## Phase 0 surface and docs
- [x] Keep shared, server, and client `WorldGen` module trees in place.
- [x] Extend `RVDebugPanelConfig` and `RVDebugPanelService` with `Generate Land Intent` and fixed-seed audit actions.
- [x] Update the worldgen docs and repo pointers for the hybrid land-intent pipeline.

## Phase 1 land intent
- [x] Add a shared `LandformPlanner` that outputs one river, `1-2` ridge spines, one basin or shelf field, and low-frequency detail-noise settings.
- [x] Turn `Hydrology` into a real river generator with sampled width, bank, floodplain, and water-level data.
- [x] Serialize the `LandformDescriptor` and expose visible landform preview markers in Studio.
- [x] Keep the land-intent field cheap by using signed-distance and sampled blends instead of erosion simulation.

## Phase 2 path and ribbon
- [x] Generate a deterministic closed loop scaffold that stays within the world constraints and feeds the shared ribbon pipeline.
- [x] Replace the current square-oriented side template with a planner that treats corners, center use, and overall square-footprint coverage as scoring goals instead of prescribed dents.
- [x] Replace the current path-shape approach with one that consistently produces broad, flowy curvature instead of long flat sides, hairpins, or one dominant inward jab.
- [x] Fit road heights against the landform field with grade clamping.
- [x] Keep main-road acceptance aligned with `track-generator.html` instead of layering extra radius, river, center, or flow gates on top.
- [x] Preserve road-context telemetry for debug without turning it into extra acceptance logic.
- [x] Keep the shared chunked road ribbon descriptor and server or client render reuse.

## Phase 3 POIs
- [x] Support `RoadEdge`, `DriveUp`, and `WalkUp`.
- [x] Score parcels with paced lap-distance spacing and flatten them through the terrain pass.
- [x] Reject pads, reserves, aprons, and paths that overlap roads, branches, river water, river banks, or accepted POIs.
- [x] Keep preview pads, reserves, aprons, and paths visibly above final terrain for debugging.
- [ ] Replace development preview slabs with authored POI prefabs in a later pass.

## Phase 4 branches
- [x] Preserve the full secondary-road network generated alongside the primary course.
- [x] Build branch descriptors from preserved network roads instead of synthetic dead-end or false-intersection templates.
- [x] Keep primary-road and secondary-road ownership separate so the secondary network can be reused without re-generating road shapes.
- [x] Reject branch corridors that cross roads, river water, or river-bank clearance.
- [x] Keep branch-end blockers only as diegetic road-end obstacles.
- [ ] Add authored environment dressing and stronger visual ambiguity at branch entrances later.

## Phase 5 terrain and hooks
- [x] Build terrain from the landform field rather than generic noise alone.
- [x] Stamp contextual shoulders, shallow cut or fill blending, parcel flattening, access corridors, and river water voxels.
- [x] Remove physical off-road anti-shortcut terrain barriers from the current stamping flow.
- [x] Increase off-road material variation so grass, dirt, mud, rock, and riverbank zones visually sell the cost of leaving pavement.
- [x] Add shared audit summaries, reject summaries, RV start placement, and right-side player or respawn placement hooks.

## Exit criteria before expanding scope
- [x] `rojo sourcemap default.project.json --output NUL` passes.
- [x] `rojo build default.project.json --output "$env:TEMP\\DeadCamp_rojo_validate.rbxlx"` passes.
- [x] `GenerateLandIntent`, `GenerateWorldPhase1`, `GeneratePOIParcels`, `GenerateBranches`, `GenerateTerrain`, `GenerateWorldAll`, `AuditWorldSeeds`, and `DestroyWorld` exist in the debug surface.
- [ ] Studio confirms the fixed audit seeds each show one visible river, no water crossings, no repeated ditch pattern, and believable flowing roads that use corners and center without collapsing into a wavy square.
- [ ] Studio confirms close POIs hug the shoulder without repainting asphalt and farther POIs stop aprons or paths at the shoulder edge.
- [ ] Studio confirms current players and respawned characters appear beside the RV's right-side entry above terrain.
- [ ] The RV remains driveable around the full loop after landform tuning passes.
