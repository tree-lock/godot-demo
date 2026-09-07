extends CharacterBody2D

const NORMAL_ANIMATION_PREFIX := &"normal"

@onready var body_spirit: AnimatedSprite2D = $"body-sprite"

@export var move_speed: float = 120

var facing_suffix: StringName = &"right"

func _ready() -> void:
	update_animation()

func _physics_process(delta: float) -> void:
	var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	velocity = move_input * move_speed
	move_and_slide()
	
	if move_input != Vector2.ZERO:
		facing_suffix = _vector_to_facing_suffix(move_input)
		
	update_animation()

func update_animation() -> void:
	var animation_name := StringName("%s_%s" % [NORMAL_ANIMATION_PREFIX, facing_suffix])
	
	if not body_spirit.sprite_frames.has_animation(animation_name):
		push_warning("Missing Player animation: %s" % animation_name)
		return
	
	if body_spirit.animation != animation_name:
		body_spirit.play(animation_name) 
		
func _vector_to_facing_suffix(direction: Vector2) -> StringName:
	if abs(direction.x) >= abs(direction.y): 
		return &"right" if direction.x > 0.0 else &"left"
		
	return &"down" if direction.y > 0.0 else &"up"
