# Vehicle Platform

Status: `implemented`

## Purpose

Provide the RV as the shared player base: a modular build target, a drivable vehicle, and a stable moving playspace for passengers.

## Core concepts

- The RV is the mobile base camp and the main shared object the run is built around.
- Keep the builder plan-driven so front, middle, and rear sections can be swapped or extended without rewriting the build flow.
- One player drives while other players can move around inside the vehicle; builder and runtime changes should preserve that moving-interior contract.
- Keep vehicle-specific detail here instead of growing `AGENTS.md` with section inventories or geometry playbooks.

## What exists now

- Modular RV construction lives in `RVBuilder` and already supports a plan-driven vehicle build flow.
- The current repo includes the Class-C-focused cab and living-section assembly foundation, plus shared panel, roof, wheel, and opening helpers.
- Driving, grounding, passenger carry, and passenger support detection exist and are part of the active runtime path.
- Interactable motion for doors and hood panels exists, along with debug spawn and drive actions.

## What does not exist yet

- No formal damage model, detachable or failing RV parts, or repair loop that consumes resources.
- No runtime upgrade-slot system for armor, storage, weapons, utilities, or decorations.
- No persistence layer for RV layout, cosmetics, or between-run modifications.

## Current reference build

- Walkable interior.
- Class-C cab section with steering wheel, dashboard, driver and passenger seating, hood, engine bay, front wheels, front bumper, and an over-cab front shape.
- Front living section with an entry door, side panels, and a rounded roof profile.
- Rear living section with side and rear windows, rear wheels, rounded roof profile, rear wall, ladder, and rear bumper.
- Wheel wells, wheel tubs, and exterior lights already belong to the active build contract.

## Geometry authoring conventions

- Use `RVBounds` for placement. Describe generated geometry with `bounds(x0, x1, y0, y1, z0, z1)` and let helpers derive `Size` and `CFrame`.
- Use `RVShapePrimitives` for `WedgePart` and `Enum.PartType.Cylinder` creation. Do not hand-roll `CFrame.Angles` for those primitive rotations at call sites.
- Preferred builder primitives are `part(parent, name, bounds(...), style, optionalRotation)`, `wedge(parent, name, bounds(...), slopeFace, style)`, and `cylinder(parent, name, bounds(...), axis, style, optionalTilt)`.
- `ModelBuilder:tryUnion` and `ModelBuilder:trySubtract` are fail-fast CSG helpers. If Roblox CSG fails, the build must error; do not leave backup geometry, translucent cutters, or substitute folders in the model.
- Coordinate convention: `X = width`, `Y = height`, `Z = length`, and negative `Z` is vehicle front.
- `ShapePrimitives.WedgeSlopeFace.TopFront` matches the reference wedge orientation. Use the named slope-face enums instead of ad hoc rotation guessing.
- Use `ShapePrimitives.WedgeSolidCorner` only to describe the corner that should remain solid, then convert it with `wedgeSlopeFaceForSolidCorner`.
- Use `ShapePrimitives.wheelWellCornerSlopeFace(edge)` for wheel-well corner wedges instead of duplicating front or back orientation logic.
- Roblox cylinders run along their local height axis before rotation. Use `ShapePrimitives.CylinderAxis.Width`, `Height`, or `Length` to describe which vehicle axis the cylinder occupies inside the provided bounds.
- If a cylinder needs a controlled tilt, pass `{ Toward = ShapePrimitives.Direction.Back, Degrees = 65 }`. If it must match an exact source axis, pass `{ Rotation = someCFrame }` through the helper.

## Current wheel-well directive

Wheel wells should stay simple:

1. Divide the wall on either side of the wheel hole.
2. Stop the wall segment above the wheel at the top of the wheel.
3. Place a small wedge in the corners to make it feel rounded.
4. Union the wall parts together.
5. Box in the inside of the wheel for the vehicle interior.

Prefer one shared function with arguments that can support double-wheel or double-axle layouts instead of separate ad hoc wheel-well build paths.

## Reused plan fields

Reuse these plan fields before adding new ones:

- Plan root: `OutputName`, `VehicleId`, `BuildVersion`, `Scale`, `Drive?`, `SteeringWheelSourcePath`, `Modules`.
- Module: `Id`, `Type`, `Length`, `GeometryLength?`, `PanelColor?`, `Wheels?`, `Windows?`, `Doors?`, `RearWall?`, `Ladder?`, `FeatureY?`.
- Wheel group: `Id`, `LocalZ`, `AxleCount?`, `SideWheels?`, `AxleSpacing?`, `DualSpacing?`, `Radius?`, `Width?`, `OuterProtrusion?`, `WellClearance?`.
- Window or door specs: `Id`, `Side`, `LocalZ0`, `LocalZ1`, `Y0?`, `Y1?`.

## Key files

- `src/server/Build_RV_BaseCamp.server.luau`
- `src/server/RVBuilder/VehicleBuilder.luau`
- `src/server/RVBuilder/Plans/BaseCamp.luau`
- `src/server/RVBuilder/Constants.luau`
- `src/server/RVBuilder/Layout.luau`
- `src/server/RVBuilder/ModelBuilder.luau`
- `src/server/RVBuilder/ModuleBuilders.luau`
- `src/server/RVBuilder/Panels.luau`
- `src/server/RVBuilder/WheelGroups.luau`
- `src/server/RVBuilder/ClassCCabBuilder.luau`
- `src/server/RVBuilder/ClassCCabGeometry.luau`
- `src/server/RVBuilder/CockpitBuilder.luau`
- `src/server/RVBuilder/Assemblies.luau`
- `src/server/RVBuilder/RVInteractableMotion.luau`
- `src/server/RVBuilder/RVDriveController.luau`
- `src/server/RVBuilder/RVGrounding.luau`
- `src/server/RVBuilder/RVOccupantCarry.luau`
- `src/shared/RVBounds.luau`
- `src/shared/RVShapePrimitives.luau`
- `src/shared/RVRideSupport.luau`

## Dependencies

- `World Generation` for spawn placement and terrain support.
- `Tooling and Validation` for debug spawning and validation flows.
- Future `Round Gameplay` and `Meta Progression` systems for repair, upgrades, and persistence.
