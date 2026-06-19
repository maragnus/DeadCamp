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
- `part(parent, name, bounds(...), style, optionalRotation)`, `wedge(parent, name, bounds(...), slope, style)`, and `cylinder(parent, name, bounds(...), axis, style, optionalTilt)` are the preferred builder primitives.
- Wedge convention: `ShapePrimitives.WedgeSlope.TopFront` matches the reference `Workspace.Wedge`: triangular side visible on the right, flat bottom, vertical back, and the diagonal face between top/front.
- Use `ShapePrimitives.WedgeSlope.TopFront`, `TopBack`, `TopLeft`, or `TopRight` to describe the diagonal wedge face in geometric terms.
- Use `ShapePrimitives.wheelWellCornerSlope(side, edge)` for wheel-well corner wedges instead of duplicating left/right front/back rotation logic.
- Cylinder convention: Roblox cylinders run along their local height axis before rotation. Use `ShapePrimitives.CylinderAxis.Width`, `Height`, or `Length` to say which vehicle axis the cylinder occupies inside the provided bounds.
- If a cylinder needs a controlled tilt, pass `{ Toward = ShapePrimitives.Direction.Back, Degrees = 65 }` or the equivalent direction object through the helper. Add new tilt cases in `RVShapePrimitives` before using ad hoc `CFrame.Angles`.

# RV Base Camp

The RV is a modular vehicle that serves as the player base camp.

It has interchangable sections and can be extended to any length and represent either a Class-C (engine front) or a Class-A motorhome (engine rear).

One player will drive the RV between points of interest. The other players are free to move about the vehicle, organize and craft while in motion. This require special physics handling as Roblox cannot natively support this.

Key components and features:
- Walkable interior
- Class-C Cab section
  - Steering wheel and simple dashboard
  - Driver's seat
  - Passenger seat
  - Hood
  - Engine
  - Front wheels
  - Front bumper
- Front section
  - Entry door (usable)
  - Gutted interior (no furniture)
  - Side panels
- Class-C Back section
  - Windows (subtracted/carved out of walls)
  - Rear wheels
  - Gutted interior (no furniture)
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
- Update "Common Objects" below with a quick access list of commonly used scripts or `Instances`

## Common Objects

- `game.Workspace.Baseplate`: Baseplate
- `game.Workspace.RV_BaseCamp_RepairCandidate`: generated repair candidate RV model
- `game.ServerScriptService.Server.Build_RV_BaseCamp`: Rojo-synced builder script from `src/server/Build_RV_BaseCamp.server.luau`
- `game.ServerScriptService.Server.RVBuilder`: Rojo-synced modular RV builder modules from `src/server/RVBuilder`
- `game.ServerScriptService.Server.RVBuilder.Plans.BaseCamp`: default front-to-back RV module plan from `src/server/RVBuilder/Plans/BaseCamp.luau`
- `game.ReplicatedStorage.Shared.RVBounds`: Rojo-synced bounding-box utility module from `src/shared/RVBounds.luau`
- `game.ReplicatedStorage.Shared.RVShapePrimitives`: Rojo-synced primitive orientation module from `src/shared/RVShapePrimitives.luau`
