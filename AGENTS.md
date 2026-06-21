# Dead Camp (Roblox Experience)

A co-op Roblox survival road-trip game where players escape a zombie outbreak in an RV, scavenging campsites, gas stations, ranger stations, farms, and abandoned towns while defending the vehicle from hordes at night.

# Rules

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

# Roblox Primitive Orientation

- Use `RVShapePrimitives` for `WedgePart` and `Enum.PartType.Cylinder` creation. Do not hand-roll `CFrame.Angles` for these primitive rotations at call sites.
- In Rojo source, `RVShapePrimitives` lives at `src/shared/RVShapePrimitives.luau`.
- Coordinate convention: `X = width`, `Y = height`, `Z = length`, and negative `Z` is vehicle front.
- Use `RVBounds` for placement. Do not place generated geometry by manually pairing `center` and `size` at call sites.
- In Rojo source, `RVBounds` lives at `src/shared/RVBounds.luau`.
- Describe generated geometry with `bounds(x0, x1, y0, y1, z0, z1)`, then let helpers derive `Size` and `CFrame`.
- `part(parent, name, bounds(...), style, optionalRotation)`, `wedge(parent, name, bounds(...), slopeFace, style)`, and `cylinder(parent, name, bounds(...), axis, style, optionalTilt)` are the preferred builder primitives.
- Wedge convention: `ShapePrimitives.WedgeSlopeFace.TopFront` matches the reference `Workspace.Wedge`: triangular side visible on the right, flat bottom, vertical back, and the diagonal face between top/front.
- Use `ShapePrimitives.WedgeSlopeFace.TopLeft`, `TopFront`, `TopRight`, `TopBack`, `BottomLeft`, `BottomFront`, `BottomRight`, or `BottomBack` to describe the diagonal wedge face direction.
- Use `ShapePrimitives.WedgeSolidCorner` only when describing the box corner that should remain solid, then convert it with `ShapePrimitives.wedgeSlopeFaceForSolidCorner`.
- Use `ShapePrimitives.wheelWellCornerSlopeFace(edge)` for wheel-well corner wedges instead of duplicating front/back rotation logic.
- Cylinder convention: Roblox cylinders run along their local height axis before rotation. Use `ShapePrimitives.CylinderAxis.Width`, `Height`, or `Length` to say which vehicle axis the cylinder occupies inside the provided bounds.
- If a cylinder needs a controlled tilt, pass `{ Toward = ShapePrimitives.Direction.Back, Degrees = 65 }`. If it must match an exact source axis, pass `{ Rotation = someCFrame }` through the helper. Add new tilt cases in `RVShapePrimitives` before using ad hoc `CFrame.Angles`.

# RV Base Camp

The RV is a modular vehicle that serves as the player base camp.

It has interchangable sections and can be extended to any length and represent either a Class-C (engine front) or a Class-A motorhome (engine rear).

One player will drive the RV between points of interest. The other players are free to move about the vehicle, organize and craft while in motion. This require special physics handling as Roblox cannot natively support this.

Key components and features:
- Walkable interior
- Class-C-style Cab section
  - Steering wheel and simple dashboard
  - Driver's seat
  - Passenger seat
  - Hood
  - Engine
  - Front wheels
  - Front bumper
  - Living compartment overhang with rounded front
- Front living section
  - Entry door (usable)
  - Gutted interior (no furniture)
  - Side panels
  - Slightly rounded roof (3 segment)
- Class-C-style Back living section
  - Side and rear windows (subtracted/carved out of walls)
  - Rear wheels
  - Gutted interior (no furniture)
  - Slightly rounded roof (3 segment)
  - Rear wall
  - Ladder
  - Rear bumper
- Wheels
  - Carved wheel wells
  - Wheel box interior
- Exterior lights (headlamps, brakes, blinkers, and markers)

Wheel wells need to be made much more simple: 
1. Divide the wall on either side of the wheel hole.
2. Stop the wall segment above the wheel the top of the wheel.
3. Place a small wedge in the corners to make it feel rounded.
4. Union the wall parts together
5. Box in the inside of the wheel for the vehicle interior.

We probably should have a single function with arguments to support double-wheel or double-axle, so we have a consistent method of creating it.

# Roblox MCP

- Prefer Rojo-local edits in `src`. Use `multi_edit` only for emergency Studio-only patches or inspection experiments that will be copied back into `src`.
- Use `execute_luau` to execute raw Luau code for validation in Studio.
- Keep Studio as a runtime validation target, not the source of truth. Make durable code changes locally under `src`, let Rojo sync them into Studio, then validate in Studio.
- After local source edits, run Rojo validation when practical:
  - `rojo sourcemap default.project.json --output NUL`
  - `rojo build default.project.json --output %TEMP%\DeadCamp_rojo_validate.rbxlx`
- When validating changed ModuleScripts in Studio, avoid Roblox's `require` cache by cloning the relevant Rojo-synced module tree before requiring it:
  - Clone `game.ServerScriptService.Server.RVBuilder` to a temporary sibling such as `RVBuilder_ValidationClone`.
  - Require and run modules from the clone.
  - Destroy the clone after validation.
- If validation depends on changed shared modules, also avoid cached `ReplicatedStorage.Shared` requires:
  - Clone `game.ReplicatedStorage.Shared`.
  - Temporarily rename the original Shared folder, parent the clone as `Shared`, run validation, then restore the original name and destroy the clone.
  - Use this only for validation snippets, not as a durable Studio edit.
- Prefer programmatic Studio smoke checks over visual guessing:
  - Build `game.Workspace.RV_BaseCamp_RepairCandidate` from the cloned builder.
  - Inspect `ClassName`, `Size`, `Position`, `CFrame` vectors, attributes, and expected child names.
  - Use raycasts to verify carved/subtracted openings are actually clear.
  - Check for CSG fallback folders like `_Ununioned` or `_Unsubtracted`.
  - Compare generated parts to known reference objects when orientation matters, such as `game.Workspace.RV_BaseCamp.Generated.RV_BaseCamp.Cab.SteeringWheel`.
- Update "Common Objects" below with a quick access list of commonly used scripts or `Instances`

## AGENTS Maintenance

- Keep entries short. State what it does and when to use it. Skip changelog, rationale, and implementation detail unless needed for safe use.
- Any add/remove/change to a shared utility, shared enum, common constant, plan shape, or other reused builder API must update this `AGENTS.md` section in the same change.
- Large-file watchlist: `src/server/RVBuilder/Assemblies.luau`, `src/server/RVBuilder/ClassCCabBuilder.luau`. If scope grows there, suggest a logical split before or with the change.

## Core Dictionary

- `src/server/Build_RV_BaseCamp.server.luau`: build entrypoint.
- `src/server/RVBuilder/Plans/BaseCamp.luau`: default plans. `classC(overrides?)`, `classA(overrides?)`.
- `src/server/RVBuilder/VehicleBuilder.luau`: full build orchestration. `build(plan)`.
- `src/server/RVBuilder/Constants.luau`: shared builder constants. Top-level: `DefaultScale`, `OutputName`, `VehicleId`, `BuildVersion`, `SteeringWheelSourcePath`, `Colors`. API: `dimensions(scale?)`, `validateDimensions(dimensions)`. Derived dimension keys: `Scale`, `GroundY`, `Width`, `SideWallThickness`, `FloorTop`, `FloorThickness`, `BodyBottom`, `WallTop`, `RoofThickness`, `RoofShoulderRadius`, `ChassisY`, `ChassisHeight`, `ChassisBottom`, `ChassisTop`, `CabHalfWidth`, `CabWallTop`, `CabFenderTop`, `WheelCenterY`, `WheelRadius`, `WheelWidth`, `WheelOuterProtrusion`, `WheelWellClearance`, `WheelTubDepth`, `WheelTubThickness`, `WheelWellCorner`, `DualWheelSpacing`, `GlassThickness`, `TrimThickness`.
- `src/server/RVBuilder/Layout.luau`: plan fractions to absolute Z. `resolve(plan)`, `localZ(section, fraction)`, `localSpan(section, z0Fraction, z1Fraction)`. `GeometryLength` keeps authored local fractions when section seam length differs.
- `src/shared/RVBounds.luau`: bounds source of truth. `new(x0, x1, y0, y1, z0, z1)`, `center(bounds)`, `size(bounds)`, `isValid(bounds)`, `cframe(bounds, rotation?)`, `offset(bounds, dx, dy, dz)`.
- `src/shared/RVShapePrimitives.luau`: wedge/cylinder orientation source of truth. Enums: `Direction`, `WedgeSlopeFace`, `WedgeSolidCorner`, `CylinderAxis`. API: `pitchToward(toward, degrees?)`, `wedgeSlopeFaceForSolidCorner(solidCorner)`, `wedgeCFrameFromBounds(bounds, slopeFace, rotation?)`, `cylinderCFrameFromBounds(bounds, axis, orientation?)`, `wheelWellCornerSlopeFace(edge)`, `wheelWellCornerSlope(sideOrEdge, maybeEdge?)`, `createWedgeInBounds(parent, name, bounds, slopeFace, configure?, rotation?)`, `createCylinderInBounds(parent, name, bounds, axis, configure?, orientation?)`.
- `src/server/RVBuilder/ModelBuilder.luau`: common instance builder, CSG, and cloning helpers. `destroyExisting(outputName)`, `new(config)`, `color(value)`, `folder(parent, name)`, `style(colorName, overrides?)`, `configure(part, style?)`, `part(parent, name, partBounds, style?, rotation?)`, `wedge(parent, name, partBounds, slopeFace, style?, rotation?)`, `cylinder(parent, name, partBounds, axis, style?, orientation?)`, `prompt(parent, objectText, holdDuration?)`, `tryUnion(parent, name, pieces, meta?)`, `trySubtract(parent, name, source, cutters, meta?)`, `addGlass(parent, name, partBounds, meta?, rotation?)`, `addLight(parent, name, partBounds, lightColor, lightType, meta?)`, `cloneSourceToBounds(sourcePath, parent, name, partBounds, style?, rotation?, options?)`.
- `src/server/RVBuilder/Panels.luau`: side/end wall splitting, side-surface bounds, and wheel-box helpers. `sideName(side)`, `wheelOpening(dimensions, section, group, side)`, `wheelTubInnerHalfWidth(dimensions)`, `sideFlushBounds(dimensions, side, y0, y1, z0, z1, thickness?, options?)`, `sideOutsetBounds(dimensions, side, y0, y1, z0, z1, thickness?, options?)`, `buildSidePanel(builder, parent, name, side, section, openings?, options?)`, `buildEndPanel(builder, parent, name, section, z0, z1, openings?, options?)` with `TopCornerRadius?` or `TopCornerStartY?` for raised center caps, `addWheelTub(builder, parent, well, options?)`.
- `src/server/RVBuilder/RoofProfiles.luau`: shared straight roof span bounds. Use when living roof and cab-cap roof need the same rounded shoulder profile. `shoulderedTopBounds(dimensions, halfWidth, topY, z0, z1)`.
- `src/server/RVBuilder/Assemblies.luau`: shared assemblies and opening transforms. `buildChassis(builder, parent, layout)`, `buildFloor(builder, parent, layout, wheelGroups)`, `buildRoof(builder, parent, section)`, `buildDoor(builder, interactables, glassParent, section, door)`, `buildWheels(builder, parent, wheelGroups)`, `buildBumpers(builder, parent, layout)`, `buildLights(builder, parent, layout, sections)`, `buildLadder(builder, parent, section)`, `connectInteractables(root)`, `absoluteDoor(section, door)`, `absoluteWindow(section, window)`. Shared open/close attrs: `OpenCloseGroupId`, `OpenCloseKind`, `OpenCloseSide`.
- `src/server/RVBuilder/ClassCCabGeometry.luau`: shared Class-C cab measurements and front profile helpers. API: `hoodHalfWidth(dimensions)`, `frontProfile(dimensions)`, `hoodLeadingEdgeBand(profile, hoodDepth)`, `overCabCapHeights(dimensions)`, `windshieldHalfWidth(dimensions)`, `cabWindowBand(dimensions)`, `alignedCabWindowBand(dimensions)`, `sideWallBounds(dimensions, side, y0, y1, z0, z1)`, `windshieldSideBounds(dimensions, side, y0, y1, z0, z1)`, `windshieldSideWindowBounds(sideBounds, cabWindowBand)`, `windshieldSlopeZAtY(sideBounds, y)`, `windshieldGlassBounds(dimensions, sideBounds, cabWindowBand, windshieldTopY)`, `steeringAssembly(dimensions, localZAt)`.
- `src/server/RVBuilder/ModuleBuilders.luau`: section handlers. `buildLiving(builder, folders, section)`, `buildClassCCab(builder, folders, section)`, `buildClassACab(builder, folders, section)`.
- `src/server/RVBuilder/ClassCCabBuilder.luau`: Class-C cab builder. `build(builder, folders, section)`. Internal areas: `buildFrontFace`, `buildHood`, `buildWindshield`, `buildCabin`, `buildOverCabCap`, `buildInterior`.
- Plan fields worth reusing before adding new ones:
  - Plan root: `OutputName`, `VehicleId`, `BuildVersion`, `Scale`, `SteeringWheelSourcePath`, `Modules`.
  - Module: `Id`, `Type`, `Length`, `GeometryLength?`, `PanelColor?`, `Wheels?`, `Windows?`, `Doors?`, `RearWall?`, `Ladder?`, `FeatureY?`.
  - Wheel group: `Id`, `LocalZ`, `AxleCount?`, `SideWheels?`, `AxleSpacing?`, `DualSpacing?`, `Radius?`, `Width?`, `OuterProtrusion?`, `WellClearance?`.
  - Window/Door specs: `Id`, `Side`, `LocalZ0`, `LocalZ1`, `Y0?`, `Y1?`.

## Common Objects

- `game.Workspace.Baseplate`: Baseplate
- `game.Workspace.RV_BaseCamp_RepairCandidate`: generated repair candidate RV model
- `game.ServerScriptService.Server.Build_RV_BaseCamp`: Rojo-synced builder script from `src/server/Build_RV_BaseCamp.server.luau`
- `game.ServerScriptService.Server.RVBuilder`: Rojo-synced modular RV builder modules from `src/server/RVBuilder`
- `game.ServerScriptService.Server.RVBuilder.Constants`: shared builder constants and dimensions
- `game.ServerScriptService.Server.RVBuilder.Layout`: plan-to-section Z helpers
- `game.ServerScriptService.Server.RVBuilder.ModelBuilder`: common part/CSG/cloning helpers
- `game.ServerScriptService.Server.RVBuilder.Panels`: panel split and wheel-box helpers
- `game.ServerScriptService.Server.RVBuilder.Assemblies`: roof/floor/door/wheel/light helpers
- `game.ServerScriptService.Server.RVBuilder.ClassCCabGeometry`: shared Class-C cab measurements, hood/front profile helpers, and steering/window sizing
- `game.ServerScriptService.Server.RVBuilder.ModuleBuilders`: living/class cab handlers
- `game.ServerScriptService.Server.RVBuilder.ClassCCabBuilder`: Class-C cab composition
- `game.ServerScriptService.Server.RVBuilder.VehicleBuilder`: top-level builder
- `game.ServerScriptService.Server.RVBuilder.Plans.BaseCamp`: default front-to-back RV module plan from `src/server/RVBuilder/Plans/BaseCamp.luau`
- `game.ReplicatedStorage.Shared.RVBounds`: Rojo-synced bounding-box utility module from `src/shared/RVBounds.luau`
- `game.ReplicatedStorage.Shared.RVShapePrimitives`: Rojo-synced primitive orientation module from `src/shared/RVShapePrimitives.luau`
