extends CharacterBody2D
class_name Player

const BULLET_SCENE := preload("res://scene/Bullet.tscn")

@onready var body_spirit: AnimatedSprite2D = $BodySprite
@onready var shooting_timer: Timer = $ShootingTimer
@onready var armed_effect_sprite: AnimatedSprite2D = $ArmedEffectSprite


@export var move_speed: float = 120

@export var fire_interval: float = 0.18 

@export var bullet_spawn_distance: float = 18.0

@export var spiral_phase_step: float = PI / 12

var facing_suffix: StringName = &"right"

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
	shooting_timer.one_shot = true
	shooting_timer.wait_time = _get_effective_fire_interval()
	speed_buff_timer = _create_buff_timer(_on_speed_buff_timeout)
	rapid_buff_timer = _create_buff_timer(_on_rapid_buff_timeout)
	form_buff_timer = _create_buff_timer(_on_form_buff_timeout)
	_update_animation()
	_update_armed_effect()

func _physics_process(_delta: float) -> void:
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
	
	bullet.top_level = true
	bullet.setup(spawn_direction)
	
	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		return true
		
	spawn_parent.add_child(bullet)
	bullet.global_position = global_position + spawn_direction * bullet_spawn_distance
	return true

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
	
		
func _vector_to_facing_suffix(direction: Vector2) -> StringName:
	if abs(direction.x) >= abs(direction.y): 
		return &"right" if direction.x > 0.0 else &"left"
		
	return &"down" if direction.y > 0.0 else &"up"
