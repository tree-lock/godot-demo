extends CharacterBody2D
class_name Enemy

const DEFAULT_BULLET_DAMAGE := 1
const BLINK_ENABLED_SHADER_PARAMETER := &"blink_enabled"
const PICKUP_SCENE := preload("res://scene/pickup.tscn")
const EXPLOSION_QUERY_MAX_RESULTS := 16

enum DeathSequenceStage {
	NONE,
	DEATH,
	EXPLOSION
}

@export var config: EnemyConfig
@export var touch_damage: int = 1
@export var touch_damage_interval: float = 0.5
@export var hurt_blink_duration: float = 0.16

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var touch_damage_area: Area2D = $TouchDamageArea
@onready var touch_damage_shape: CollisionShape2D = $TouchDamageArea/CollisionShape2D
@onready var explosion_area: Area2D = $ExplosionArea
@onready var explosion_shape: CollisionShape2D = $ExplosionArea/CollisionShape2D


var target_player: Player = null
var current_health: int = 1
var is_dead: bool = false
var touch_damage_cooldown_left: float = 0.0
var touched_player: Player = null
var hurt_blink_time_left: float = 0.0
var death_sequence_stage: DeathSequenceStage = DeathSequenceStage.NONE
var death_animation_name_in_use: StringName = &""
var random_generator: RandomNumberGenerator = RandomNumberGenerator.new()
