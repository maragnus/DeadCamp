# WorldGen Validation Playbook

## Baseline local check
1. Run:
   ```powershell
   rojo sourcemap default.project.json --output NUL
   rojo build default.project.json --output "$env:TEMP\DeadCamp-rojo-build.rbxlx"
   ```
2. Open the synced place in Studio and start `rojo serve`.

## Studio workflow
1. Let `Build_RV_BaseCamp.server.luau` generate the default world and RV on startup.
   - If startup world generation fails, the debug panel should still load and the output should include a reject-count summary from `RoadLoop.generate`.
   - A failed startup should still leave `Workspace.WorldGenPreview.Debug.FailedLoopPreview` with the best rejected attempt visualized.
2. Use the debug panel to rerun:
   - `Generate Land Intent`
   - `Generate Path`
   - `Generate POIs`
   - `Generate Branches`
   - `Generate Terrain`
   - `Generate World All`
   - `Audit World Seeds`
   - `Destroy World`
3. Confirm the active root is `Workspace.WorldGenPreview`.
4. Confirm the active root is a `Folder`, not a `Model`.
5. Confirm the root attributes match the expected profile id, seed, build version, sample count, and completed phase.

## Descriptor checks
- `Landforms/LandformDescriptor` exists and decodes.
- `Road/RoadNetworkDescriptor` exists and decodes.
- `Road/RoadNetworkDescriptor` exists as the compact transport copy of the authoritative road network, carrying quantized sample positions and only the metadata needed for deterministic client reconstruction.
- `POIs/POIParcelDescriptor` exists after the POI phase.
- `Debug/WorldAuditSummary` exists after the terrain phase and reads `World audit passed` for accepted seeds.
- `Debug/POIRejects` and `Debug/BranchRejects` are available when the planners reject candidates.

## Land intent and terrain checks
- Each accepted world has one visible river with readable centerline and bank debug markers under `Landforms`.
- The main road, branches, and POI access corridors do not cross river water or the bank-clearance band.
- Road surface sits slightly proud of the terrain instead of sinking into it.
- Road surface and shoulders are visibly smoother than the surrounding terrain, but the terrain does not repeat the old full-length ditch pattern.
- The terrain reads as contextual shoulders and cut or fill blending rather than anti-shortcut walls or hotspot barricades.
- Intersections are visibly wider and flatter than ordinary road segments instead of pinching into the surrounding grade.
- POI pads are visibly flattened, and preview pads, reserves, aprons, and paths sit at least slightly above final terrain instead of clipping into it.
- Preserved secondary roads blend into the terrain instead of floating above it.

## Road geometry checks
- `RoadSurface` stays as one mesh when the road is `<=256` studs long and otherwise splits into seamless sections no longer than `256` studs of centerline length.
- No road section exceeds `256` studs of path length.
- Client and server road renders align sample-for-sample with no visible offset at section boundaries because the server renders from the authoritative in-memory network and both sides rebuild road-surface offsets deterministically from the same transported centerline positions.
- `LoopChunk` and preserved secondary-road chunks stay slightly above the stamped roadbed instead of sinking into it.
- Dedicated intersection caps render as visible rounded paved surfaces instead of relying on terrain flattening alone to imply the junction.
- Dedicated intersection caps face upward, and any reusable mesh helper should already fail fast in code if its declared outward normal points the wrong way before Studio visual review.
- If a road mesh still fails to validate, turn on `WorldConstants.DebugFlags.RoadRenderMeshDiagnostics` first so the failure includes chunk-level ribbon triangulation context instead of broadening the default log noise for every run.
- The main path is tinted green during testing so it is immediately distinguishable from the rest of the network.
- The accepted loop makes visible use of the square footprint instead of hovering near a circular center-only route or collapsing into a wavy square.
- The drive includes meaningful center use, but that center use reads as natural inward movement rather than one forced deep jab.
- The route feels flowy and road-like, with broad sweeps and no obvious hairpins or long flat box sides.

## POI and secondary-road checks
- Close `RoadEdge` POIs can hug the shoulder without repainting asphalt or crossing into the road corridor.
- `DriveUp` aprons and `WalkUp` paths start at the shoulder edge and stop at the parcel; they do not cross roads or river space.
- Every preserved secondary road from the accepted network renders as a visible road from the same authoritative road-network surface path as the main loop.
- Secondary-road entrances and internal junctions read as intentional widened intersections instead of narrow pinches or terrain tears.

## RV checks
- The RV spawns on the published start marker instead of at origin.
- `RVDriveController.attach(rv)` grounds the RV without tunneling or hovering.
- Current players appear beside the RV's right-side exterior entry instead of inside the vehicle or below terrain.
- Respawned characters also reappear beside the RV while the generated world and RV remain active.
- The RV can drive forward along the road without immediately requiring an off-road barrier to stay on course.

## Fixed-seed sweep
- `Audit World Seeds` should pass the current seed list:
  - `7402048`
  - `7402049`
  - `7402065`
  - `7402149`
  - `7402551`
- If the sweep fails, the current generated root should correspond to the failing seed so the visible previews and audit summary explain the failure.

## Cache-safe runtime checks
- If Studio appears stale, clone the synced `ServerScriptService.Server` and `ReplicatedStorage.Shared` trees before requiring changed modules.
- Validate from the clone instead of trusting already-required module tables.

## Failure diagnostics
- `RoadLoop.generate` failures should report reject counts for planner generation and self-intersection failures, plus sample attempt summaries.
- If the first startup world generation fails, `ReplicatedStorage.DeadCampDebug.RVDebugCommand` should still exist so the debug panel can retry generation manually.
- The failed preview should include the sampled loop, the anchor polygon, a start marker, and markers for the first detected self-intersection when present.
- The failed preview should render at a readable debug height above existing terrain so prior terrain stamps do not bury the sampled loop.
- POI or branch planner failures should leave reject reasons in `Debug/POIRejects` or `Debug/BranchRejects`.

## Known runtime behavior
- If mesh APIs are unavailable, road rendering fails fast and reports the mesh-build error instead of degrading to substitute strip parts.
- Client road overlay is enabled by default in Studio and disabled by default at runtime through `EnableClientRoadOverlay`.
- Bridge generation is intentionally out of scope for this pass; candidates that would require a crossing must be rejected and retried instead.
