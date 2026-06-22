# WorldGen Validation Playbook

## Baseline local check
1. Run:
   ```powershell
   rojo build default.project.json --output "$env:TEMP\DeadCamp-rojo-build.rbxlx"
   ```
2. Open the synced place in Studio and start `rojo serve`.

## Studio workflow
1. Let `Build_RV_BaseCamp.server.luau` generate the default world and RV on startup.
   - If startup world generation fails, the debug panel should still load and the output should include a reject-count summary from `RoadLoop.generate`.
   - A failed startup should still leave `Workspace.WorldGenPreview.Debug.FailedLoopPreview` with the best rejected attempt visualized.
2. Use the debug panel to rerun:
   - `Generate Path`
   - `Generate Terrain`
   - `Generate POIs`
   - `Generate Branches`
   - `Generate World All`
   - `Destroy World`
3. Confirm the active root is `Workspace.WorldGenPreview`.
4. Confirm the active root is a `Folder`, not a `Model`.
5. Confirm the root attributes match the expected profile id, seed, build version, sample count, and completed phase.

## Descriptor checks
- `Road/RoadLoopDescriptor` exists and decodes.
- `Road/RoadLoopDescriptor` stays well below Roblox `StringValue` limits because it uses the compact quantized sample transport instead of a full ribbon JSON blob.
- `POIs/POIParcelDescriptor` exists after the POI phase.
- `Branches/BranchDescriptor` exists after the branch phase.

## Terrain checks
- Road surface and shoulders are visibly smoother than the surrounding terrain.
- Shortcut hotspot areas become smaller hills or valleys that block the RV without looking like artificial walls.
- POI pads are visibly flattened.
- Branch roads blend into the terrain instead of floating above it.

## Road geometry checks
- `RoadSurface` is split into seamless chunk pieces rather than one oversized mesh.
- No chunk exceeds the intended `128x128` footprint budget.
- Client and server road renders align sample-for-sample with no visible offset at chunk boundaries because both rebuild from the same compact loop descriptor.

## RV checks
- The RV spawns on the published start marker instead of at origin.
- `RVDriveController.attach(rv)` grounds the RV without tunneling or hovering.
- The RV can drive forward along the road without immediately entering a barrier band.

## Cache-safe runtime checks
- If Studio appears stale, clone the synced `ServerScriptService.Server` and `ReplicatedStorage.Shared` trees before requiring changed modules.
- Validate from the clone instead of trusting already-required module tables.

## Failure diagnostics
- `RoadLoop.generate` failures should report reject counts for bounds, self-intersections, and curve radius, plus sample attempt summaries.
- If the first startup world generation fails, `ReplicatedStorage.DeadCampDebug.RVDebugCommand` should still exist so the debug panel can retry generation manually.
- The failed preview should include the sampled loop, the anchor polygon, a start marker, and markers for the first detected self-intersection or minimum-radius point when present.
- The failed preview should render at a readable debug height above existing terrain so prior terrain stamps do not bury the sampled loop.

## Known fallback behavior
- If mesh APIs are unavailable, road rendering falls back to anchored strip parts rebuilt from the same compact loop descriptor.
- Client road overlay is enabled by default in Studio and disabled by default at runtime through `EnableClientRoadOverlay`.
