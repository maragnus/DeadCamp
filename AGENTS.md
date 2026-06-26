# Dead Camp (Roblox Experience)

A co-op Roblox survival road-trip game where players escape a zombie outbreak in an RV, scavenging campsites, gas stations, ranger stations, farms, and abandoned towns while defending the vehicle from hordes at night.

## Game Systems

Status legend:
- `planned`: design intent only; no durable runtime implementation or scaffold yet.
- `scaffolded`: repo structure, preview code, or partial runtime hooks exist, but the player-facing system is still incomplete.
- `implemented`: a usable foundation exists in the active repo and participates in the current build or runtime flow.

Keep this section in sync with `docs/systems/README.md` and the matching docs under `docs/systems/`.

- `Vehicle Platform` (`implemented`): modular RV construction, RV driving, passenger support, and vehicle runtime foundations. Docs: `docs/systems/vehicle-platform.md`
- `World Generation` (`scaffolded`): seeded `LandIntent -> Path -> POIs -> Branches -> Terrain -> Hooks` world builds with optional river-aware landforms, an HTML-derived graph road network with one primary loop plus preserved secondary roads, conflict-aware POI and branch planning, terrain shaping, debug previews, RV start placement, and right-side player placement hooks. Docs: `docs/systems/world-generation.md`, `docs/worldgen/architecture.md`
- `Run Planning and Economy` (`planned`): resource pressure, loot seeding, POI reward pacing, checkpoint cadence, and sell or upgrade balance. Docs: `docs/systems/run-planning-and-economy.md`
- `Round Gameplay` (`planned`): round rules, survival needs, inventory, looting, repair, crafting, checkpoints, and service interactions. Docs: `docs/systems/round-gameplay.md`
- `Encounters` (`planned`): zombies, hordes, combat, barricades, random events, and defensive tools. Docs: `docs/systems/encounters.md`
- `Meta Progression` (`planned`): save data, RV unlocks, decoration, cosmetics, and long-term progression. Docs: `docs/systems/meta-progression.md`
- `Tooling and Validation` (`implemented`): debug actions, Rojo validation, preview flows, and deterministic smoke-check helpers. Docs: `docs/systems/tooling-and-validation.md`

## Non-Negotiable Rules

- NEVER degrade silently or degrade at all. If a process fails for any reason, stop and report the error instead of falling back to substitute behavior or creating a workaround.
- And if there is an exception that is user approved, it MUST be logged as a warning.
- ALWAYS answer user questions without making code changes if the message contains a question. Also, "audit" means investigation and explanation, not code changes.
- ALWAYS treat a user-presented issue, bug report, performance complaint, unexpected behavior report, or concern as a request for diagnosis and understanding first, not permission to immediately edit code. Investigate, explain the likely root cause, outline options, and wait for an explicit request to implement before making changes.
- ALWAYS ask before removing or degrading user-facing behavior. NEVER assume feature removal is acceptable.
- ALWAYS ask when requirements are ambiguous or you are uncertain.
- NEVER make code changes from low-confidence analysis. If confidence is low, report what was found, identify the uncertainty, and ask before editing unless the user explicitly asked for that exact change.
- ALWAYS treat assumptions as dangerous, especially for behavior, configuration, model/runtime capabilities, source freshness, and product defaults. If a decision could reasonably belong in configuration or materially change behavior, ask or make it explicitly configurable instead of hard-coding the assumption.
- NEVER make speculative fixes for bugs. If the root cause is not proven, investigate, add targeted diagnostics when useful, and ask before changing behavior.
- ALWAYS fix root causes. NEVER patch symptoms.
- DRY (Don't Repeat Yourself) is the core rule. It is critical that we reuse and repurpose code to make sure that we create a codebase that is easy to understand and maintain. Always find the DRYest way to accomplish a goal, and find or create utility methods that simplify tasks.
- DRY example: create a method that creates Parts based on a bounding box, instead of Center and Size, which is complex and prone to error.
- DRY example: use constants to avoid magic numbers and strings
- This repository is the source of truth always and files are stored locally because Roblox Studio is not stable and tends to crash or revert changes.
- Rojo is available and `src` is safe to edit. Prefer local file edits under `src` and let Rojo sync them into Roblox Studio.
- Use `default.project.json` as the Rojo mapping source:
  - `src/server` syncs to `game.ServerScriptService.Server`
  - `src/shared` syncs to `game.ReplicatedStorage.Shared`
  - `src/client` syncs to `game.StarterPlayer.StarterPlayerScripts.Client`
- For server runtime code, create `*.server.luau` files under `src/server`.
- For shared modules, create `*.luau` files under `src/shared` and require them through `game:GetService("ReplicatedStorage"):WaitForChild("Shared")`.
- Use Roblox Studio MCP for inspection and runtime execution when needed, but do not use it as the primary source of code truth while Rojo is running.

## Shared Geometry and Mesh Conventions

- Any generated mesh must go through the shared `src/shared/Geometry` utilities. Do not call `AssetService:CreateEditableMesh`, `CreateEditableMeshAsync`, or `CreateMeshPartAsync` outside that layer.
- Do not hand-roll triangle winding, fallback primitive rotations, or other orientation-sensitive mesh details at feature call sites. Add or reuse a named helper in `src/shared/Geometry` first.
- Reusable mesh helpers must define mesh winding and validation from the same shape contract so orientation cannot drift.
- Declare `ExpectedFacing` or `ExpectedNormal` on orientation-sensitive chunks and let shared geometry canonicalize triangle winding from that contract before validation or mesh build.
- Every orientation-sensitive mesh helper must validate its outward-facing normal in code before Studio visual review. Prefer named directions like `Top`, `Bottom`, `Front`, `Back`, `Left`, and `Right` over sign guessing.
- Detailed shared-mesh workflow and validation expectations live in `docs/systems/tooling-and-validation.md`.
- Leave verbose road-mesh diagnostics behind `src/shared/WorldGen/WorldConstants.luau` `DebugFlags.RoadRenderMeshDiagnostics` unless you are actively investigating a mesh-build failure.

## Vehicle Geometry Conventions

- When editing generated RV geometry, use `RVBounds` for placement and `RVShapePrimitives` for wedges or cylinders. Do not hand-roll `center` and `size` math or primitive rotations at call sites.
- `src/server/RVBuilder/ModelBuilder.luau` CSG helpers are fail-fast. If a union or subtract operation fails, surface the error; do not leave backup geometry or degraded substitutes in the build.
- Coordinate convention: `X = width`, `Y = height`, `Z = length`, and negative `Z` is vehicle front.
- RV-specific primitive, slope-face, cylinder-axis, and wheel-well conventions live in `docs/systems/vehicle-platform.md`. Shared mesh work belongs in `src/shared/Geometry`.

## RV Base Camp

- The RV is a modular vehicle that serves as the player base camp.
- It should remain plan-driven, support swappable sections, and stay extensible to layouts such as Class-C and Class-A motorhomes.
- One player drives while other players can move about the vehicle; that moving-interior contract affects both builder and runtime systems.
- Current section inventory, reference-build details, and vehicle-specific design constraints live in `docs/systems/vehicle-platform.md`.

## Rojo and Studio Workflow

- Local `src` is the source of truth; Roblox Studio is a validation target.
- Prefer Rojo-local edits and copy any Studio-only inspection experiment back into `src`.
- Run `rojo sourcemap default.project.json --output NUL` and `rojo build default.project.json --output %TEMP%\DeadCamp_rojo_validate.rbxlx` when practical.
- When validating changed ModuleScripts in Studio, avoid stale `require` caches by running against cloned synced module trees.
- Prefer programmatic smoke checks over visual guesses. Detailed validation steps, cache-refresh workflow, and common Studio targets live in `docs/systems/tooling-and-validation.md`.

## AGENTS Maintenance

- Keep entries short. State what it does and when to use it. Skip changelog, rationale, and implementation detail unless needed for safe use.
- Keep `## Game Systems`, `docs/systems/README.md`, and the matching `docs/systems/*.md` file in sync. Every system doc should carry exactly one status: `planned`, `scaffolded`, or `implemented`.
- When system scope changes, update the owning system doc's `What exists now`, `What does not exist yet`, and `Key files` sections in the same change.
- Prefer adding detail to the matching system doc instead of growing `AGENTS.md` with long design prose. `AGENTS.md` should stay the index.
- If a section starts accumulating subsystem-specific inventories, geometry directives, or step-by-step validation procedures, move that detail into the owning `docs/systems/*.md` file and leave a short pointer in `AGENTS.md`.
- Any add/remove/change to a shared utility, shared enum, common constant, plan shape, or other reused builder API must update the owning system doc and any repo-wide `AGENTS.md` pointer in the same change.
- Large-file watchlist: `src/server/RVBuilder/Assemblies.luau`, `src/server/RVBuilder/ClassCCabBuilder.luau`. If scope grows there, suggest a logical split before or with the change.

## Core Entry Points

- `docs/systems/README.md`: system status index and links to dedicated docs.
- `src/server/Build_RV_BaseCamp.server.luau`: build entrypoint. Generates the world, starts the debug panel service, and spawns the RV.
- `src/server/RVBuilder/VehicleBuilder.luau`: top-level RV build orchestration. See `docs/systems/vehicle-platform.md` for the fuller vehicle file map.
- `src/server/RVBuilder/Plans/BaseCamp.luau`: default RV plans and section layout.
- `src/server/WorldGen/WorldGenService.luau`: world-generation lifecycle, `LandIntent -> Path -> POIs -> Branches -> Terrain -> Hooks` orchestration, failed-preview fallback, and RV placement helper. See `docs/worldgen/architecture.md` for the fuller worldgen map.
- `src/server/WorldGen/WorldGenAudit.luau`: world audit checks for main-road self-intersections, branch or parcel corridor conflicts, buried previews, and related debug summaries.
- `src/server/WorldGen/WorldPlacement.luau`: RV start placement plus right-side player drop and respawn placement while a generated world is active.
- `src/server/WorldGen/FailedLoopPreviewBuilder.luau`: failed-loop visualization for the best rejected road candidate, anchors, and failure markers.
- `src/server/RVDebugPanelService.luau`: debug spawn, drive, and world-generation action orchestrator.
- `src/shared/RVDebugPanelConfig.luau`: shared debug action definitions and remote config.
- `src/shared/WorldGen/LandformPlanner.luau`: coarse land-intent planner for river, ridges, basin, and base heightfield sampling.
- `src/shared/WorldGen/Hydrology.luau`: optional river corridor generation and runtime river sampling.
- `src/shared/WorldGen/RoadLoopSettings.luau`: resolved path-planner defaults and shared tuning derived from `WorldProfile.PathPlanner`.
- `src/shared/WorldGen/RoadLoopGraphPlanner.luau`: HTML-derived road-network planner that selects one primary loop from a planar network and preserves secondary-road metadata for branch reuse.
- `src/shared/WorldGen/RoadLoopDiagnostics.luau`: shared loop self-intersection diagnostics, footprint metrics, scenic telemetry, and shortcut hotspot analysis.
- `src/shared/WorldGen/RoadLoopAttemptRanker.luau`: rejected-attempt ranking plus failure-summary formatting.
- `src/shared/WorldGen/RoadJunctionBuilder.luau`: shared degree-based road-junction sizing and entry reconstruction reused by terrain shaping and visible intersection surfaces.
- `src/shared/WorldGen/RoadMeshBuilder.luau`: deterministic road-surface mesh builder that extrudes road quads from centerline positions, picks the most top-stable split per quad, and only then chunks.
- `src/shared/WorldGen/RoadNetworkBuilder.luau`: shared server and client road-network renderer that rebuilds loop, preserved secondary-road, and intersection surfaces from one compact deterministic road-network descriptor.
- `src/shared/WorldGen/RoadSurfaceProfile.luau`: shared roadbed raise, visual clearance, and terrain-aligned render sampling for road and terrain alignment.
- `src/shared/WorldGen/WorldConflictUtils.luau`: shared road, branch, parcel, and river-clearance conflict checks reused across planners and audits.
- `src/shared/Geometry/EditableMeshBuilder.luau`: global EditableMesh lifecycle wrapper with fixed-size conversion, cleanup, and chunk validation.
- `src/shared/Geometry/MeshShapePrimitives.luau`: global named mesh-shape helpers that own cap and ribbon winding, facing, and validation contracts.
- `src/shared/Geometry/MeshValidation.luau`: global mesh chunk validation plus declared-facing helpers reused to canonicalize triangle winding before mesh build.
- `src/shared/RVBounds.luau`: bounds source of truth for generated RV geometry.
- `src/shared/RVShapePrimitives.luau`: primitive orientation source of truth for generated RV wedges and cylinders.
- `src/shared/DeadCampCollisionGroups.luau`: shared collision-group names across vehicle and world systems.

## Common Objects

- `game.Workspace.WorldGenPreview`: Studio world-generation root.
- `game.Workspace.GeneratedWorld`: runtime world-generation root.
- `game.Workspace.RV_BaseCamp_RepairCandidate`: generated validation RV model.
- `game.ServerScriptService.Server.Build_RV_BaseCamp`: Rojo-synced build entrypoint.
- `game.ServerScriptService.Server.RVBuilder`: Rojo-synced RV builder module root.
- `game.ServerScriptService.Server.WorldGen.WorldGenService`: world-generation pipeline orchestrator.
- `game.ServerScriptService.Server.RVDebugPanelService`: debug action orchestrator.
- `game.ReplicatedStorage.Shared.WorldGen`: shared world-generation module root.
- `game.ReplicatedStorage.Shared.RVDebugPanelConfig`: shared debug action config.
- `game.ReplicatedStorage.DeadCampDebug.RVDebugCommand`: Studio debug remote event.
