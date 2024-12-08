# scripts/battle/movement_range.gd
extends Node3D
class_name MovementRange

var _grid_manager: GridManager
var _range_indicators: Dictionary = {}  # 移動範囲表示用のインスタンス
var _current_range: Array[Vector2i] = []
var _movement_map: Dictionary = {}  # 残り移動力を記録するマップ
var _current_unit: Unit = null

func _init(manager: GridManager):
	_grid_manager = manager

func create_range_indicator() -> MeshInstance3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0, 0, 1, 0.3) 
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(_grid_manager.cell_size * 0.95, 0.2, _grid_manager.cell_size * 0.95)
	mesh.surface_set_material(0, material)
	
	var indicator = MeshInstance3D.new()
	indicator.mesh = mesh
	indicator.position.y = 0.1
	
	return indicator

# 移動可能範囲を計算して表示
func show_movement_range(unit: Unit):
	clear_range_display()
	_current_range = calculate_movement_range(unit)
	
	for cell_pos in _current_range:
		var target_unit = _grid_manager.get_unit_at(cell_pos)
		if target_unit and target_unit.team != unit.team:
			continue
			
		var indicator = create_range_indicator()
		var world_pos = _grid_manager.grid_to_world(cell_pos)
		world_pos.y = 0.1
		indicator.position = world_pos
		add_child(indicator)
		_range_indicators[cell_pos] = indicator

# 移動可能範囲を計算
func calculate_movement_range(unit: Unit) -> Array[Vector2i]:
	_current_unit = unit
	_movement_map.clear()
	var reachable: Array[Vector2i] = []
	
	reachable.append(unit.grid_position)
	_movement_map[unit.grid_position] = unit.move_range
	
	var queue = [{
		"pos": unit.grid_position,
		"remaining": unit.move_range
	}]
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var pos = current["pos"]
		var remaining = current["remaining"]
		
		if remaining <= 0:
			continue
			
		for dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next_pos = pos + dir
			var next_remaining = remaining - 1
			
			if _is_valid_movement_destination(next_pos):
				if not (next_pos in _movement_map) or _movement_map[next_pos] < next_remaining:
					_movement_map[next_pos] = next_remaining
					queue.push_back({
						"pos": next_pos,
						"remaining": next_remaining
					})
					if not (next_pos in reachable):
						reachable.append(next_pos)
	return reachable

# 移動先の有効性チェック
func _is_valid_movement_destination(pos: Vector2i) -> bool:
	if not _grid_manager.is_valid_position(pos):
		return false
	
	if pos == _current_unit.grid_position:
		return true

	var target_unit = _grid_manager.get_unit_at(pos)
	if target_unit and target_unit.team == _current_unit.team:
		return false
			
	return true

func is_cell_in_range(pos: Vector2i) -> bool:
	return pos in _current_range

func clear_range_display():
	_current_range.clear()
	for indicator in _range_indicators.values():
		indicator.queue_free()
	_range_indicators.clear()
