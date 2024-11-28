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
# ユニット管理用の変数を追加
var units: Dictionary = {}  # キー: Vector2i（位置）, 値: Unit
var selected_unit: Unit = null
var waiting_for_turn_end: bool = false


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
	# ユニット位置のデバッグ出力
	print("\n=== Initial Unit Positions ===")
	for pos in units.keys():
		var unit = units[pos]
		print("Unit at position: ", pos, " Team: ", unit.team)
	print("===========================\n")
	
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
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if waiting_for_turn_end:
			_finish_turn()
		elif selected_unit:
			print("Action finished by space key")
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

func _finish_turn():
	print("Finishing turn")
	waiting_for_turn_end = false
	battle_ui.hide_turn_end_button()
	turn_manager.end_turn()

# 行動終了処理を追加
func _finish_current_action():
	if selected_unit:
		print("Finishing current action")
		selected_unit.end_action()
		selected_unit = null
		movement_range.clear_range_display()
		attack_range.clear_range_display()
		waiting_for_turn_end = true
		battle_ui.show_turn_end_button()

func execute_movement(unit: Unit, target_pos: Vector2i):
	if await move_unit(unit, target_pos):
		unit.has_moved = true
		movement_range.clear_range_display()
		battle_ui.show_unit_info(unit)
		if not unit.has_attacked:
			attack_range.show_attack_range(unit)
		else:
			unit.end_action()
			selected_unit = null
			battle_ui.hide_unit_info()
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
func execute_enemy_turn():
	print("Execute enemy turn started")
	print("Enemy units: ", turn_manager.active_units[TurnManager.Team.ENEMY].size())
	
	for unit in turn_manager.active_units[TurnManager.Team.ENEMY]:
		if not unit.has_acted:
			print("Enemy unit acting")
			var target_pos = find_closest_player_unit_position(unit)
			
			if target_pos != Vector2i(-1, -1):
				print("Target position found: ", target_pos)
				
				# まず現在位置で攻撃可能か確認
				var attack_cells = attack_range.calculate_attack_range(unit)
				var can_attack = false
				var target_unit = null
				
				# 攻撃可能な対象を探す
				for attack_pos in attack_cells:
					target_unit = get_unit_at(attack_pos)
					if target_unit and target_unit.team == TurnManager.Team.PLAYER:
						can_attack = true
						print("Found attackable target at current position")
						break
				
				if can_attack and target_unit:
					# 現在位置から攻撃
					print("Enemy attacking from current position")
					unit.perform_attack(target_unit)
				else:
					# 移動して攻撃を試みる
					var move_pos = calculate_movement_toward_target(unit, target_pos)
					# awaitキーワードを追加
					if await move_unit(unit, move_pos):
						print("Enemy moved to: ", move_pos)
						
						# 移動後の攻撃範囲で再確認
						attack_cells = attack_range.calculate_attack_range(unit)
						for attack_pos in attack_cells:
							target_unit = get_unit_at(attack_pos)
							if target_unit and target_unit.team == TurnManager.Team.PLAYER:
								print("Found attackable target after movement")
								unit.perform_attack(target_unit)
								break
			
			# 行動終了
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
	print("Possible moves from movement range: ", possible_moves)
	
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
	print("=== Unit Placement Debug ===")
	print("Attempting to place unit at position: ", pos)
	
	if not is_valid_position(pos):
		print("Position invalid for placement")
		return false
		
	if has_unit_at(pos):
		print("Position already occupied")
		return false
	
	if units.has(unit):
		var old_pos = units.find_key(unit)
		print("Unit was previously at position: ", old_pos)
		units.erase(old_pos)
	
	units[pos] = unit
	unit.grid_position = pos
	unit.position = grid_to_world(pos)
	print("Unit successfully placed at: ", pos)
	print("Current grid position: ", unit.grid_position)
	print("Current world position: ", unit.position)
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
	units.erase(old_pos)
	
	# 新しい移動関数を使用
	await unit.move_to_grid(new_pos)
	
	if place_unit(unit, new_pos):
		unit.unit_moved.emit(old_pos, new_pos)
		return true
	
	return false
	
# ユニット選択処理を更新
# grid_manager.gd の _select_cell 関数を修正
func _select_cell(grid_pos: Vector2i):
	print("Selecting cell: ", grid_pos)
	
	if not is_valid_position(grid_pos):
		battle_ui.hide_unit_info()
		return
		
	if not turn_manager.is_player_turn():
		return

	var target_unit = get_unit_at(grid_pos)
	
	# UI更新
	if target_unit:
		battle_ui.show_unit_info(target_unit)
	else:
		battle_ui.hide_unit_info()
	
	# 選択中のユニットがある場合の処理
	if selected_unit:
		print("Selected unit exists: ", selected_unit)
		
		# 攻撃可能な敵ユニット
		if target_unit and target_unit.team != selected_unit.team and attack_range.is_in_attack_range(grid_pos):
			# 近接攻撃の場合、まず移動
			if grid_pos in movement_range._current_range:
				# 最適な攻撃位置を計算
				var attack_pos = calculate_attack_position(selected_unit, grid_pos)
				if attack_pos != selected_unit.grid_position:
					# 移動してから攻撃
					await execute_movement(selected_unit, attack_pos)
			
			# 攻撃実行
			selected_unit.perform_attack(target_unit)
			selected_unit.has_attacked = true
			attack_range.clear_range_display()
			selected_unit.end_action()
			selected_unit = null
			battle_ui.hide_unit_info()
			waiting_for_turn_end = true
			battle_ui.show_turn_end_button()
			return
			
		# 移動可能なセル
		if movement_range.is_cell_in_range(grid_pos):
			print("Moving to cell")
			execute_movement(selected_unit, grid_pos)
			return
	
	# 新しいユニットの選択処理を追加
	if target_unit and target_unit.team == 0 and not target_unit.has_acted:
		print("Selected new unit")
		selected_unit = target_unit
		if not target_unit.has_moved:
			var movement_cells = movement_range.calculate_movement_range(target_unit)
			print("Calculated movement range: ", movement_cells)
			movement_range.show_movement_range(target_unit)
			attack_range.show_attack_range(target_unit, movement_cells)
		elif not target_unit.has_attacked:
			attack_range.show_attack_range(target_unit)
	
	selected_cell_indicator.visible = true
	selected_cell_indicator.position = grid_to_world(grid_pos)
	cell_selected.emit(grid_pos)
# grid_manager.gd に追加
func calculate_attack_position(attacker: Unit, target_pos: Vector2i) -> Vector2i:
	var target_unit = get_unit_at(target_pos)
	if not target_unit:
		return attacker.grid_position
		
	# 攻撃対象の周囲のセルをチェック
	var possible_positions = []
	var directions = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	
	for dir in directions:
		var pos = target_pos + dir
		if is_valid_position(pos) and pos in movement_range._current_range:
			possible_positions.append(pos)
	
	# 最も近い位置を選択
	var best_pos = attacker.grid_position
	var best_distance = 999
	
	for pos in possible_positions:
		var distance = calculate_grid_distance(attacker.grid_position, pos)
		if distance < best_distance:
			best_distance = distance
			best_pos = pos
			
	return best_pos

func remove_unit(unit: Unit):
	print("TurnManager: Removing unit from active units")
	# ユニットをチーム配列から削除
	if unit.team in active_units:
		active_units[unit.team].erase(unit)
		print("Unit removed from team ", unit.team)
	
	# ゲーム終了判定
	if check_game_end():
		print("Game has ended!")
		
func check_game_end() -> bool:
	# プレイヤーチームのユニットがいなくなった場合
	if active_units[Team.PLAYER].is_empty():
		print("Game Over - Enemy Wins!")
		return true
	
	# 敵チームのユニットがいなくなった場合
	if active_units[Team.ENEMY].is_empty():
		print("Game Over - Player Wins!")
		return true
	
	return false

func register_unit(unit: Unit):
	print("Registering unit for team: ", unit.team)
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
	# アクティブユニットの行動確認
	for unit in active_units[current_team]:
		if not unit.has_acted:
			print("Turn cannot end - ", active_units[current_team].size(), " units haven't acted yet")
			return

	print(get_team_name(current_team), "'s turn END")
	print("================")
	
	# チーム切り替え
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
	# UI更新
	if battle_ui:
		battle_ui.show_game_end_message(is_player_victory)
	
	# ゲーム状態を終了状態に
	turn_manager.end_game()
