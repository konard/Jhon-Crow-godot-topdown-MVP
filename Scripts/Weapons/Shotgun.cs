using Godot;
using GodotTopDownTemplate.AbstractClasses;

namespace GodotTopDownTemplate.Weapons;

/// <summary>
/// Shotgun action state for pump-action mechanics.
/// </summary>
public enum ShotgunActionState
{
    /// <summary>
    /// Ready to fire - action closed, shell chambered.
    /// </summary>
    Ready,

    /// <summary>
    /// Action open - needs to be cycled up.
    /// </summary>
    ActionOpen,

    /// <summary>
    /// Needs to cycle down after cycling up.
    /// </summary>
    NeedsCycleDown
}

/// <summary>
/// Pump-action shotgun with multi-pellet spread.
/// Features semi-automatic fire, pump-action cycling, and tube magazine.
/// Fires ShotgunPellet projectiles with limited ricochet (35 degrees max).
/// Pellets fire in a "swarm" pattern with slight delays between each.
/// No laser sight, large screen shake per shot.
/// </summary>
public partial class Shotgun : BaseWeapon
{
    /// <summary>
    /// Minimum number of pellets per shot (inclusive).
    /// </summary>
    [Export]
    public int MinPellets { get; set; } = 6;

    /// <summary>
    /// Maximum number of pellets per shot (inclusive).
    /// </summary>
    [Export]
    public int MaxPellets { get; set; } = 12;

    /// <summary>
    /// Pellet scene to instantiate when firing.
    /// Uses ShotgunPellet which has limited ricochet (35 degrees).
    /// If not set, falls back to BulletScene.
    /// </summary>
    [Export]
    public PackedScene? PelletScene { get; set; }

    /// <summary>
    /// Delay between each pellet spawn in seconds.
    /// Creates a "swarm" effect where pellets don't all fire at once.
    /// Default 8ms per pellet.
    /// </summary>
    [Export]
    public float PelletSpawnDelay { get; set; } = 0.008f;

    /// <summary>
    /// Whether this weapon uses a tube magazine (shell-by-shell loading).
    /// When true, the magazine UI should be hidden and replaced with shell count.
    /// </summary>
    public bool UsesTubeMagazine { get; } = true;

    /// <summary>
    /// Whether the shotgun has been fired and needs cycling.
    /// In Phase 1, cycling is instant after firing.
    /// </summary>
    public ShotgunActionState ActionState { get; private set; } = ShotgunActionState.Ready;

    /// <summary>
    /// Reference to the Sprite2D node for the shotgun visual.
    /// </summary>
    private Sprite2D? _shotgunSprite;

    /// <summary>
    /// Current aim direction based on mouse position.
    /// </summary>
    private Vector2 _aimDirection = Vector2.Right;

    /// <summary>
    /// Timer for action cycling animation.
    /// </summary>
    private float _actionCycleTimer = 0.0f;

    /// <summary>
    /// Time for pump-action cycle (in seconds).
    /// </summary>
    private const float ActionCycleTime = 0.3f;

    /// <summary>
    /// Signal emitted when action state changes.
    /// </summary>
    [Signal]
    public delegate void ActionStateChangedEventHandler(int newState);

    /// <summary>
    /// Signal emitted when the shotgun fires.
    /// </summary>
    [Signal]
    public delegate void ShotgunFiredEventHandler(int pelletCount);

    public override void _Ready()
    {
        base._Ready();

        // Get the shotgun sprite for visual representation
        _shotgunSprite = GetNodeOrNull<Sprite2D>("ShotgunSprite");

        if (_shotgunSprite != null)
        {
            GD.Print($"[Shotgun] ShotgunSprite found: visible={_shotgunSprite.Visible}");
        }
        else
        {
            GD.Print("[Shotgun] No ShotgunSprite node (visual model not yet added as per requirements)");
        }

        // Load pellet scene if not set
        if (PelletScene == null)
        {
            PelletScene = GD.Load<PackedScene>("res://scenes/projectiles/csharp/ShotgunPellet.tscn");
            if (PelletScene != null)
            {
                GD.Print("[Shotgun] Loaded ShotgunPellet scene");
            }
            else
            {
                GD.PrintErr("[Shotgun] WARNING: Could not load ShotgunPellet.tscn, will fallback to BulletScene");
            }
        }

        GD.Print($"[Shotgun] Ready - MinPellets={MinPellets}, MaxPellets={MaxPellets}, PelletDelay={PelletSpawnDelay}s");
    }

    public override void _Process(double delta)
    {
        base._Process(delta);

        // Update aim direction
        UpdateAimDirection();

        // Handle action cycling timer
        if (_actionCycleTimer > 0)
        {
            _actionCycleTimer -= (float)delta;
            if (_actionCycleTimer <= 0)
            {
                CompleteActionCycle();
            }
        }
    }

    /// <summary>
    /// Updates the aim direction based on mouse position.
    /// </summary>
    private void UpdateAimDirection()
    {
        Vector2 mousePos = GetGlobalMousePosition();
        Vector2 toMouse = mousePos - GlobalPosition;

        if (toMouse.LengthSquared() > 0.001f)
        {
            _aimDirection = toMouse.Normalized();
        }

        // Update sprite rotation if available
        UpdateShotgunSpriteRotation(_aimDirection);
    }

    /// <summary>
    /// Updates the shotgun sprite rotation to match the aim direction.
    /// </summary>
    private void UpdateShotgunSpriteRotation(Vector2 direction)
    {
        if (_shotgunSprite == null)
        {
            return;
        }

        float angle = direction.Angle();
        _shotgunSprite.Rotation = angle;

        // Flip sprite vertically when aiming left
        bool aimingLeft = Mathf.Abs(angle) > Mathf.Pi / 2;
        _shotgunSprite.FlipV = aimingLeft;
    }

    /// <summary>
    /// Fires the shotgun - spawns multiple pellets with spread in a swarm pattern.
    /// Pellets are spawned with slight delays to create a natural swarm effect
    /// where some pellets are ahead of others.
    /// </summary>
    /// <param name="direction">Base direction to fire.</param>
    /// <returns>True if the weapon fired successfully.</returns>
    public override bool Fire(Vector2 direction)
    {
        // Check if action is ready
        if (ActionState != ShotgunActionState.Ready)
        {
            GD.Print($"[Shotgun] Cannot fire - action state: {ActionState}");
            return false;
        }

        // Check for empty magazine
        if (CurrentAmmo <= 0)
        {
            PlayEmptyClickSound();
            return false;
        }

        // Check fire rate - use either BulletScene or PelletScene
        PackedScene? projectileScene = PelletScene ?? BulletScene;
        if (!CanFire || WeaponData == null || projectileScene == null)
        {
            return false;
        }

        // Use aim direction
        Vector2 fireDirection = _aimDirection;

        // Determine number of pellets (random between min and max)
        int pelletCount = GD.RandRange(MinPellets, MaxPellets);

        // Get spread angle from weapon data
        float spreadAngle = WeaponData.SpreadAngle;
        float spreadRadians = Mathf.DegToRad(spreadAngle);
        float halfSpread = spreadRadians / 2.0f;

        GD.Print($"[Shotgun] Firing {pelletCount} pellets with {spreadAngle}° spread (swarm pattern)");

        // Fire pellets with delay for swarm effect
        FirePelletsWithDelay(fireDirection, pelletCount, spreadRadians, halfSpread, projectileScene);

        // Consume ammo (one shell for all pellets)
        CurrentAmmo--;

        // Set action state - needs cycling (Phase 1: instant cycle)
        ActionState = ShotgunActionState.ActionOpen;
        _actionCycleTimer = ActionCycleTime;
        EmitSignal(SignalName.ActionStateChanged, (int)ActionState);

        // Play shotgun sound
        PlayShotgunSound();

        // Emit gunshot for sound propagation
        EmitGunshotSound();

        // Trigger large screen shake
        TriggerScreenShake(fireDirection);

        // Emit signals
        EmitSignal(SignalName.Fired);
        EmitSignal(SignalName.ShotgunFired, pelletCount);
        EmitSignal(SignalName.AmmoChanged, CurrentAmmo, ReserveAmmo);

        return true;
    }

    /// <summary>
    /// Fires pellets with delay between each to create a swarm pattern.
    /// The delay causes some pellets to be slightly ahead of others,
    /// creating a more natural spread instead of a flat wall.
    /// </summary>
    private async void FirePelletsWithDelay(Vector2 fireDirection, int pelletCount, float spreadRadians, float halfSpread, PackedScene projectileScene)
    {
        for (int i = 0; i < pelletCount; i++)
        {
            // Distribute pellets evenly across the spread cone with some randomness
            float baseAngle;
            if (pelletCount > 1)
            {
                // Distribute pellets across the cone
                float progress = (float)i / (pelletCount - 1);
                baseAngle = Mathf.Lerp(-halfSpread, halfSpread, progress);
                // Add small random deviation
                baseAngle += (float)GD.RandRange(-spreadRadians * 0.1, spreadRadians * 0.1);
            }
            else
            {
                // Single pellet goes straight
                baseAngle = 0;
            }

            Vector2 pelletDirection = fireDirection.Rotated(baseAngle);
            SpawnPellet(pelletDirection, projectileScene);

            // Wait between pellets (except for the last one)
            if (i < pelletCount - 1 && PelletSpawnDelay > 0)
            {
                await ToSignal(GetTree().CreateTimer(PelletSpawnDelay), "timeout");
            }
        }
    }

    /// <summary>
    /// Spawns a pellet projectile in the specified direction.
    /// Uses ShotgunPellet scene which has limited ricochet (35 degrees).
    /// </summary>
    private void SpawnPellet(Vector2 direction, PackedScene projectileScene)
    {
        if (projectileScene == null || WeaponData == null)
        {
            return;
        }

        // Check if the bullet spawn path is blocked by a wall
        var (isBlocked, hitPosition, hitNormal) = CheckBulletSpawnPath(direction);

        Vector2 spawnPosition;
        if (isBlocked)
        {
            // Wall detected at point-blank range - spawn at weapon position
            spawnPosition = GlobalPosition + direction * 2.0f;
        }
        else
        {
            // Normal case: spawn at offset position
            spawnPosition = GlobalPosition + direction * BulletSpawnOffset;
        }

        var pellet = projectileScene.Instantiate<Node2D>();
        pellet.GlobalPosition = spawnPosition;

        // Set pellet properties
        if (pellet.HasMethod("SetDirection"))
        {
            pellet.Call("SetDirection", direction);
        }
        else
        {
            pellet.Set("Direction", direction);
        }

        // Set pellet speed from weapon data
        pellet.Set("Speed", WeaponData.BulletSpeed);

        // Set shooter ID to prevent self-damage
        var owner = GetParent();
        if (owner != null)
        {
            pellet.Set("ShooterId", owner.GetInstanceId());
        }

        GetTree().CurrentScene.AddChild(pellet);
    }

    /// <summary>
    /// Completes the action cycle (automatic in Phase 1).
    /// </summary>
    private void CompleteActionCycle()
    {
        if (ActionState == ShotgunActionState.ActionOpen)
        {
            // Check if there's ammo to chamber
            if (CurrentAmmo > 0)
            {
                ActionState = ShotgunActionState.Ready;
                GD.Print("[Shotgun] Action cycled - ready to fire");
            }
            else
            {
                // Empty magazine - stay in action open state
                ActionState = ShotgunActionState.ActionOpen;
                GD.Print("[Shotgun] Action cycled but magazine empty");
            }
            EmitSignal(SignalName.ActionStateChanged, (int)ActionState);
        }
    }

    /// <summary>
    /// Manually cycles the action (for future pump-action input).
    /// </summary>
    public void CycleAction()
    {
        if (ActionState == ShotgunActionState.ActionOpen)
        {
            CompleteActionCycle();
        }
    }

    /// <summary>
    /// Plays the empty gun click sound.
    /// </summary>
    private void PlayEmptyClickSound()
    {
        var audioManager = GetNodeOrNull("/root/AudioManager");
        if (audioManager != null && audioManager.HasMethod("play_empty_click"))
        {
            audioManager.Call("play_empty_click", GlobalPosition);
        }
    }

    /// <summary>
    /// Plays the shotgun firing sound.
    /// </summary>
    private void PlayShotgunSound()
    {
        var audioManager = GetNodeOrNull("/root/AudioManager");
        // Use M16 shot as placeholder until shotgun-specific sound is added
        if (audioManager != null && audioManager.HasMethod("play_m16_shot"))
        {
            audioManager.Call("play_m16_shot", GlobalPosition);
        }
    }

    /// <summary>
    /// Emits gunshot sound for enemy detection.
    /// </summary>
    private void EmitGunshotSound()
    {
        var soundPropagation = GetNodeOrNull("/root/SoundPropagation");
        if (soundPropagation != null && soundPropagation.HasMethod("emit_sound"))
        {
            float loudness = WeaponData?.Loudness ?? 1469.0f;
            soundPropagation.Call("emit_sound", 0, GlobalPosition, 0, this, loudness);
        }
    }

    /// <summary>
    /// Triggers large screen shake for shotgun recoil.
    /// </summary>
    private void TriggerScreenShake(Vector2 shootDirection)
    {
        if (WeaponData == null || WeaponData.ScreenShakeIntensity <= 0)
        {
            return;
        }

        var screenShakeManager = GetNodeOrNull("/root/ScreenShakeManager");
        if (screenShakeManager == null || !screenShakeManager.HasMethod("add_shake"))
        {
            return;
        }

        // Large shake intensity for shotgun
        float shakeIntensity = WeaponData.ScreenShakeIntensity;
        float recoveryTime = WeaponData.ScreenShakeMinRecoveryTime;

        screenShakeManager.Call("add_shake", shootDirection, shakeIntensity, recoveryTime);
    }

    /// <summary>
    /// Gets the current aim direction.
    /// </summary>
    public Vector2 AimDirection => _aimDirection;

    /// <summary>
    /// Gets whether the shotgun is ready to fire.
    /// </summary>
    public bool IsReadyToFire => ActionState == ShotgunActionState.Ready && CanFire;
}
