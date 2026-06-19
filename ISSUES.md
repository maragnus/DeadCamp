NOTE: `src/server/Build_RV_BaseCamp.server.luau` is the active source of truth. Rojo syncs it into `game.ServerScriptService.Server.Build_RV_BaseCamp`.

RV BaseCamp
- Walkable interior
- Cab section
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
- Back section
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

We need a solid, DRY, well-structured script that can create a functional RV. We will be including features in the future, like alternate parts, like Class-C-style frontend (flat/no hood), middle (living area extension), rear (engine compartment). So we need a perfect foundation that uses clean language, bounding boxes, and smart assembly that makes it easy to understand and maintain going forward.

We need to account for the fact we'll have swappable modules, lights and parts that fall off, break, or go missing, and can connect to scripts so for this to be the main vehicle in the Roblox Experience.

We have some known issues, for example, the lacking constants like floor height, floor thickness. It needs to be easy to build components in relations to the dimensions of the vehicle. We also need to keep numbers simple and relative whenever possible. Low congitive overhead for understanding part dimensions, rotations, and relativity.

Make a pass over the file and make sure we have the best starting point for building this script.


- You appear to have forgotten that the bottom of the vehicle is not the ground. There is a floor height and floor thickness. I think you need to define these clearly. Because WheelRearRight_WheelTub_RearWall and others go from the top of the wheel to the baseplate.
- You ignored my steps in "Wheel wells should be so simple" I really do want you to follow them.
- PassengerDoor_WheelFrontRight_WallAboveWheel is wrong, it's overlapping the WindshieldSideRight
- The front wheel box extends beyond the width of the cab.
- The hood sides are still wrong and not angled, I've provided a picture.


Wheel wells need to be made more simple:
1. Divide the wall on either side of the wheel hole.
2. Stop the wall segment above the wheel the top of the wheel.
3. Place a small wedge in the corners to make it feel rounded.
4. Union the wall parts together
5. Box in the inside of the wheel for the vehicle interior.
