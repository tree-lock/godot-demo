extends Node2D

@export_group("刷怪资源")
@export var enemy_scene: PackedScene = preload("res://scene/enemy.tscn")
@export var enemy_configs: Array[EnemyConfig] = [
	preload("res://resources/config/enemy_basic.tres"),
	preload("res://resources/config/enemy_shelled.tres"),
	preload("res://resources/config/enemy_fast.tres"),
	preload("res://resources/config/enemy_bomber.tres"),
]

@export_group("刷怪节奏")
@export_range(0, 100, 1, "or_greater") var initial_spawn_count: int = 1
@export_range(1, 20, 1, "or_greater") var spawn_count_per_tick: int = 1
@export_range(0.1, 60.0, 0.1, "or_greater") var spawn_interval: float = 1.5
@export_range(0.1, 60.0, 0.1, "or_greater") var min_spawn_interval: float = 0.6
@export_range(1, 200, 1, "or_greater") var max_alive_enemies: int = 12
@export_range(1.0, 3600.0, 0.1, "or_greater") var spawn_acceleration_duration: float = 60.0 

@onready var player: Player = $Player
@onready var enemy_container: Node2D = $EnemyContainer
@onready var enemy_spawn_points_root: Node2D = $EnemySpawnPoints
@onready var enemy_spawn_timer: Timer = $EnemySpawnTimer

var random_generator: RandomNumberGenerator = RandomNumberGenerator.new()
var enemy_spawn_points: Array[Marker2D] = []
var available_enemy_configs: Array[EnemyConfig] = []
var game_time_elapsed: float = 0.0

func _ready() -> void:
	random_generator.randomize()
	_collect_enemy_spawn_points()
	_collect_enemy_configs()
	_configure_enemy_spawn_timer()
	_spawn_initial_enemies()
	_start_enemy_spawn_timer()

func _process(delta: float) -> void:
	game_time_elapsed += delta
	_update_spawn_interval()

func _collect_enemy_spawn_points() -> void:
	enemy_spawn_points.clear()

	for child in enemy_spawn_points_root.get_children():
		var spawn_point: Marker2D = child as Marker2D
		if spawn_point != null:
			enemy_spawn_points.append(spawn_point)


	if enemy_spawn_points.is_empty():
		push_warning("No enemy spawn points found in EnemySpawnPoints node")


func _collect_enemy_configs() -> void:
	available_enemy_configs.clear()

	for config in enemy_configs:
		if config != null:
			available_enemy_configs.append(config)

	if available_enemy_configs.is_empty():
		push_warning("No enemy configs found in EnemyConfigs array")

func _configure_enemy_spawn_timer() -> void:
	enemy_spawn_timer.one_shot = false
	enemy_spawn_timer.wait_time = _get_current_spawn_interval()

	if not enemy_spawn_timer.timeout.is_connected(_on_enemy_spawn_timer_timeout):
		enemy_spawn_timer.timeout.connect(_on_enemy_spawn_timer_timeout)


func _update_spawn_interval() -> void:
	var current_interval: float = _get_current_spawn_interval()

	if is_equal_approx(enemy_spawn_timer.wait_time, current_interval):
		return
	
	enemy_spawn_timer.wait_time = current_interval

	if enemy_spawn_timer.is_stopped():
		return
	if enemy_spawn_timer.time_left <= current_interval:
		return

	enemy_spawn_timer.start(current_interval)


func _get_current_spawn_interval() -> float:
	var start_interval: float = maxf(spawn_interval, 0.1)
	var end_interval: float = minf(maxf(min_spawn_interval, 0.1), start_interval)

	if spawn_acceleration_duration <= 0.0:
		return end_interval

	
	var difficulty_ratio := clampf(game_time_elapsed / spawn_acceleration_duration, 0.0, 1.0)
	return lerp(start_interval, end_interval, difficulty_ratio)

func _spawn_initial_enemies() -> void:
	for i in range(initial_spawn_count):
		if not _try_spawn_enemy():
			break

func _start_enemy_spawn_timer() -> void:
	if not _is_spawn_system_ready():
		return
	
	enemy_spawn_timer.start()

func _on_enemy_spawn_timer_timeout() -> void:
	for i in range(spawn_count_per_tick):
		if not _try_spawn_enemy():
			break


func _try_spawn_enemy() -> bool:
	if not _is_spawn_system_ready():
		return false

	if _get_alive_enemy_count() >= max_alive_enemies:
		return false

	var spawn_point := _pick_spawn_point()
	if spawn_point == null:
		return false
	
	var enemy_config := _pick_enemy_config()
	if enemy_config == null:
		return false

	var enemy_instance := enemy_scene.instantiate() as Enemy
	if enemy_instance == null:
		push_warning("Failed to instantiate enemy scene")
		return false

	enemy_container.add_child(enemy_instance)
	enemy_instance.global_position = spawn_point.global_position
	enemy_instance.setup(enemy_config, player)
	
	return true

func _is_spawn_system_ready() -> bool:
	return (
		player != null and
		enemy_scene != null and
		not enemy_spawn_points.is_empty() and
		not available_enemy_configs.is_empty()
	)

func _pick_spawn_point() -> Marker2D:
	if enemy_spawn_points.is_empty():
		return null
	
	var random_index: int = random_generator.randi_range(0, enemy_spawn_points.size() - 1)
	return enemy_spawn_points[random_index]

func _pick_enemy_config() -> EnemyConfig:
	if available_enemy_configs.is_empty():
		return null
	
	var random_index: int = random_generator.randi_range(0, available_enemy_configs.size() - 1)
	return available_enemy_configs[random_index]


func _get_alive_enemy_count() -> int:
	var alive_enemy_count := 0

	for child in enemy_container.get_children():
		if child is Enemy:
			alive_enemy_count += 1
		
	
	return alive_enemy_count
