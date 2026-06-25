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
  - `WorldConstants`: phase names, root names, loading-status names, shared enums, parcel footprints, and descriptor names.
  - `WorldProfile`: default profile, landform or river tuning, road tuning, POI budgets, and validation.
  - `WorldSeed`: deterministic seed normalization and scoped RNG helpers.
  - `LandformPlanner`: shared `LandformDescriptor` generation for one river, ridge spines, basin shaping, and low-frequency detail noise.
  - `Hydrology`: optional river corridor generation, width variation, water level sampling, and river-clearance runtime queries.
  - `RoadLoopSettings`: shared graph-planner defaults and resolved tuning derived from `WorldProfile.PathPlanner`.
  - `RoadLoopGraphPlanner`: authoritative HTML-derived road-network planner that builds a planar road network, selects one primary loop from its faces, preserves the remaining secondary roads, and exposes network metadata for downstream road rendering and intersection shaping.
  - `RoadPathUtils`: shared centripetal spline sampling, arc-length resampling, descriptor creation, descriptor serialization, and height fitting for loops and secondary roads, including the authoritative right-handed `Tangent`/`Right`/`Up` sample frame consumed by rendering, terrain, and POI placement.
  - `RoadLoopDiagnostics`: shared loop self-intersection diagnostics, footprint metrics, scenic telemetry, and shortcut hotspot analysis.
  - `RoadLoopAttemptRanker`: rejected-attempt ranking plus failure-summary formatting.
  - `RoadLoop`: thin closed-loop orchestrator that runs the graph planner, self-intersection safety checks, and failure reporting while preserving the sampled-loop contract.
  - `RoadJunctionBuilder`: shared junction sizing and entry reconstruction used by terrain flattening and visible intersection surfaces.
  - `RoadNetworkBuilder`: shared loop, secondary-road, and intersection render builder used by server and client from the same road-network descriptor.
  - `RoadRibbonSpec`: render-ready ribbon sections and triangles for closed loops or open branches, with seam-matched section boundaries when a road exceeds the mesh-length cap.
  - `RoadSurfaceProfile`: shared terrain-surface raise, visual road clearance, and terrain-aligned render sampling reused by terrain stamping and road rendering.
  - `WorldTerrainMasks`: road corridor widths, shortcut-risk analysis, and terrain influence radii without physical off-road barrier shaping.
  - `WorldConflictUtils`: shared road, preserved-road, river, parcel, and access-corridor conflict checks reused by planners and audits.
  - `POIParcelPlanner`: size or access-aware POI parcel scoring and paced placement across both sides of the route, including `RoadEdge`, `DriveUp`, and `WalkUp`, while yielding to both the main loop and preserved secondary roads.
  - `BranchPlanner`: network-road descriptor builder that samples and fits every preserved secondary-road segment so terrain, previews, and audits all consume the same authoritative secondary-road descriptors.
  - `RoadRenderBuilder`: shared road render orchestrator used by server and client; delegates all EditableMesh lifecycle and mesh validation to the global shared geometry utilities.
  - `WorldSerialization`: compact fixed-point road-network transport plus JSON descriptors for landforms and POIs replicated to clients or stored for debug.
- `src/shared/Geometry`
  - `GeometryDirections`: named `Top`/`Bottom`/`Front`/`Back`/`Left`/`Right` direction contract for geometry helpers.
  - `MeshValidation`: reusable chunk validation for triangle indices, degeneracy, and outward-facing normals.
  - `EditableMeshBuilder`: one global wrapper around EditableMesh creation, fixed-size conversion, mesh-part creation, and cleanup.
  - `MeshShapePrimitives`: reusable validated mesh-shape builders that keep winding and facing validation in one contract.
- `src/server/WorldGen`
  - `WorldGenService`: root lifecycle, `Heartbeat`-driven phase orchestration, replicated loading-status publication, debug summary publication, and start-marker publication.
  - `TerrainBuilder`: landform sampling plus voxel terrain stamping with `ReadVoxels`/`WriteVoxels`, raised roadbeds, contextual roadside blending, parcel flattening, intersection widening and flattening, river water fills, and resumable chunk-by-chunk terrain application.
  - `LandformPreviewBuilder`: visible river, bank, ridge, and basin preview markers for Studio inspection.
  - `POIPreviewBuilder`: development pad, reserve, apron, path, and road-edge preview slabs positioned above final terrain.
  - `WorldGenAudit`: post-terrain audit checks for main-road self-intersections, corridor conflicts, and buried previews.
  - `WorldPlacement`: RV start placement plus right-side player and respawn placement while the current world is active.
  - `FailedLoopPreviewBuilder`: failed path-generation preview for the best rejected loop candidate, its anchor polygon, and failure markers.
- `src/client/WorldGen`
  - `WorldGenClientRenderer`: consumes the replicated compact road-network descriptor and rebuilds the local loop, secondary-road, and intersection overlay from the same shared builder the server uses.
  - `WorldGenBootstrap.client.luau`: attaches the client renderer to generated roots as they appear.

## Root structure
- Studio uses `Workspace.WorldGenPreview`.
- Runtime uses `Workspace.GeneratedWorld`.
- Replicated loading state lives at `ReplicatedStorage.DeadCampWorldGenStatus`.
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
- Loading-status attributes:
  - `IsLoading`
  - `HasWorld`
  - `LoadPhase`
  - `LoadProgress`
  - `LoadError`
  - `WorldProfileId`
  - `WorldSeed`
  - `WorldPhaseCompleted`

## Phase order
1. `LandIntent`
   - Generate the shared `LandformDescriptor`: an optional river spline, `1-2` ridge or hillside spines, one basin or shelf field, and low-frequency height-noise settings.
2. `Path`
   - Generate a full planar road network, select one non-self-crossing primary course that uses the square footprint well, preserve the remaining secondary roads, then fit heights and publish the sampled-loop contract for downstream systems.
3. `POIs`
   - Score and place paced POI parcels across both sides of the route, choosing between `RoadEdge`, `DriveUp`, and `WalkUp` while rejecting conflicts against the main loop, preserved secondary roads, and reserved corridors before terrain stamping.
4. `Branches`
   - Publish the already-sampled preserved secondary-road descriptors into the authoritative road-network payload so rendering, terrain shaping, and audits all consume the same preserved-road data.
5. `Terrain`
   - Sample the final landform field, stamp roadbeds and shoulders, flatten POI pads, blend access corridors, shape contextual cut or fill shoulders, and fill river water voxels when hydrology is enabled.
6. `Hooks`
   - Publish the world start marker, debug descriptors, reject summaries, preview geometry, and audit summary for Studio inspection and RV or player placement.

## Incremental execution
- Startup and debug-triggered world generation now run through one active `Heartbeat` job instead of one blocking `generateAll()` call.
- The planner and layout phases still execute as coherent steps, but terrain application is explicitly resumable and advances one chunk at a time within a bounded per-frame server budget.
- The generated root is still published only after the selected build finishes, while the separate replicated status folder tells clients whether the server is still loading or failed before a root existed.
- The async runner is single-flight: only one job step executes at a time, final root assembly runs as a one-shot finalize task outside the repeating `Heartbeat`, and server output logs phase transitions plus completion or failure.

## Determinism and descriptors
- Every generation run is keyed by `WorldProfileId` and explicit `WorldSeed`.
- The server serializes:
  - the landform descriptor
  - the fitted road network as a compact fixed-point descriptor containing the main loop plus preserved secondary roads
  - POI parcel descriptors
- The client never invents path geometry; it rebuilds the full visible road network from the same compact road-network descriptor the server uses for its rendered road surfaces.
- Main-loop roads, preserved secondary roads, and dedicated intersection caps all build from one shared road-network render path.
- The road-network render path never calls Roblox EditableMesh APIs directly from worldgen feature code; those calls are centralized in `src/shared/Geometry/EditableMeshBuilder.luau`, and reusable shape helpers carry their own facing validation.
- The shared road sample frame is right-handed: `Right = Tangent x Up`. Consumers that need lateral offsets or turn-inside logic should reuse the shared helpers instead of rebuilding sign conventions locally.

## Conflict model and audits
- `WorldConflictUtils` is the shared conflict surface for main-road, preserved-road, parcel, access-corridor, river-water, and river-bank clearance checks.
- `BranchPlanner`, `POIParcelPlanner`, and `WorldGenAudit` all reuse that same conflict logic instead of duplicating overlap math.
- `WorldGenAudit` currently runs after the terrain phase and rejects worlds that self-intersect the main road, cross protected river corridors, overlap protected corridors with POIs, or bury preview geometry into terrain.

## RV integration
- `Build_RV_BaseCamp.server.luau` generates the world first, then starts the debug service and spawns the RV.
- `WorldGenService.placeRVAtStart(rv)` moves the built RV onto the published start marker before `RVDriveController.attach(rv)` grounds it against the generated terrain.
- `WorldPlacement` resolves the right-side exterior entry from the tagged door part, validates the drop point, places current players after drive attachment, and reapplies on `CharacterAdded` while the current world and RV remain active.
