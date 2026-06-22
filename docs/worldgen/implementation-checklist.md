# WorldGen Implementation Checklist

## Phase 0 scaffold
- [x] Create shared, server, and client `WorldGen` module trees.
- [x] Extend `RVDebugPanelConfig` and `RVDebugPanelService` with world generation actions.
- [x] Add worldgen docs and update `AGENTS.md`.

## Phase 1 path and ribbon
- [x] Generate a deterministic closed loop from a square-oriented anchor set with stronger inward features.
- [x] Resample by arc length and reject invalid loops by bounds, self-intersection, and minimum curve radius.
- [x] Detect shortcut hotspots from physically close but lap-distant samples.
- [x] Build a shared chunked road ribbon descriptor with seamless `128x128`-bounded pieces.
- [x] Render a server road surface from the descriptor.
- [x] Render a client road overlay from the same descriptor.

## Phase 2 terrain
- [x] Create a base terrain sampler from seeded noise.
- [x] Fit road heights to the terrain with grade clamping.
- [x] Use `Terrain:ReadVoxels` and `Terrain:WriteVoxels` in chunked regions.
- [x] Stamp roadbed, shoulders, discourage band, and shortcut-barrier terrain.
- [x] Replace binary voxel fills with partial occupancy so terrain reads as blended instead of stepped.
- [x] Shape shortcut barriers as smaller hills or valleys that stop the RV without looking like artificial spikes.
- [ ] Add more material variation and local detail noise once base shaping is stable.

## Phase 3 POIs
- [x] Score parcels using the center plus 8 perimeter control points.
- [x] Respect one global POI pool: small `64x64`, medium `128x128`, large `256x256`.
- [x] Support `DriveUp` and `WalkUp`.
- [x] Flatten parcels through the terrain pass.
- [x] Render development pad/apron slabs.
- [x] Pace parcel selection by lap distance so POIs stay relatively even while still allowing organic variance.
- [ ] Replace development slabs with authored POI prefabs in a later pass.

## Phase 4 branches
- [x] Generate abandoned branch-road descriptors off the main loop only.
- [x] Preview branch roads and dead-end blockers.
- [x] Make branch preview roads follow terrain using the same sampled-road pipeline as the main loop.
- [ ] Reserve dedicated dead-end branch POI content once authored POIs exist.
- [ ] Increase occlusion and visual ambiguity at branch entrances with real environment props.

## Phase 5 hooks
- [x] Add blocker preview hooks for shortcut hotspots.
- [x] Keep hydrology explicitly disabled but preserve reservation hooks.
- [ ] Replace blocker preview parts with authored decorator systems.

## Exit criteria before expanding scope
- [ ] Same seed reproduces the same loop, terrain, POI slabs, and branch layout in Studio reruns.
- [ ] The RV spawns onto the generated road and remains driveable around the full loop.
- [ ] Shortcut hotspots visibly become RV-hostile terrain instead of alternate route opportunities.
- [ ] Main road mesh chunks stay seamless with no visible cracks between adjacent sections.
- [ ] `GenerateWorldPhase1`, `GenerateTerrain`, `GeneratePOIParcels`, `GenerateBranches`, `GenerateWorldAll`, and `DestroyWorld` all work cleanly from the debug panel.
