extends Resource
class_name CellData

@export var terrain_type: String = "plain"
@export var height: int = 0
@export var move_cost: float = 1.0
@export var is_walkable: bool = true

func _init(type: String = "plain", h: int = 0):
	terrain_type = type
	height = h
