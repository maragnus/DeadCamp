# Tooling and Validation

Status: `implemented`

## Purpose

Support fast iteration on the RV and world by keeping preview, spawn, drive, and validation flows easy to rerun and consistent with the local Rojo source of truth.

## What exists now

- The repo has a build entrypoint, a Studio debug panel, shared debug action config, and server orchestration for spawn, drive, and world-generation actions.
- The Studio debug panel bootstrap is resilient to startup worldgen failure, so the remote and panel can still be used for manual retries and diagnostics.
- Failed worldgen startup now leaves behind a visible failed-loop preview under the Studio world root so geometry problems can be inspected visually instead of only through log text.
- Local `src` is the source of truth, while Roblox Studio is the place to validate the synced result.
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
- `src/client/RVDebugPanel.client.luau`
- `src/server/WorldGen/WorldGenService.luau`
- `docs/worldgen/validation-playbook.md`
- `AGENTS.md`

## Dependencies

- `Vehicle Platform` and `World Generation`, since those are the current runtime systems being validated.
- Future gameplay systems should plug into these flows instead of inventing isolated debug entrypoints.
