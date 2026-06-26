# Tooling and Validation

Status: `implemented`

## Purpose

Support fast iteration on the RV and world by keeping preview, spawn, drive, and validation flows easy to rerun and consistent with the local Rojo source of truth.

## What exists now

- The repo has a build entrypoint, a Studio debug panel, shared debug action config, and server orchestration for spawn, drive, and world-generation actions.
- The Studio debug panel bootstrap is resilient to startup worldgen failure, so the remote and panel can still be used for manual retries and diagnostics.
- Failed worldgen startup now leaves behind a visible failed-loop preview under the Studio world root so geometry problems can be inspected visually instead of only through log text.
- Local `src` is the source of truth, while Roblox Studio is the place to validate the synced result.
- Shared mesh generation now has one global `src/shared/Geometry` contract that owns EditableMesh creation, fixed-size conversion, cleanup, and outward-normal validation before Studio visual review.
- Worldgen road surfaces now go through a dedicated deterministic `src/shared/WorldGen/RoadMeshBuilder.luau` path before those shared geometry validation and mesh-build steps, instead of depending on a generic ribbon primitive to recover bad winding late.
- Worldgen road-mesh diagnostics are available behind `WorldConstants.DebugFlags.RoadRenderMeshDiagnostics` so richer ribbon-triangulation context can be enabled only while chasing mesh-build failures.
- World generation already has implementation and validation docs, and the runtime path already builds the world before spawning the RV.

## What does not exist yet

- No single cross-system smoke-test harness exists yet for future gameplay systems like survival, inventory, encounters, or progression.
- No formal automated regression suite exists yet outside repo-local build and Studio validation flows.

## Repo workflow

- Prefer local edits under `src` and let Rojo sync them into Studio.
- Use Studio as a runtime validation target, not the source of truth for durable code changes.
- Studio-only inspection experiments are acceptable when needed, but copy any lasting change back into `src`.

## Validation workflow

- After local source edits, run `rojo sourcemap default.project.json --output NUL` when practical.
- Also run `rojo build default.project.json --output %TEMP%\DeadCamp_rojo_validate.rbxlx` when practical to confirm the place still builds cleanly.
- When validating changed ModuleScripts in Studio, avoid stale `require` cache behavior by cloning the synced module tree and requiring modules from the clone.
- If validation depends on changed shared modules, clone `game.ReplicatedStorage.Shared`, temporarily swap the clone in as `Shared`, run validation, then restore the original folder.
- Prefer programmatic smoke checks over visual guessing: inspect expected child names, classes, sizes, positions, `CFrame` vectors, attributes, clear openings, and CSG fallback folders such as `_Ununioned` or `_Unsubtracted`.

## Shared mesh contract

- All generated meshes must use the shared `src/shared/Geometry` modules instead of calling `AssetService` mesh APIs directly from feature code.
- `EditableMeshBuilder` owns `CreateEditableMesh`, optional fixed-size conversion through `CreateEditableMeshAsync(..., { FixedSize = true })`, `CreateMeshPartAsync`, cleanup for temporary editable mesh objects, and the final shared winding-canonicalization step before validation and mesh build.
- `MeshShapePrimitives` owns reusable shape builders such as top-facing or bottom-facing caps and frame-driven ribbon strips. Callers pass named intent like `Top` or `Bottom`; they do not supply raw triangle winding.
- `MeshValidation` must run before a mesh part is produced. It resolves each chunk's declared facing contract for canonical winding, then fails fast on bad triangle indices, degenerate geometry, or normals that still point the wrong way for that declared facing.
- If a shared mesh helper needs deeper failure context, keep that extra detail behind an explicit switch rather than making every normal validation error noisy by default.
- Mesh-generation failures must stop the owning process and report the error; they must not silently degrade to substitute `Part` output.
- Visual Studio review is still required, but it is the final check after programmatic normal validation, not the first line of defense.

## Common Studio targets

- `game.Workspace.WorldGenPreview`
- `game.Workspace.GeneratedWorld`
- `game.Workspace.RV_BaseCamp_RepairCandidate`
- `game.ServerScriptService.Server.Build_RV_BaseCamp`
- `game.ServerScriptService.Server.RVBuilder`
- `game.ServerScriptService.Server.WorldGen.WorldGenService`
- `game.ServerScriptService.Server.RVDebugPanelService`
- `game.ReplicatedStorage.Shared.WorldGen`
- `game.ReplicatedStorage.Shared.RVDebugPanelConfig`
- `game.ReplicatedStorage.DeadCampDebug.RVDebugCommand`

## Key files

- `src/server/Build_RV_BaseCamp.server.luau`
- `src/server/RVDebugPanelService.luau`
- `src/shared/RVDebugPanelConfig.luau`
- `src/shared/Geometry/EditableMeshBuilder.luau`
- `src/shared/Geometry/MeshShapePrimitives.luau`
- `src/shared/Geometry/MeshValidation.luau`
- `src/shared/WorldGen/RoadMeshBuilder.luau`
- `src/shared/Geometry/PartOrientation.luau`
- `src/client/RVDebugPanel.client.luau`
- `src/server/WorldGen/WorldGenService.luau`
- `docs/worldgen/validation-playbook.md`
- `AGENTS.md`

## Dependencies

- `Vehicle Platform` and `World Generation`, since those are the current runtime systems being validated.
- Future gameplay systems should plug into these flows instead of inventing isolated debug entrypoints.
