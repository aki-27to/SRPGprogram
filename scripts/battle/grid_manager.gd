# grid_manager.gd
extends Node3D
class_name GridManager

const MovementRangeClass := preload("res://scripts/battle/movement_range.gd")

signal cell_selected(position: Vector2i)
signal cell_highlighted(position: Vector2i)
signal cell_unhighlighted(position: Vector2i)

@export var grid_size: Vector2i = Vector2i(10, 10)
@export var cell_size: float = 1.0

var attack_range: AttackRange
var movement_range: MovementRange  
var turn_manager: TurnManager

var grid_data: Dictionary = {}
var visualization_node: Node3D
var selected_cell_indicator: MeshInstance3D = null
# ユニット管理用の変数を追加
var units: Dictionary = {}  # キー: Vector2i（位置）, 値: Unit
var selected_unit: Unit = null

func _ready():
    _initialize_grid()
    _create_visualization()
    _create_selection_indicator()
    
    # 移動範囲システムの初期化
    movement_range = MovementRangeClass.new(self)
    add_child(movement_range)
    
    # 攻撃範囲システムの初期化
    attack_range = AttackRange.new(self)
    add_child(attack_range)
    
    # ターン管理システムの初期化
    turn_manager = TurnManager.new()
    add_child(turn_manager)
    # 重要：シグナル接続の確認
    if not turn_manager.turn_changed.is_connected(_on_turn_changed):
        turn_manager.turn_changed.connect(_on_turn_changed)

func _initialize_grid():
    for x in range(grid_size.x):
        for y in range(grid_size.y):
            var pos = Vector2i(x, y)
            grid_data[pos] = CellData.new()

func _create_visualization():
    visualization_node = Node3D.new()
    add_child(visualization_node)
    
    var material = StandardMaterial3D.new()
    material.albedo_color = Color(0.8, 0.8, 0.8, 1.0)
    
    var mesh = BoxMesh.new()
    mesh.size = Vector3(cell_size * 0.9, 0.1, cell_size * 0.9)
    mesh.surface_set_material(0, material)
    
    for x in range(grid_size.x):
        for y in range(grid_size.y):
            var static_body = StaticBody3D.new()  # 物理ボディを追加
            var collision_shape = CollisionShape3D.new()
            var box_shape = BoxShape3D.new()
            box_shape.size = Vector3(cell_size * 0.9, 0.1, cell_size * 0.9)
            collision_shape.shape = box_shape
            
            var mesh_instance = MeshInstance3D.new()
            mesh_instance.mesh = mesh
            
            static_body.add_child(collision_shape)
            static_body.add_child(mesh_instance)
            static_body.position = grid_to_world(Vector2i(x, y))
            
            visualization_node.add_child(static_body)

func _create_selection_indicator():
    var material = StandardMaterial3D.new()
    material.albedo_color = Color(1.0, 1.0, 0.0, 0.5)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    
    var mesh = BoxMesh.new()
    mesh.size = Vector3(cell_size * 0.95, 0.2, cell_size * 0.95)
    mesh.surface_set_material(0, material)
    
    selected_cell_indicator = MeshInstance3D.new()
    selected_cell_indicator.mesh = mesh
    selected_cell_indicator.visible = false
    add_child(selected_cell_indicator)

# grid_manager.gd内の_input関数を修正

func _input(event):
    # プレイヤーターンでない場合は早期リターン
    if not turn_manager.is_player_turn():
        return
    
    # スペースキーでの行動終了処理を追加
    if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
        if selected_unit:
            print("Action finished by space key")  # デバッグ用
            _finish_current_action()
            return

    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        print("Processing player input")  # デバッグ出力追加
        var camera = get_viewport().get_camera_3d()
        if camera:
            print("Camera found")  # デバッグ追加
            var from = camera.project_ray_origin(event.position)
            var to = from + camera.project_ray_normal(event.position) * 1000.0
            var space_state = get_world_3d().direct_space_state
            var query = PhysicsRayQueryParameters3D.create(from, to)
            var result = space_state.intersect_ray(query)
            
            print("Ray result: ", result)  # デバッグ追加
            
            if result:
                var grid_pos = world_to_grid(result.position)
                print("Grid position calculated: ", grid_pos)  # デバッグ追加
                if is_valid_position(grid_pos):
                    _select_cell(grid_pos)

# 行動終了処理を追加
func _finish_current_action():
    if selected_unit:
        print("Finishing current action")  # デバッグ用
        selected_unit.end_action()
        selected_unit = null
        movement_range.clear_range_display()
        attack_range.clear_range_display()
        turn_manager.end_turn()

func execute_movement(unit: Unit, target_pos: Vector2i):
    print("Executing movement to: ", target_pos)  # デバッグ追加
    if move_unit(unit, target_pos):
        unit.has_moved = true
        movement_range.clear_range_display()
        
        # 攻撃範囲の表示（移動後）
        if not unit.has_attacked:
            print("Showing attack range after movement")  # デバッグ追加
            attack_range.show_attack_range(unit)
        else:
            print("Unit has already attacked, ending turn")  # デバッグ追加
            unit.end_action()
            selected_unit = null
            turn_manager.end_turn()


# ターン管理関連の処理を追加
func _on_turn_changed(_team: int):
    print("Turn changed callback triggered")  # デバッグ追加
    selected_unit = null
    movement_range.clear_range_display()
    
    # 敵のターンになったら自動で行動を実行
    if not turn_manager.is_player_turn():
        print("Starting enemy turn processing")  # デバッグ追加
        execute_enemy_turn()

# 敵の行動処理
# grid_manager.gdのexecute_enemy_turn()を修正
func execute_enemy_turn():
    print("Execute enemy turn started")
    print("Enemy units: ", turn_manager.active_units[TurnManager.Team.ENEMY].size())
    
    for unit in turn_manager.active_units[TurnManager.Team.ENEMY]:
        print("Processing enemy unit: ", unit)
        if not unit.has_acted:
            print("Enemy unit acting")
            var target_pos = find_closest_player_unit_position(unit)
            if target_pos != Vector2i(-1, -1):
                print("Target position found: ", target_pos)
                # 移動実行
                var move_pos = calculate_movement_toward_target(unit, target_pos)
                if move_unit(unit, move_pos):  # 移動が成功した場合のみ
                    unit.has_moved = true  # 移動フラグを設定
                    
                    # 攻撃可能な対象がいるか確認
                    var attack_cells = attack_range.calculate_attack_range(unit)
                    for attack_pos in attack_cells:
                        var possible_target = get_unit_at(attack_pos)
                        if possible_target and possible_target.team != unit.team:
                            print("Enemy executing attack")
                            unit.perform_attack(possible_target)
                            unit.has_attacked = true
                            break
                
                # 行動終了処理を必ず実行
                print("Enemy unit finishing action")
                unit.end_action()
                movement_range.clear_range_display()
                attack_range.clear_range_display()
    
    print("Enemy turn complete")
    turn_manager.end_turn()

# 最も近いプレイヤーユニットの位置を見つける
func find_closest_player_unit_position(enemy_unit: Unit) -> Vector2i:
    var closest_distance = 999
    var closest_pos = Vector2i(-1, -1)
    
    for unit in turn_manager.active_units[TurnManager.Team.PLAYER]:
        var distance = calculate_grid_distance(enemy_unit.grid_position, unit.grid_position)
        if distance < closest_distance:
            closest_distance = distance
            closest_pos = unit.grid_position
            print("Found player unit at: ", closest_pos, " distance: ", closest_distance)
    
    return closest_pos

# グリッド上の2点間の距離を計算
func calculate_grid_distance(from: Vector2i, to: Vector2i) -> int:
    return abs(from.x - to.x) + abs(from.y - to.y)

# ターゲットに向かう移動位置を計算
func calculate_movement_toward_target(unit: Unit, target_pos: Vector2i) -> Vector2i:
    var possible_moves = movement_range.calculate_movement_range(unit)
    var best_move = unit.grid_position
    var best_distance = 999
    
    print("Calculating movement toward: ", target_pos)
    print("Possible moves: ", possible_moves)
    
    for move in possible_moves:
        var distance = calculate_grid_distance(move, target_pos)
        if distance < best_distance:
            best_distance = distance
            best_move = move
            print("Found better move: ", best_move, " distance: ", best_distance)
    
    return best_move

func is_valid_position(pos: Vector2i) -> bool:
    return pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y

func get_cell_data(pos: Vector2i) -> CellData:
    return grid_data.get(pos)

func world_to_grid(world_pos: Vector3) -> Vector2i:
    return Vector2i(
        int(world_pos.x / cell_size),
        int(world_pos.z / cell_size)
    )

func grid_to_world(grid_pos: Vector2i) -> Vector3:
    return Vector3(
        grid_pos.x * cell_size,
        0,
        grid_pos.y * cell_size
    )

# ユニット配置メソッド
func place_unit(unit: Unit, pos: Vector2i) -> bool:
    if not is_valid_position(pos) or has_unit_at(pos):
        return false
    
    if units.has(unit):
        var old_pos = units.find_key(unit)
        units.erase(old_pos)
    
    units[pos] = unit
    unit.grid_position = pos
    unit.position = grid_to_world(pos)
    return true

# 指定位置のユニット取得
func get_unit_at(pos: Vector2i) -> Unit:
    return units.get(pos)

# 指定位置にユニットが存在するか確認
func has_unit_at(pos: Vector2i) -> bool:
    return units.has(pos)

# ユニットの移動
func move_unit(unit: Unit, new_pos: Vector2i) -> bool:
    if not is_valid_position(new_pos) or has_unit_at(new_pos):
        return false
    
    var old_pos = unit.grid_position
    if place_unit(unit, new_pos):
        unit.unit_moved.emit(old_pos, new_pos)
        return true
    return false
    
# ユニット選択処理を更新
# grid_manager.gd の _select_cell 関数を修正
func _select_cell(grid_pos: Vector2i):
    if not is_valid_position(grid_pos) or not turn_manager.is_player_turn():
        return

    print("Selecting cell: ", grid_pos)  # デバッグ追加
    var unit = get_unit_at(grid_pos)
    
    # 選択中のユニットがある場合
    if selected_unit:
        print("Selected unit exists: ", selected_unit)  # デバッグ追加
        
        # 攻撃可能な敵ユニット
        if unit and unit.team != selected_unit.team and attack_range.is_in_attack_range(grid_pos):
            print("Attacking enemy unit")  # デバッグ追加
            selected_unit.perform_attack(unit)
            selected_unit.has_attacked = true
            attack_range.clear_range_display()
            selected_unit.end_action()
            selected_unit = null
            turn_manager.end_turn()
            return
            
        # 移動可能なセル
        if movement_range.is_cell_in_range(grid_pos):
            print("Moving to cell")  # デバッグ追加
            execute_movement(selected_unit, grid_pos)
            return
    
    # 新しいユニットの選択
    if unit and unit.team == 0 and not unit.has_acted:
        print("Selected new unit")  # デバッグ追加
        selected_unit = unit
        if not unit.has_moved:
            var movement_cells = movement_range.calculate_movement_range(unit)
            movement_range.show_movement_range(unit)
            attack_range.show_attack_range(unit, movement_cells)
        elif not unit.has_attacked:
            attack_range.show_attack_range(unit)
    
    selected_cell_indicator.visible = true
    selected_cell_indicator.position = grid_to_world(grid_pos)
    cell_selected.emit(grid_pos)
