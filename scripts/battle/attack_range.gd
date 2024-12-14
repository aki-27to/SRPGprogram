# attack_range.gd
extends Node3D
class_name AttackRange

var _grid_manager: GridManager
var _range_indicators: Dictionary = {}

func set_grid_manager(manager: GridManager):
	_grid_manager = manager

# 色指定を追加
func create_range_indicator(is_attack: bool = false) -> MeshInstance3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.0, 0.0, 0.3) if is_attack else Color(0.0, 0.0, 1.0, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(_grid_manager.cell_size * 0.95, 0.2, _grid_manager.cell_size * 0.95)
	mesh.surface_set_material(0, material)
	
	var indicator = MeshInstance3D.new()
	indicator.mesh = mesh
	indicator.position.y = 0.1
	
	return indicator

# movement_cellsパラメータを追加
func show_attack_range(unit: Unit, movement_cells: Array = []):
	clear_range_display()
	var attack_cells = calculate_attack_range(unit)
	
	# まず移動可能範囲内の敵ユニットをチェック
	if not movement_cells.is_empty():
		for cell_pos in movement_cells:
			var target_unit = _grid_manager.get_unit_at(cell_pos)
			if target_unit and target_unit.team != unit.team:
				# 敵ユニットの位置を赤で表示
				var indicator = create_range_indicator(true)  # 赤色
				indicator.position = _grid_manager.grid_to_world(cell_pos)
				add_child(indicator)
				_range_indicators[cell_pos] = indicator

	# 通常の攻撃範囲表示（移動後の攻撃範囲）
	if movement_cells.is_empty():
		for cell_pos in attack_cells:
			if not (cell_pos in _range_indicators):
				var indicator = create_range_indicator(true)
				indicator.position = _grid_manager.grid_to_world(cell_pos)
				add_child(indicator)
				_range_indicators[cell_pos] = indicator

func calculate_attack_range(unit: Unit) -> Array:
	var attackable = []
	var pos = unit.grid_position
	
	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)
	]
	
	for dir in directions:
		var target_pos = pos + dir
		if _grid_manager.is_valid_position(target_pos):
			attackable.append(target_pos)
	
	return attackable

func clear_range_display():
	for indicator in _range_indicators.values():
		indicator.queue_free()
	_range_indicators.clear()

func is_in_attack_range(pos: Vector2i) -> bool:
	return pos in _range_indicators
