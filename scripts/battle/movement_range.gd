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
    print("=== Movement Range Display Start ===")
    print("Current unit position: ", unit.grid_position)
    clear_range_display()
    _current_range = calculate_movement_range(unit)
    print("All reachable positions: ", _current_range)
    
    # 移動可能範囲の表示（敵ユニットの位置は除外しない）
    for cell_pos in _current_range:
        # 敵ユニットがいる場合は表示をスキップ（attack_rangeで表示する）
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
    print("==== Starting movement range calculation ====")
    print("Unit position: ", unit.grid_position)
    _movement_map.clear()
    var reachable: Array[Vector2i] = []
    
    # 初期位置を明示的に追加
    reachable.append(unit.grid_position)
    _movement_map[unit.grid_position] = unit.move_range
    print("Added initial position to reachable: ", unit.grid_position)
    
    var queue = [{
        "pos": unit.grid_position,
        "remaining": unit.move_range
    }]
    
    while not queue.is_empty():
        var current = queue.pop_front()
        var pos = current["pos"]
        var remaining = current["remaining"]
        
        # 移動力が0以下になった場合はスキップ
        if remaining <= 0:
            continue
            
        # 各方向の探索
        for dir in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
            var next_pos = pos + dir
            var next_remaining = remaining - 1
            
            if _is_valid_movement_destination(next_pos):
                # 未到達、もしくはより多くの移動力が残る経路を発見した場合
                if not (next_pos in _movement_map) or _movement_map[next_pos] < next_remaining:
                    _movement_map[next_pos] = next_remaining
                    queue.push_back({
                        "pos": next_pos,
                        "remaining": next_remaining
                    })
                    if not (next_pos in reachable):
                        print("Adding position to reachable: ", next_pos, " with remaining moves: ", next_remaining)
                        reachable.append(next_pos)
    return reachable

# 移動先の有効性チェック
func _is_valid_movement_destination(pos: Vector2i) -> bool:
    if not _grid_manager.is_valid_position(pos):
        print("Position invalid - out of grid")
        return false
    
    # 自分自身の位置は移動可能とする
    if pos == _current_unit.grid_position:
        print("Position valid - current position")
        return true

    # 味方ユニットがいる場所には移動できない
    var target_unit = _grid_manager.get_unit_at(pos)
    if target_unit and target_unit.team == _current_unit.team:
        print("Position invalid - friendly unit at: ", pos)
        return false
            
    print("Position valid for movement")
    return true

func is_cell_in_range(pos: Vector2i) -> bool:
    print("Checking if cell ", pos, " is in range")
    print("Current range during check: ", _current_range)
    var result = pos in _current_range
    print("Check result: ", result)
    return result

func clear_range_display():
    _current_range.clear()
    for indicator in _range_indicators.values():
        indicator.queue_free()
    _range_indicators.clear()
