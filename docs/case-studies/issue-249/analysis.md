# Issue 249: Fix Player Model - Arm Joint Issues

## Problem Statement
When walking with an assault rifle, there are visible joint issues:
1. The shoulder (of the right arm) sticks out behind the torso
2. The arm is not connected at the elbow

## Technical Analysis

### Sprite Dimensions
- `player_body.png`: 28x24 pixels (torso, facing right)
- `player_head.png`: 14x18 pixels (helmet from above)
- `player_left_arm.png`: 20x8 pixels (horizontal arm, extends right)
- `player_right_arm.png`: 20x8 pixels (horizontal arm, extends right)

### Scene Positioning (Player.tscn)
```
PlayerModel (Node2D at origin)
├── Body (Sprite2D)
│   ├── position: (-4, 0)
│   ├── z_index: 1 (in scene), set to 1 in code
├── LeftArm (Sprite2D)
│   ├── position: (24, 6)
│   ├── z_index: 4 (in scene), set to 2 in code
├── RightArm (Sprite2D)
│   ├── position: (-2, 6)
│   ├── z_index: 4 (in scene), set to 2 in code
├── Head (Sprite2D)
│   ├── position: (-6, -2)
│   ├── z_index: 3 (in scene and code)
└── WeaponMount (Node2D)
    └── position: (0, 6) or (6, 6) in C# version
```

### Walking Animation System
The `_update_walk_animation()` function in `player.gd` applies offsets:
- Body bobs up/down: `sin(time * 2.0) * 1.5 * intensity`
- Head bobs (dampened): `sin(time * 2.0) * 0.8 * intensity`
- Arms swing opposite: `sin(time) * 3.0 * intensity`
  - Left arm: `position + Vector2(arm_swing, 0)`
  - Right arm: `position + Vector2(-arm_swing, 0)`

### Root Cause Identification

#### Issue 1: Shoulder Sticking Out
The right arm position `(-2, 6)` places the arm's pivot point (center of sprite) close to the body center. When the arm swings during walking animation (`-arm_swing` on X-axis), it moves to the LEFT (negative X direction), which in the player's reference frame means BACKWARD.

With a 20-pixel wide arm sprite centered at x=-2:
- Sprite spans from x=-12 to x=8
- The "shoulder" part of the arm (leftmost portion) is at x=-12
- The body's right edge is around x=10 (body at -4 with 28px width)

When the arm swings LEFT during animation, the shoulder portion becomes more visible behind the body.

#### Issue 2: Elbow Disconnection
The arm sprites are designed as straight horizontal bars. When the walking animation moves the arms along the X-axis, and the body bobs vertically, the arms can appear disconnected because:
1. The Y position of arms doesn't track with body bob
2. The arm sprites don't have proper elbow articulation

### Proposed Solutions

#### Solution A: Adjust Arm Position
Move the right arm position so the shoulder is better anchored to the body:
- Current: `(-2, 6)`
- Proposed: `(2, 6)` or adjust to better align shoulder joint

#### Solution B: Reduce Arm Swing During Walking
The current arm swing of `3.0 * intensity` pixels may be too large, causing visible disconnection. Reducing to `1.5 * intensity` would keep arms more attached.

#### Solution C: Synchronize Body Bob with Arms
Add a small vertical offset to arms that matches the body bob to prevent apparent disconnection during walking.

#### Solution D: Adjust Z-Index Based on Facing Direction
When the player faces left (PlayerModel flipped), swap the z-indices of arms so the correct arm appears in front.

## Recommended Fix
Implement a combination of:
1. Reduce arm swing amplitude
2. Add body-synchronized vertical offset to arms
3. Adjust right arm base position for better shoulder alignment
