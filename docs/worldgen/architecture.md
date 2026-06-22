# Layered Road WorldGen V1

## Purpose
- Generate a seedable closed road loop that drives terrain shaping, POI pads, branch roads, and blocker hooks from one authoritative sampled path.
- Keep world generation separate from `RVBuilder` so the RV and the map can evolve independently.
- Use the same generation pipeline in Studio preview and runtime.

## Module layout
- `src/shared/WorldGen`
  - `WorldConstants`: phase names, root names, shared enums, parcel footprints, descriptor names.
  - `WorldProfile`: default profile, sweep or deviation tuning, and validation.
  - `WorldSeed`: deterministic seed normalization and scoped RNG helpers.
  - `RoadPathUtils`: shared centripetal spline sampling, arc-length resampling, descriptor creation, and height fitting for loops and branches.
  - `RoadLoop`: closed-loop generation from square-oriented corner sweeps plus smooth side deviations, with 1 to 2 deeper center-reaching sides, wraparound seam validation, shortcut hotspot detection, and latest-failure reporting for Studio preview.
  - `RoadRibbonSpec`: render-ready ribbon chunks, triangles, and fallback strip segments for closed loops or open branches.
  - `WorldTerrainMasks`: road corridor widths plus hill or valley anti-shortcut hotspot shaping.
  - `POIParcelPlanner`: size/access-aware POI parcel scoring and paced placement across both sides of the route.
  - `BranchPlanner`: terrain-following abandoned branch-road descriptors with sampled paths.
  - `RoadRenderBuilder`: shared mesh-or-strip-part renderer used by server and client.
  - `WorldSerialization`: compact fixed-point road-loop transport plus JSON descriptors replicated to clients.
  - `Hydrology`: reserved future hook surface; disabled in V1.
- `src/server/WorldGen`
  - `WorldGenService`: root lifecycle, phase orchestration, start marker publication, RV placement helper.
  - `TerrainBuilder`: road height fitting plus voxel terrain stamping with `ReadVoxels`/`WriteVoxels`.
  - `RoadModelBuilder`: server road render wrapper.
  - `POIPreviewBuilder`: development pad/apron slabs.
  - `BranchPreviewBuilder`: branch-road and blocker previews.
  - `FailedLoopPreviewBuilder`: failed path-generation preview for the best rejected loop candidate, its anchor polygon, and failure markers.
  - `BlockerDecorator`: shortcut hotspot markers.
- `src/client/WorldGen`
  - `WorldGenClientRenderer`: consumes the replicated compact road-loop descriptor and rebuilds the local road overlay from shared ribbon logic.
  - `WorldGenBootstrap.client.luau`: attaches the client renderer to generated roots as they appear.

## Root structure
- Studio uses `Workspace.WorldGenPreview`.
- Runtime uses `Workspace.GeneratedWorld`.
- World roots are `Folder` instances, not `Model` instances.
- Child folders:
  - `Road`
  - `ServerRoad`
  - `Terrain`
  - `POIs`
  - `Branches`
  - `Blockers`
  - `Debug`
- Root attributes:
  - `WorldProfileId`
  - `WorldSeed`
  - `WorldBuildVersion`
  - `WorldPhaseCompleted`
  - `RoadLoopLength`
  - `RoadSampleCount`
  - `EnableClientRoadOverlay`

## Phase order
1. `Path`
   - Generate a closed square-covering loop with broad corner sweeps, smooth zero-slope side deviations, and 1 to 2 center-reaching sides, then validate it, derive shortcut hotspots, quantize a compact loop descriptor, and rebuild chunked ribbons locally on each side.
2. `Terrain`
   - Fit road and branch heights against the base heightfield, then stamp the map terrain with partial voxel occupancy around the driveable corridor.
3. `POIs`
   - Score and place paced POI parcels across both road sides, then flatten them as part of terrain stamping and render development slabs.
4. `Branches`
   - Add terrain-following abandoned branch-road descriptors and preview geometry; branch terrain uses the same road-aware terrain pass as the main road.
5. `Hooks`
   - Add blocker previews and preserve hydrology hook metadata for future work.

## Determinism and descriptors
- Every generation run is keyed by `WorldProfileId` and explicit `WorldSeed`.
- The server serializes:
  - the fitted road loop as a compact fixed-point descriptor
  - POI parcel descriptors
  - branch descriptors
- The client never invents path geometry; it only rebuilds render geometry from the same compact loop descriptor the server uses for its rendered road.
- Branch preview roads and main-loop roads both use the same shared ribbon generation path.

## RV integration
- `Build_RV_BaseCamp.server.luau` generates the world first, then starts the debug service and spawns the RV.
- `WorldGenService.placeRVAtStart(rv)` moves the built RV onto the published start marker before `RVDriveController.attach(rv)` grounds it against the generated terrain.
