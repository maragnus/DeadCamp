# Hybrid Land-Intent WorldGen

## Purpose
- Generate a deterministic, algorithmically cheap world that feels like roads follow a believable river and hillside layout instead of sitting on generic noise.
- Plan land intent, road layout, branches, POIs, terrain shaping, and RV or player placement from one shared source of truth.
- Treat the square map footprint as a coverage opportunity for a flowing closed drive, not as a literal square template with a few dents.
- Keep world generation separate from `RVBuilder` so the RV and the map can evolve independently.
- Use the same generation pipeline in Studio preview and runtime.

## Path design goals
- The main loop should make convincing use of the full square play area, including multiple corners and meaningful center use, while still closing back into its start area.
- Coverage is a scoring goal, not a prescribed topology. A valid loop should not need to resemble a wavy square to prove that it used the map well.
- The intended drive feel is flowing and road-like: broad sweeps, natural curvature changes, and no obvious hairpins, long flat box sides, or one dominant inward jab.
- The primary hard validity check stays aligned with `track-generator.html`: the course must remain non-self-crossing after curve backoff.

## Module layout
- `src/shared/WorldGen`
  - `WorldConstants`: phase names, root names, shared enums, parcel footprints, descriptor names.
  - `WorldProfile`: default profile, landform or river tuning, road tuning, POI budgets, and validation.
  - `WorldSeed`: deterministic seed normalization and scoped RNG helpers.
  - `LandformPlanner`: shared `LandformDescriptor` generation for one river, ridge spines, basin shaping, and low-frequency detail noise.
  - `Hydrology`: optional river corridor generation, width variation, water level sampling, and river-clearance runtime queries.
  - `RoadLoopSettings`: shared graph-planner defaults and resolved tuning derived from `WorldProfile.PathPlanner`.
  - `RoadLoopGraphPlanner`: authoritative HTML-derived road-network planner that builds a planar road network, selects one primary loop from its faces, preserves the remaining secondary roads, and exposes network metadata for branch reuse.
  - `RoadPathUtils`: shared centripetal spline sampling, arc-length resampling, descriptor creation, and height fitting for loops and branches.
  - `RoadLoopDiagnostics`: shared loop self-intersection diagnostics, footprint metrics, scenic telemetry, and shortcut hotspot analysis.
  - `RoadLoopAttemptRanker`: rejected-attempt ranking plus failure-summary formatting.
  - `RoadLoop`: thin closed-loop orchestrator that runs the graph planner, self-intersection safety checks, and failure reporting while preserving the sampled-loop contract.
  - `RoadRibbonSpec`: render-ready ribbon chunks, triangles, and fallback strip segments for closed loops or open branches.
  - `WorldTerrainMasks`: road corridor widths, shortcut-risk analysis, and terrain influence radii without physical off-road barrier shaping.
  - `WorldConflictUtils`: shared road, branch, river, parcel, and access-corridor conflict checks reused by planners and audits.
  - `POIParcelPlanner`: size or access-aware POI parcel scoring and paced placement across both sides of the route, including `RoadEdge`, `DriveUp`, and `WalkUp`, with shared reserve padding defined for every access type.
  - `BranchPlanner`: network-driven branch descriptor builder that converts preserved secondary-road segments into dead ends, blocked branches, or false intersections without synthetic fallback templates.
  - `RoadRenderBuilder`: shared mesh-or-strip-part renderer used by server and client.
  - `WorldSerialization`: compact fixed-point road-loop transport plus JSON descriptors for landforms, POIs, and branches replicated to clients or stored for debug.
- `src/server/WorldGen`
  - `WorldGenService`: root lifecycle, phase orchestration, debug summary publication, and start-marker publication.
  - `TerrainBuilder`: landform sampling plus voxel terrain stamping with `ReadVoxels`/`WriteVoxels`, contextual roadside blending, parcel flattening, and river water fills.
  - `RoadModelBuilder`: server road render wrapper.
  - `LandformPreviewBuilder`: visible river, bank, ridge, and basin preview markers for Studio inspection.
  - `POIPreviewBuilder`: development pad, reserve, apron, path, and road-edge preview slabs positioned above final terrain.
  - `BranchPreviewBuilder`: branch-road and branch-end blocker previews with template-aware color variation.
  - `WorldGenAudit`: post-terrain audit checks for main-road self-intersections, corridor conflicts, and buried previews.
  - `WorldPlacement`: RV start placement plus right-side player and respawn placement while the current world is active.
  - `FailedLoopPreviewBuilder`: failed path-generation preview for the best rejected loop candidate, its anchor polygon, and failure markers.
- `src/client/WorldGen`
  - `WorldGenClientRenderer`: consumes the replicated compact road-loop descriptor and rebuilds the local road overlay from shared ribbon logic.
  - `WorldGenBootstrap.client.luau`: attaches the client renderer to generated roots as they appear.

## Root structure
- Studio uses `Workspace.WorldGenPreview`.
- Runtime uses `Workspace.GeneratedWorld`.
- World roots are `Folder` instances, not `Model` instances.
- Child folders:
  - `Landforms`
  - `Road`
  - `ServerRoad`
  - `Terrain`
  - `POIs`
  - `Branches`
  - `Blockers`
  - `Debug`
- `Blockers` remains available for compatibility, but the current pipeline no longer stamps anti-shortcut barrier terrain or hotspot blocker decoration outside roads.
- Root attributes:
  - `WorldProfileId`
  - `WorldSeed`
  - `WorldBuildVersion`
  - `WorldPhaseCompleted`
  - `RoadLoopLength`
  - `RoadSampleCount`
  - `EnableClientRoadOverlay`

## Phase order
1. `LandIntent`
   - Generate the shared `LandformDescriptor`: an optional river spline, `1-2` ridge or hillside spines, one basin or shelf field, and low-frequency height-noise settings.
2. `Path`
   - Generate a full planar road network, select one non-self-crossing primary course that uses the square footprint well, preserve the remaining secondary roads, then fit heights and publish the sampled-loop contract for downstream systems.
3. `POIs`
   - Score and place paced POI parcels across both sides of the route, choosing between `RoadEdge`, `DriveUp`, and `WalkUp` while rejecting corridor conflicts before terrain stamping.
4. `Branches`
   - Convert preserved secondary-road segments from the authoritative network into blocked branches, dead ends, or false intersections, while using shared conflict checks to stay out of roads and river corridors.
5. `Terrain`
   - Sample the final landform field, stamp roadbeds and shoulders, flatten POI pads, blend access corridors, shape contextual cut or fill shoulders, and fill river water voxels when hydrology is enabled.
6. `Hooks`
   - Publish the world start marker, debug descriptors, reject summaries, preview geometry, and audit summary for Studio inspection and RV or player placement.

## Determinism and descriptors
- Every generation run is keyed by `WorldProfileId` and explicit `WorldSeed`.
- The server serializes:
  - the landform descriptor
  - the fitted road loop as a compact fixed-point descriptor
  - POI parcel descriptors
  - branch descriptors
- The client never invents path geometry; it only rebuilds the primary-loop render geometry from the same compact loop descriptor the server uses for its rendered road.
- Branch preview roads and main-loop roads both use the same shared ribbon generation path.

## Conflict model and audits
- `WorldConflictUtils` is the shared conflict surface for main-road, branch-road, parcel, access-corridor, river-water, and river-bank clearance checks.
- `BranchPlanner`, `POIParcelPlanner`, and `WorldGenAudit` all reuse that same conflict logic instead of duplicating overlap math.
- `WorldGenAudit` currently runs after the terrain phase and rejects worlds that self-intersect the main road, overlap the main road from false intersections, overlap protected corridors with POIs, or bury preview geometry into terrain.

## RV integration
- `Build_RV_BaseCamp.server.luau` generates the world first, then starts the debug service and spawns the RV.
- `WorldGenService.placeRVAtStart(rv)` moves the built RV onto the published start marker before `RVDriveController.attach(rv)` grounds it against the generated terrain.
- `WorldPlacement` resolves the right-side exterior entry from the tagged door part, validates the drop point, places current players after drive attachment, and reapplies on `CharacterAdded` while the current world and RV remain active.
