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

func update_animation() -> void:
	
