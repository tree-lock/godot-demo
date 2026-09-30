extends CharacterBody2D
class_name Player

const BULLET_SCENE := preload("res://scene/Bullet.tscn")
const DEATH_ANIMATION_NAME := &"death"
const BLINK_ENABLED_SHADER_PARAMETER := &"blink_enabled"
const WORLD_COLLISION_MASK := 1
const BULLET_SPAWN_MARGIN := 1.0

@onready var body_spirit: AnimatedSprite2D = $BodySprite
@onready var shooting_timer: Timer = $ShootingTimer
@onready var armed_effect_sprite: AnimatedSprite2D = $ArmedEffectSprite


@export var move_speed: float = 120

@export var fire_interval: float = 0.18 

@export var bullet_spawn_distance: float = 18.0

@export var spiral_phase_step: float = PI / 12

@export var max_health: int = 5
@export var hurt_invincible_duration: float = 1.0

var facing_suffix: StringName = &"right"
var current_health: int = 5
var is_dead: bool = false
var hurt_invincible_time_left: float = 0.0

var move_speed_multiplier: float = 1.0
var rapid_fire_rate_multiplier: float = 1.0
var form_fire_rate_multiplier: float = 1.0
var current_form_mode: PickupConfig.PlayerFormMode = PickupConfig.PlayerFormMode.NORMAL
var current_short_pattern: PickupConfig.ShotPattern = PickupConfig.ShotPattern.NORMAL
var spiral_phase: float = 0.0

var speed_buff_timer: Timer
var rapid_buff_timer: Timer
var form_buff_timer: Timer


func _ready() -> void:	
	current_health = max_health
	shooting_timer.one_shot = true
	shooting_timer.wait_time = _get_effective_fire_interval()
	speed_buff_timer = _create_buff_timer(_on_speed_buff_timeout)
	rapid_buff_timer = _create_buff_timer(_on_rapid_buff_timeout)
	form_buff_timer = _create_buff_timer(_on_form_buff_timeout)
	_update_animation()
	_update_armed_effect()

func apply_damage(amount: int) -> bool:
	if is_dead or amount <= 0 or hurt_invincible_time_left > 0.0:
		return false

	current_health -= amount
	if current_health <= 0:
		current_health = 0
		_die()
		return true

	_start_hurt_blink()
	return true

func _die() -> void:
	if is_dead:
		return

	is_dead = true
	hurt_invincible_time_left = 0.0
	_set_hurt_blink_enabled(false)
	velocity = Vector2.ZERO
	shooting_timer.stop()
	armed_effect_sprite.visible = false
	if armed_effect_sprite.is_playing():
		armed_effect_sprite.stop()

	if body_spirit.sprite_frames == null or not body_spirit.sprite_frames.has_animation(DEATH_ANIMATION_NAME):
		push_warning("Missing player animation: %s" % DEATH_ANIMATION_NAME)
		return

	body_spirit.sprite_frames.set_animation_loop(DEATH_ANIMATION_NAME, false)
	body_spirit.play(DEATH_ANIMATION_NAME)

func _physics_process(delta: float) -> void:
	_update_hurt_blink(delta)
	if is_dead:
		velocity = Vector2.ZERO
		return

	var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var shoot_input := Input.get_vector("shoot_left", "shoot_right", "shoot_up", "shoot_down")
	
	velocity = move_input * move_speed * move_speed_multiplier
	move_and_slide()
	
	if _is_spiral_pattern():
		_try_auto_spiral_shoot()
	elif shoot_input != Vector2.ZERO:
		_try_shoot(shoot_input)
		
	_update_facing(move_input, shoot_input)
	_update_animation()
	_update_armed_effect()

func apply_config(config: PickupConfig) -> bool:
	if config == null:
		return false
	
	match config.pickup_type:
		PickupConfig.PickupType.SPEED:
			_apply_speed_buff(config)
		PickupConfig.PickupType.RAPID:
			_apply_rapid_buff(config)
		PickupConfig.PickupType.SPIRAL:
			_apply_form_buff(config)
		_:
			return false
	
	return true

func _apply_speed_buff(config: PickupConfig) -> void:
	move_speed_multiplier = config.move_speed_multiplier
	_restart_buff_timer(speed_buff_timer, config.duration)

func _apply_rapid_buff(config: PickupConfig) -> void:
	rapid_fire_rate_multiplier = config.fire_rate_multiplier
	_restart_buff_timer(rapid_buff_timer, config.duration)
	_refresh_shooting_interval()

func _apply_form_buff(config: PickupConfig) -> void:
	current_form_mode = config.player_form_mode
	current_short_pattern = config.shot_pattern
	form_fire_rate_multiplier = config.fire_rate_multiplier
	_restart_buff_timer(form_buff_timer, config.duration)
	_refresh_shooting_interval()

func _on_speed_buff_timeout() -> void:
	move_speed_multiplier = 1.0

func _on_rapid_buff_timeout() -> void:
	rapid_fire_rate_multiplier = _get_default_fire_rate_multiplier()
	_refresh_shooting_interval()

func _on_form_buff_timeout() -> void:
	current_form_mode = PickupConfig.PlayerFormMode.NORMAL
	current_short_pattern = PickupConfig.ShotPattern.NORMAL
	form_fire_rate_multiplier = _get_default_fire_rate_multiplier()
	_refresh_shooting_interval()

func _create_buff_timer(timeout_callback: Callable) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(timeout_callback)
	add_child(timer)
	return timer

func _restart_buff_timer(timer: Timer, duration: float) -> void:
	timer.stop()
	if duration <= 0.0:
		return
	timer.start(duration)

func _refresh_shooting_interval() -> void:
	shooting_timer.wait_time = _get_effective_fire_interval()

func _update_animation() -> void:
	var animation_name := StringName("%s_%s" % [_get_animation_prefix(), facing_suffix])
	
	if not body_spirit.sprite_frames.has_animation(animation_name):
		var fallback_animation_name := StringName("%s_%s" % [&"normal", facing_suffix])
		push_warning("Missing player animation: %s" % animation_name)
		if not body_spirit.sprite_frames.has_animation(fallback_animation_name):
			return
		animation_name = fallback_animation_name
	
	if body_spirit.animation != animation_name:
		body_spirit.play(animation_name)
		
func _update_facing(move_input: Vector2, shoot_input: Vector2) -> void:
	if _is_armed_form():
		if move_input != Vector2.ZERO:
			facing_suffix = _vector_to_facing_suffix(move_input)
		return
	
	if shoot_input != Vector2.ZERO:
		facing_suffix = _vector_to_facing_suffix(shoot_input)
	elif move_input != Vector2.ZERO:
		facing_suffix = _vector_to_facing_suffix(move_input)
		
func _try_shoot(shoot_input: Vector2) -> void:
	if not shooting_timer.is_stopped():
		return;
	
	var shoot_direction := shoot_input.normalized()
	var has_spawned_bullet = _fire_bullet(shoot_direction)
	if (has_spawned_bullet):
		shooting_timer.start(_get_effective_fire_interval())
		
func _fire_bullet(shoot_direction: Vector2) -> bool:
	if _is_spiral_pattern():
		var has_spawned_forward_bullet = _spawn_bullet(shoot_direction)
		var has_spawned_back_bullet = _spawn_bullet(shoot_direction.rotated(PI))
		spiral_phase = wrapf(spiral_phase + spiral_phase_step, 0.0, TAU)
		return has_spawned_forward_bullet or has_spawned_back_bullet
	
	return _spawn_bullet(shoot_direction)
	
func _spawn_bullet(spawn_direction: Vector2) -> bool:
	var bullet := BULLET_SCENE.instantiate() as Bullet
	if bullet == null:
		return false

	if not _can_spawn_bullet(spawn_direction, _get_bullet_body_radius(bullet)):
		bullet.free()
		return false

	bullet.top_level = true
	bullet.setup(spawn_direction)

	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		bullet.free()
		return false

	bullet.global_position = global_position + spawn_direction * bullet_spawn_distance
	spawn_parent.add_child(bullet)
	return true

func _can_spawn_bullet(direction: Vector2, bullet_radius: float) -> bool:
	var origin := global_position
	var spawn_position := origin + direction * bullet_spawn_distance
	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return true

	var query := PhysicsRayQueryParameters2D.create(
		origin,
		spawn_position + direction * (bullet_radius + BULLET_SPAWN_MARGIN),
		WORLD_COLLISION_MASK
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return space_state.intersect_ray(query).is_empty()

func _get_bullet_body_radius(bullet: Bullet) -> float:
	var shape_node := bullet.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape is CircleShape2D:
		return (shape_node.shape as CircleShape2D).radius
	return 0.0

func _try_auto_spiral_shoot() -> void:
	if not shooting_timer.is_stopped():
		return
	
	var spiral_direction := Vector2.RIGHT.rotated(spiral_phase)
	var has_spawned_bullet := _fire_bullet(spiral_direction)
	if has_spawned_bullet:
		shooting_timer.start(_get_effective_fire_interval())

func _get_effective_fire_interval() -> float:
	return maxf(fire_interval / _get_effective_fire_rate_multiplier(), 0.01)
	
func _get_effective_fire_rate_multiplier() -> float:
	if _has_active_form_override():
		return maxf(form_fire_rate_multiplier, 0.01)
	
	return maxf(rapid_fire_rate_multiplier, 0.01)

func _get_default_fire_rate_multiplier() -> float:
	return 1.0

func _has_active_form_override() -> bool:
	return _is_armed_form() and _is_spiral_pattern()

func _is_armed_form() -> bool:
	return current_form_mode == PickupConfig.PlayerFormMode.ARMED

func _is_spiral_pattern() -> bool:
	return current_short_pattern == PickupConfig.ShotPattern.SPIRAL
	
func _get_animation_prefix() -> StringName:
	if _is_armed_form():
		return &"armed"
	
	return &"normal"
	
func _update_armed_effect() -> void:
	if not _is_armed_form(): 
		if armed_effect_sprite.visible:
			armed_effect_sprite.visible = false
		if armed_effect_sprite.is_playing():
			armed_effect_sprite.stop()
		return
	
	if not armed_effect_sprite.visible:
		armed_effect_sprite.visible = true
	if armed_effect_sprite.is_playing():
		return
	if armed_effect_sprite.sprite_frames == null:
		push_warning("Sprite Frames of ArmedEffectSprite not found")
		return
	
	if armed_effect_sprite.sprite_frames.has_animation(&"default"):
		armed_effect_sprite.play(&"default")
	
		
func _start_hurt_blink() -> void:
	if hurt_invincible_duration <= 0.0:
		return

	hurt_invincible_time_left = hurt_invincible_duration
	_set_hurt_blink_enabled(true)

func _update_hurt_blink(delta: float) -> void:
	if hurt_invincible_time_left <= 0.0:
		return

	hurt_invincible_time_left = maxf(hurt_invincible_time_left - delta, 0.0)
	if hurt_invincible_time_left > 0.0:
		return

	_set_hurt_blink_enabled(false)

func _set_hurt_blink_enabled(enabled: bool) -> void:
	var shader_material := body_spirit.material as ShaderMaterial
	if shader_material == null:
		return

	shader_material.set_shader_parameter(BLINK_ENABLED_SHADER_PARAMETER, enabled)

func _vector_to_facing_suffix(direction: Vector2) -> StringName:
	if abs(direction.x) >= abs(direction.y): 
		return &"right" if direction.x > 0.0 else &"left"
		
	return &"down" if direction.y > 0.0 else &"up"
