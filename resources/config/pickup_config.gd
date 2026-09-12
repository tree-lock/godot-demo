extends Resource

class_name PickupConfig

enum PickupType {
	SPEED,
	RAPID,
	SPIRAL,
}

enum PlayerFormMode {
	NORMAL,
	ARMED,
}


enum ShotPattern {
	NORMAL,
	SPIRAL,
}


@export_group("基础信息")

@export var pickup_type: PickupType = PickupType.SPEED

@export var display_name: String = "移速道具"

@export_range(0.0, 1000.0, 0.1, "or_greater") var drop_weight: float = 1.0


@export_group("显示资源")

@export var icon_texture: Texture2D
