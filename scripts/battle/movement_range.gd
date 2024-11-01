# scripts/battle/movement_range.gd
extends Node3D
class_name MovementRange

var _grid_manager: GridManager
var _range_indicators: Dictionary = {}  # 移動範囲表示用のインスタンス
var _current_range: Array[Vector2i] = []

func _init(manager: GridManager):
	_grid_manager = manager

func create_range_indicator() -> MeshInstance3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0, 1, 0, 0.3)  # 現在の透明度を0.3に
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# 追加: 上からも見えるように
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(_grid_manager.cell_size * 0.95, 0.2, _grid_manager.cell_size * 0.95)
	mesh.surface_set_material(0, material)
	
	var indicator = MeshInstance3D.new()
	indicator.mesh = mesh
	indicator.position.y = 0.15  # グリッドの少し上に表示
	
	return indicator

# 移動可能範囲を計算して表示
func show_movement_range(unit: Unit):
	clear_range_display()
	_current_range = calculate_movement_range(unit)
	
	for cell_pos in _current_range:
		var indicator = create_range_indicator()
		indicator.position = _grid_manager.grid_to_world(cell_pos)
		add_child(indicator)
		_range_indicators[cell_pos] = indicator

func is_cell_in_range(pos: Vector2i) -> bool:
	return pos in _current_range

# 移動範囲表示をクリア
func clear_range_display():
	_current_range.clear()
	for indicator in _range_indicators.values():
		indicator.queue_free()
	_range_indicators.clear()

# 移動可能範囲を計算
func calculate_movement_range(unit: Unit) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []  # 明示的に型付き配列を作成
	var checked = {}
	var queue = []
	
	# 開始位置を追加
	queue.push_back({"pos": unit.grid_position, "steps": 0})
	checked[unit.grid_position] = 0
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var current_pos = current["pos"]
		var steps = current["steps"]
		
		reachable.append(current_pos)
		
		# 移動範囲内の場合、隣接セルをチェック
		if steps < unit.move_range:
			for dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				var next_pos = current_pos + dir
				
				# 移動可能判定
				if _is_valid_movement(next_pos, checked, steps + 1):
					queue.push_back({"pos": next_pos, "steps": steps + 1})
					checked[next_pos] = steps + 1
	
	return reachable

# 移動可能判定
func _is_valid_movement(pos: Vector2i, checked: Dictionary, steps: int) -> bool:
	# グリッド範囲内か
	if not _grid_manager.is_valid_position(pos):
		return false
	
	# 未チェックか、より少ないステップ数で到達可能か
	if pos in checked and checked[pos] <= steps:
		return false
	
	# 他のユニットがいないか
	if _grid_manager.has_unit_at(pos):
		return false
	
	return true
