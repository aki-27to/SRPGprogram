# grid_manager.gd
extends Node3D
class_name GridManager

const MovementRangeClass := preload("res://scripts/battle/movement_range.gd")

signal cell_selected(position: Vector2i)
signal cell_highlighted(position: Vector2i)
signal cell_unhighlighted(position: Vector2i)
signal turn_changed(team: int)

@onready var battle_ui: BattleUI = $"../BattleUI"
@export var grid_size: Vector2i = Vector2i(10, 10)
@export var cell_size: float = 1.0

enum Team { PLAYER = 0, ENEMY = 1 }
enum ActionType { ATTACK, MAGIC, WAIT }

# --- フィールド変数 ---
var attack_range: AttackRange
var movement_range: MovementRange  
var turn_manager: TurnManager
var current_team: int = Team.PLAYER
var active_units: Dictionary = {
    Team.PLAYER: [],
    Team.ENEMY: []
}
var grid_data: Dictionary = {}
var visualization_node: Node3D
var selected_cell_indicator: MeshInstance3D = null

# ユニット関連
var units: Dictionary = {}  # キー: Vector2i（位置）, 値: Unit
var selected_unit: Unit = null

# 状態フラグ
var waiting_for_turn_end: bool = false
var selected_action: ActionType = ActionType.ATTACK
var waiting_for_direction: bool = false
var is_in_action: bool = false

# 状態保存用
var previous_state: Dictionary = {}
var selected_unit_previous_position: Vector2i = Vector2i(-1, -1)
var has_moved_previous_state: bool = false
var has_attacked_previous_state: bool = false
var has_acted_previous_state: bool = false

func _ready():
    _initialize_grid()
    _create_visualization()
    _create_selection_indicator()

    movement_range = MovementRangeClass.new(self)
    add_child(movement_range)

    attack_range = AttackRange.new(self)
    add_child(attack_range)

    turn_manager = TurnManager.new()
    add_child(turn_manager)
    _connect_turn_signals()

    # 初期UI設定
    battle_ui.hide_action_buttons()
    battle_ui.connect_action_buttons(self)

func _connect_turn_signals():
    if not turn_manager.turn_changed.is_connected(_on_turn_changed):
        turn_manager.turn_changed.connect(_on_turn_changed)

#==================================================
# 初期化系
#==================================================
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
            _create_single_cell_visual(x, y, mesh)

func _create_single_cell_visual(x: int, y: int, mesh: BoxMesh):
    var static_body = StaticBody3D.new()
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

#==================================================
# 入力処理
#==================================================
func _input(event):
    if not turn_manager.is_player_turn():
        return
    
    if _handle_waiting_direction_input(event):
        return
    
    if _handle_key_z_input(event):
        return

    if _handle_key_space_input(event):
        return

    if _handle_mouse_left_click(event):
        return

func _handle_waiting_direction_input(event) -> bool:
    if waiting_for_direction and selected_unit and event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_UP:
                selected_unit.set_direction(Vector2i.UP)
            KEY_DOWN:
                selected_unit.set_direction(Vector2i.DOWN)
            KEY_LEFT:
                selected_unit.set_direction(Vector2i.RIGHT)
            KEY_RIGHT:
                selected_unit.set_direction(Vector2i.LEFT)
            KEY_SPACE:
                _finish_current_action()
                return true
            KEY_Z:
                waiting_for_direction = false
                battle_ui.show_action_buttons()
                return true
    return false

func _handle_key_z_input(event) -> bool:
    if event is InputEventKey and event.pressed and event.keycode == KEY_Z:
        if is_in_action:
            # 状態復元
            restore_state()
            is_in_action = false

            # 状態復元後に攻撃選択中であれば攻撃範囲をクリア
            if selected_action == ActionType.ATTACK:
                cancel_attack() # 攻撃範囲非表示と3択表示を行う
            else:
                # 攻撃中でない場合は本来の再表示処理
                _redisplay_ranges_after_restore()
            return true

        elif selected_unit:
            # selected_unitがいるがis_in_actionでない場合
            # 通常のキャンセル処理
            if selected_action == ActionType.ATTACK:
                cancel_attack()
                return true
            elif selected_unit.has_moved:
                cancel_movement()
                return true
    return false

func _redisplay_ranges_after_restore():
    if selected_unit:
        if not selected_unit.has_moved:
            var movement_cells = movement_range.calculate_movement_range(selected_unit)
            movement_range.show_movement_range(selected_unit)
            attack_range.show_attack_range(selected_unit, movement_cells)
        elif not selected_unit.has_attacked:
            attack_range.show_attack_range(selected_unit)

func _handle_key_space_input(event) -> bool:
    if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
        if waiting_for_turn_end:
            _finish_turn()
            return true
        elif selected_unit:
            select_action(ActionType.WAIT)
            return true
    return false

func _handle_mouse_left_click(event) -> bool:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var camera = get_viewport().get_camera_3d()
        if camera:
            var from = camera.project_ray_origin(event.position)
            var to = from + camera.project_ray_normal(event.position) * 1000.0
            var space_state = get_world_3d().direct_space_state
            var query = PhysicsRayQueryParameters3D.create(from, to)
            var result = space_state.intersect_ray(query)
            if result:
                var grid_pos = world_to_grid(result.position)
                if is_valid_position(grid_pos):
                    _select_cell(grid_pos)
                    return true
    return false

#==================================================
# ターン終了処理
#==================================================
func _finish_turn():
    waiting_for_turn_end = false
    battle_ui.hide_turn_end_button()
    turn_manager.end_turn()

#==================================================
# 行動終了処理
#==================================================
func _finish_current_action():
    if not selected_unit:
        return

    if waiting_for_direction:
        _finish_wait_action()
    else:
        _finish_generic_action()

func _finish_wait_action():
    waiting_for_direction = false
    selected_unit.end_action()
    selected_unit = null
    _clear_ranges()
    waiting_for_turn_end = true
    battle_ui.show_turn_end_button()

func _finish_generic_action():
    selected_unit.end_action()
    selected_unit = null
    _clear_ranges()
    waiting_for_turn_end = true
    battle_ui.show_turn_end_button()
    battle_ui.hide_action_buttons()

func _clear_ranges():
    movement_range.clear_range_display()
    attack_range.clear_range_display()

#==================================================
# ユニット移動・アクション選択
#==================================================
func execute_movement(unit: Unit, target_pos: Vector2i):
    if await move_unit(unit, target_pos):
        _store_pre_movement_state(unit)
        unit.has_moved = true
        _clear_ranges()
        battle_ui.show_unit_info(unit)
        
        if not unit.has_attacked:
            battle_ui.show_action_buttons()
            selected_action = ActionType.ATTACK
        else:
            _auto_end_turn_after_movement()

func _store_pre_movement_state(unit: Unit):
    is_in_action = true
    selected_unit_previous_position = unit.grid_position
    has_moved_previous_state = unit.has_moved
    has_attacked_previous_state = unit.has_attacked
    has_acted_previous_state = unit.has_acted

func _auto_end_turn_after_movement():
    selected_unit.end_action()
    selected_unit = null
    battle_ui.hide_unit_info()
    turn_manager.end_turn()
    battle_ui.hide_action_buttons()

func select_action(action_type: ActionType):
    selected_action = action_type
    is_in_action = true
    save_state()

    match selected_action:
        ActionType.ATTACK:
            battle_ui.hide_action_buttons()
            if selected_unit:
                attack_range.show_attack_range(selected_unit)
        ActionType.MAGIC:
            _finish_current_action()
        ActionType.WAIT:
            battle_ui.hide_action_buttons()
            waiting_for_direction = true  # 向き選択モード

#==================================================
# ターン変更処理
#==================================================
func _on_turn_changed(_team: int):
    selected_unit = null
    _clear_ranges()
    battle_ui.hide_action_buttons()
    if not turn_manager.is_player_turn():
        execute_enemy_turn()

#==================================================
# 敵ターン・AI関連
#==================================================
func execute_enemy_turn():
    print("Execute enemy turn started")
    print("Enemy units: ", turn_manager.active_units[TurnManager.Team.ENEMY].size())
    
    for unit in turn_manager.active_units[TurnManager.Team.ENEMY]:
        if not unit.has_acted:
            _enemy_act(unit)
    print("Enemy turn complete")
    turn_manager.end_turn()

func _enemy_act(enemy_unit: Unit):
    print("Enemy unit acting")
    var target_pos = find_closest_player_unit_position(enemy_unit)
    if target_pos != Vector2i(-1, -1):
        _enemy_try_attack_or_move(enemy_unit, target_pos)
    enemy_unit.end_action()
    _clear_ranges()
    battle_ui.hide_action_buttons()

func _enemy_try_attack_or_move(enemy_unit: Unit, target_pos: Vector2i):
    var attack_cells = attack_range.calculate_attack_range(enemy_unit)
    var can_attack = false
    var target_unit = null
    for attack_pos in attack_cells:
        target_unit = get_unit_at(attack_pos)
        if target_unit and target_unit.team == TurnManager.Team.PLAYER:
            can_attack = true
            break
    
    if can_attack and target_unit:
        enemy_unit.perform_attack(target_unit)
    else:
        # 移動して攻撃
        var move_pos = calculate_movement_toward_target(enemy_unit, target_pos)
        if await move_unit(enemy_unit, move_pos):
            attack_cells = attack_range.calculate_attack_range(enemy_unit)
            for attack_pos in attack_cells:
                target_unit = get_unit_at(attack_pos)
                if target_unit and target_unit.team == TurnManager.Team.PLAYER:
                    enemy_unit.perform_attack(target_unit)
                    break

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

#==================================================
# Utility系(計算系)
#==================================================
func calculate_grid_distance(from: Vector2i, to: Vector2i) -> int:
    return abs(from.x - to.x) + abs(from.y - to.y)

func calculate_movement_toward_target(unit: Unit, target_pos: Vector2i) -> Vector2i:
    var possible_moves = movement_range.calculate_movement_range(unit)
    var best_move = unit.grid_position
    var best_distance = 999
    
    print("Calculating movement toward: ", target_pos)
    print("Possible moves from movement range: ", possible_moves)
    
    for move in possible_moves:
        var distance = calculate_grid_distance(move, target_pos)
        if distance < best_distance:
            best_distance = distance
            best_move = move
            print("Found better move: ", best_move, " distance: ", best_distance)
    return best_move

func calculate_attack_position(attacker: Unit, target_pos: Vector2i) -> Vector2i:
    var target_unit = get_unit_at(target_pos)
    if not target_unit:
        return attacker.grid_position
        
    var possible_positions = []
    var directions = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
    
    for dir in directions:
        var pos = target_pos + dir
        if is_valid_position(pos) and pos in movement_range._current_range:
            possible_positions.append(pos)
    
    var best_pos = attacker.grid_position
    var best_distance = 999
    
    for pos in possible_positions:
        var distance = calculate_grid_distance(attacker.grid_position, pos)
        if distance < best_distance:
            best_distance = distance
            best_pos = pos
    return best_pos

#==================================================
# グリッド・ユニット管理系
#==================================================
func is_valid_position(pos: Vector2i) -> bool:
    return pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y

func get_cell_data(pos: Vector2i) -> CellData:
    return grid_data.get(pos)

func world_to_grid(world_pos: Vector3) -> Vector2i:
    return Vector2i(int(world_pos.x / cell_size), int(world_pos.z / cell_size))

func grid_to_world(grid_pos: Vector2i) -> Vector3:
    return Vector3(grid_pos.x * cell_size, 0, grid_pos.y * cell_size)

func place_unit(unit: Unit, pos: Vector2i) -> bool:
    if not is_valid_position(pos) or has_unit_at(pos):
        return false
    _remove_unit_from_old_pos_if_needed(unit)
    units[pos] = unit
    unit.grid_position = pos
    unit.position = grid_to_world(pos)
    return true

func _remove_unit_from_old_pos_if_needed(unit: Unit):
    if units.has(unit):
        var old_pos = units.find_key(unit)
        units.erase(old_pos)

func get_unit_at(pos: Vector2i) -> Unit:
    return units.get(pos)

func has_unit_at(pos: Vector2i) -> bool:
    return units.has(pos)

func move_unit(unit: Unit, new_pos: Vector2i) -> bool:
    if not is_valid_position(new_pos) or has_unit_at(new_pos):
        return false
    
    var old_pos = unit.grid_position
    units.erase(old_pos)
    
    await unit.move_to_grid(new_pos)
    
    if place_unit(unit, new_pos):
        unit.unit_moved.emit(old_pos, new_pos)
        return true
    return false

#==================================================
# セル選択・行動処理
#==================================================
func _select_cell(grid_pos: Vector2i):
    if not is_valid_position(grid_pos) or not turn_manager.is_player_turn():
        battle_ui.hide_unit_info()
        return

    var target_unit = get_unit_at(grid_pos)
    _update_ui_for_target_unit(target_unit)

    if selected_unit:
        if await _attempt_attack_if_possible(target_unit, grid_pos):
            return
        if _attempt_move_if_in_range(grid_pos):
            return

    if target_unit and target_unit.team == Team.PLAYER and not target_unit.has_acted:
        _select_new_unit(target_unit)

    selected_cell_indicator.visible = true
    selected_cell_indicator.position = grid_to_world(grid_pos)
    cell_selected.emit(grid_pos)

func _update_ui_for_target_unit(target_unit: Unit):
    if target_unit:
        battle_ui.show_unit_info(target_unit)
    else:
        battle_ui.hide_unit_info()

func _attempt_attack_if_possible(target_unit: Unit, grid_pos: Vector2i) -> bool:
    if selected_unit and target_unit and target_unit.team != selected_unit.team and attack_range.is_in_attack_range(grid_pos):
        # 近接攻撃用に移動
        if grid_pos in movement_range._current_range:
            var attack_pos = calculate_attack_position(selected_unit, grid_pos)
            if attack_pos != selected_unit.grid_position:
                await execute_movement(selected_unit, attack_pos)
        
        if selected_action == ActionType.ATTACK:
            _execute_attack(target_unit)
            return true
    return false

func _execute_attack(target_unit: Unit):
    is_in_action = false
    selected_unit.perform_attack(target_unit)
    selected_unit.has_attacked = true
    _clear_ranges()
    selected_unit.end_action()
    selected_unit = null
    battle_ui.hide_unit_info()
    waiting_for_turn_end = true
    battle_ui.show_turn_end_button()
    battle_ui.hide_action_buttons()

func _attempt_move_if_in_range(grid_pos: Vector2i) -> bool:
    if selected_unit and movement_range.is_cell_in_range(grid_pos):
        is_in_action = true
        save_state()
        execute_movement(selected_unit, grid_pos)
        return true
    return false

func _select_new_unit(target_unit: Unit):
    selected_unit = target_unit
    is_in_action = false
    if not target_unit.has_moved:
        var movement_cells = movement_range.calculate_movement_range(target_unit)
        movement_range.show_movement_range(target_unit)
        attack_range.show_attack_range(target_unit, movement_cells)
    elif not target_unit.has_attacked:
        attack_range.show_attack_range(target_unit)

#==================================================
# 状態保存・復元系
#==================================================
func save_state():
    previous_state = {
        "selected_unit": selected_unit,
        "selected_unit_position": selected_unit.grid_position if selected_unit else null,
        "has_moved": selected_unit.has_moved if selected_unit else false,
        "has_attacked": selected_unit.has_attacked if selected_unit else false,
        "has_acted": selected_unit.has_acted if selected_unit else false,
        "waiting_for_direction": waiting_for_direction,
        "waiting_for_turn_end": waiting_for_turn_end,
        "selected_action": selected_action,
        "action_buttons_visible": battle_ui.are_action_buttons_visible()
    }

func restore_state():
    if previous_state.is_empty():
        return

    if previous_state.selected_unit:
        _restore_selected_unit_state()
    
    waiting_for_direction = previous_state.waiting_for_direction
    waiting_for_turn_end = previous_state.waiting_for_turn_end
    selected_action = previous_state.selected_action

    if previous_state.action_buttons_visible:
        battle_ui.show_action_buttons()
    else:
        battle_ui.hide_action_buttons()

    previous_state.clear()

    _re_show_ranges_based_on_state()

func _restore_selected_unit_state():
    selected_unit = previous_state.selected_unit
    selected_unit.has_moved = previous_state.has_moved
    selected_unit.has_attacked = previous_state.has_attacked
    selected_unit.has_acted = previous_state.has_acted
    
    if previous_state.selected_unit_position:
        units.erase(selected_unit.grid_position)
        selected_unit.position = grid_to_world(previous_state.selected_unit_position)
        selected_unit.grid_position = previous_state.selected_unit_position
        units[selected_unit.grid_position] = selected_unit

func _re_show_ranges_based_on_state():
    if selected_unit and not selected_unit.has_moved:
        var movement_cells = movement_range.calculate_movement_range(selected_unit)
        movement_range.show_movement_range(selected_unit)
        attack_range.show_attack_range(selected_unit, movement_cells)
    elif selected_unit and selected_unit.has_moved and not selected_unit.has_attacked:
        attack_range.show_attack_range(selected_unit)

#==================================================
# キャンセル系
#==================================================
func cancel_movement():
    if selected_unit and selected_unit_previous_position != Vector2i(-1, -1):
        units.erase(selected_unit.grid_position)
        selected_unit.position = grid_to_world(selected_unit_previous_position)
        selected_unit.grid_position = selected_unit_previous_position
        units[selected_unit.grid_position] = selected_unit
        
        selected_unit.has_moved = has_moved_previous_state
        selected_unit.has_attacked = has_attacked_previous_state
        selected_unit.has_acted = has_acted_previous_state
        
        selected_unit_previous_position = Vector2i(-1, -1)
        _clear_ranges()
        _re_show_ranges_after_cancel()

        battle_ui.hide_action_buttons()
        battle_ui.hide_unit_info()

func _re_show_ranges_after_cancel():
    if selected_unit and not selected_unit.has_moved:
        var movement_cells = movement_range.calculate_movement_range(selected_unit)
        movement_range.show_movement_range(selected_unit)
        attack_range.show_attack_range(selected_unit, movement_cells)
    elif selected_unit and selected_unit.has_moved and not selected_unit.has_attacked:
        attack_range.show_attack_range(selected_unit)

func cancel_attack():
    attack_range.clear_range_display()
    battle_ui.show_action_buttons()

func remove_unit(unit: Unit):
    if unit.team in active_units:
        active_units[unit.team].erase(unit)
    if check_game_end():
        print("Game has ended!")

func check_game_end() -> bool:
    if active_units[Team.PLAYER].is_empty():
        return true
    if active_units[Team.ENEMY].is_empty():
        return true
    return false

func register_unit(unit: Unit):
    if unit.team in active_units:
        active_units[unit.team].append(unit)

func start_game():
    print("================")
    print("Turn 1 - Player's turn START")
    print("Active units for current team: ", active_units[current_team].size())
    _start_turn()

func _start_turn():
    for unit in active_units[current_team]:
        unit.reset_actions()
    turn_changed.emit(current_team)

func end_turn():
    print("Current turn ending check...")
    for unit in active_units[current_team]:
        if not unit.has_acted:
            print("Turn cannot end - ", active_units[current_team].size(), " units haven't acted yet")
            return

    print(get_team_name(current_team), "'s turn END")
    print("================")
    current_team = Team.ENEMY if current_team == Team.PLAYER else Team.PLAYER
    print("================")
    print("Turn 1 - ", get_team_name(current_team), "'s turn START")
    print("Active units for current team: ", active_units[current_team].size())
    _start_turn()

func get_team_name(team: int) -> String:
    return "Player" if team == Team.PLAYER else "Enemy"

func is_player_turn() -> bool:
    return current_team == Team.PLAYER

func get_remaining_enemies() -> int:
    return active_units[Team.ENEMY].size()

func end_game(is_player_victory: bool):
    print("Game Over - " + ("Player Wins!" if is_player_victory else "Enemy Wins!"))
    if battle_ui:
        battle_ui.show_game_end_message(is_player_victory)
    turn_manager.end_game()
