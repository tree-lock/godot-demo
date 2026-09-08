extends Area2D

class_name Bullet

const WORLD_COLLISION_MASK := 1

@export var speed: float = 320.0
@export var max_lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var remaining_lieftime: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	remaining_lieftime = max_lifetime
	area_entered.connect(_on_area_entered)

func setup(initial_direction: Vector2) -> void:
	if initial_direction != Vector2.ZERO:
		direction = initial_direction.normalized()
	
	rotation = direction.angle()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	var current_position := global_position
	var next_position := current_position + direction * delta * speed
	
	if _will_hit_world(current_position, next_position): 
		queue_free()
		return
	
	global_position = next_position
	remaining_lieftime -= delta
	if remaining_lieftime <= 0.0:
		queue_free()
		
# 问物理引擎：从 from 飞到 to 的这段路上，会不会撞到「世界墙」（地面、空气墙等）。
func _will_hit_world(from_position: Vector2, to_position: Vector2) -> bool:
	# Godot 不能直接 for 循环扫障碍物，要先拿到物理世界的查询入口。
	# get_world_2d()：当前 2D 场景所属的物理世界（一份碰撞地图）。
	# direct_space_state：这个世界的即时查询器，专门做射线检测。
	var space_state := get_world_2d().direct_space_state
	# 物理世界还没准备好时查询器是 null，没法检测，当作没撞墙，避免空指针。
	if space_state == null:
		return false

	# 先组装射线参数，还没真正检测。类比 new Request(...)，请求还没发出去。
	# create(起点, 终点, 碰撞层掩码)：
	#   from / to = 这一帧位置 → 下一帧位置，只预扫这一小段位移
	#   WORLD_COLLISION_MASK = 1，只打 layer 1（位掩码 0001）。
	#   类似只查 class="world"，忽略敌人/子弹。
	var query := PhysicsRayQueryParameters2D.create(
		from_position,
		to_position,
		WORLD_COLLISION_MASK
	)

	# body = 实心刚体（StaticBody2D / CharacterBody2D）。空气墙、地面都是这个，必须开。
	query.collide_with_bodies = true
	# Area2D 是触发器，不是实心墙；打敌人走 area_entered，不走这条射线。
	query.collide_with_areas = false

	# 真正发出检测：沿这条线段问「中间有没有东西」。
	# 命中时 Dictionary 里有 collider / position / normal 等；没撞到则是空字典。
	var hit_result: Dictionary = space_state.intersect_ray(query)
	# 空 = 没撞到；有内容 = 撞到世界。
	return not hit_result.is_empty()

func _on_area_entered(area: Area2D) -> void:
	if area is Bullet:
		return
		
	queue_free()
