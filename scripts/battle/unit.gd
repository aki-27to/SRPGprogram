# scripts/battle/unit.gd
extends Node3D
class_name Unit

# 基本パラメータ
@export var unit_name: String = "Unit":
	set(value):
		unit_name = value
		_update_ui()

@export var team: int = 0  # 0: プレイヤー, 1: 敵
@export var max_hp: int = 10:
	set(value):
		max_hp = value
		current_hp = value
		_update_ui()
@export var current_hp: int = 10
@export var attack: int = 3
@export var defense: int = 2
@export var move_range: int = 3
@export var attack_range: int = 1

# モデルとアニメーション関連
var model_root: Node3D
var skeleton: Skeleton3D
var animation_player: AnimationPlayer

# アニメーション名の定数
const ANIM_IDLE = "Idle"
const ANIM_WALK = "Walk"
const ANIM_ATTACK = "Attack"
const ANIM_DEATH = "Death"

# 位置管理
var grid_position: Vector2i
var is_selected: bool = false
var has_acted: bool = false
var has_moved: bool = false
var has_attacked: bool = false


signal unit_selected(unit: Unit)
signal unit_moved(from: Vector2i, to: Vector2i)
signal unit_attacked(target: Unit, damage: int)
signal hp_changed(new_hp: int, max_hp: int)
signal unit_defeated



func _ready():
	# ベースモデルの読み込みと設定
	_setup_model()
	current_hp = max_hp

func _setup_model():
	var base_scene = load("res://assets/3dmodels/Crouch Idle.fbx")
	if base_scene:
		model_root = base_scene.instantiate()
		add_child(model_root)
		
		# ノード構造を詳細に出力
		print("\n=== Model Node Structure ===")
		_print_node_tree(model_root)
		print("===========================\n")        
		
		animation_player = model_root.get_node("AnimationPlayer")
		if animation_player:
			print("Found animations: ", animation_player.get_animation_list())
			# 明示的にmixamo_comアニメーションを再生
			if animation_player.has_animation("mixamo_com"):
				animation_player.play("mixamo_com")
				print("Playing mixamo_com animation")
			else:
				print("mixamo_com animation not found!")
		
		skeleton = model_root.get_node("RootNode/Skeleton3D")
		
		_setup_model_transform()
		_load_additional_animations()
		_apply_team_color()
		
func _print_node_tree(node: Node, indent: String = ""):
	print(indent + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_print_node_tree(child, indent + "  ")
		
func _setup_model_transform():
	if model_root:
		model_root.rotation_degrees.y = 180
		model_root.scale = Vector3.ONE * 0.5
		model_root.position.y = 0.3

func _load_additional_animations():
	if not animation_player:
		return
		
	print("\n=== Loading Animations ===")
	print("Current animations:", animation_player.get_animation_list())
	
	var walk_anim = load("res://assets/3dmodels/Unarmed Walk Forward.fbx")
	var attack_anim = load("res://assets/3dmodels/Sword And Shield Attack.fbx")
	var death_anim = load("res://assets/3dmodels/Death From Right.fbx")  # 追加
	
	print("Loading Walk animation from:", walk_anim)
	print("Loading Attack animation from:", attack_anim)
	print("Loading Death animation from:", death_anim)  # 追加
	
	if walk_anim:
		_add_animation_from_scene(walk_anim, ANIM_WALK)
	if attack_anim:
		_add_animation_from_scene(attack_anim, ANIM_ATTACK)
	if death_anim:  # 追加
		_add_animation_from_scene(death_anim, ANIM_DEATH)
	
	print("Final animations:", animation_player.get_animation_list())
	print("=======================\n")

func _add_animation_from_scene(scene: PackedScene, anim_name: String):
	var instance = scene.instantiate()
	if instance.has_node("AnimationPlayer"):
		var source_player = instance.get_node("AnimationPlayer")
		var source_anim = source_player.get_animation("mixamo_com")  # mixamo_comアニメーションを使用
		if source_anim:
			var new_lib = AnimationLibrary.new()
			new_lib.add_animation("mixamo_com", source_anim)
			animation_player.add_animation_library(anim_name, new_lib)
			print("Added animation: ", anim_name)
		else:
			print("Source animation 'mixamo_com' not found")
	else:
		print("AnimationPlayer not found in source scene")
	instance.queue_free()

func _apply_team_color():
	if not model_root:
		return
		
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.BLUE if team == 0 else Color.RED
	
	# 正しいパスでメッシュを取得
	if model_root.has_node("RootNode/Skeleton3D/Alpha_Surface"):
		var mesh = model_root.get_node("RootNode/Skeleton3D/Alpha_Surface")
		mesh.material_override = material
		
# アニメーション再生
func play_animation(anim_name: String, should_loop: bool = true):
	if not animation_player:
		print("No AnimationPlayer found")
		return
		
	print("\n=== Animation Debug ===")
	print("Attempting to play: ", anim_name)
	print("Available animations: ", animation_player.get_animation_list())
	print("Current animation: ", animation_player.current_animation)
	print("=====================\n")
	
	if anim_name == ANIM_IDLE:
		# デフォルトのアイドルアニメーション
		if animation_player.has_animation("mixamo_com"):
			print("Playing mixamo_com animation")
			if should_loop:
				animation_player.play("mixamo_com")
			else:
				animation_player.play("mixamo_com")
				await animation_player.animation_finished
				play_animation(ANIM_IDLE)
		else:
			print("mixamo_com animation not found!")
	else:
		# 追加したアニメーション
		if animation_player.has_animation_library(anim_name):
			print("Playing ", anim_name, "/mixamo_com animation")
			if should_loop:
				animation_player.play(anim_name + "/mixamo_com")
			else:
				animation_player.play(anim_name + "/mixamo_com")
				await animation_player.animation_finished
				play_animation(ANIM_IDLE)
		else:
			print("Animation library ", anim_name, " not found!")
			
# 移動アニメーション
func move_to(new_grid_pos: Vector2i) -> bool:
	print("Moving unit from ", grid_position, " to ", new_grid_pos)
	
	# 移動経路を計算
	var path = calculate_path(grid_position, new_grid_pos)
	if path.is_empty():
		return false
	
	# 各マスごとの移動を実行
	for next_pos in path:
		# 歩行アニメーション開始
		play_animation(ANIM_WALK, false)
		
		# キャラクターの向きを移動方向に調整
		var dir = next_pos - grid_position
		model_root.rotation.y = atan2(dir.x, dir.y)
		
		# マス目の中心位置を計算
		var target_world_pos = get_parent().grid_to_world(next_pos)
		
		# tweenで滑らかに移動
		var tween = create_tween()
		tween.tween_property(self, "position", target_world_pos, 0.3)
		await tween.finished
		
		# グリッド位置を更新
		grid_position = next_pos
	
	# アイドルアニメーションに戻る
	play_animation(ANIM_IDLE)
	return true

# グリッド座標ベースの移動
func move_to_grid(target_grid_pos: Vector2i) -> bool:
	# パス計算（現在位置から目標位置まで）
	var path = calculate_path(grid_position, target_grid_pos)
	
	# 各グリッドを順番に移動
	for next_pos in path:
		# 次の位置のワールド座標を計算
		var world_pos = get_parent().grid_to_world(next_pos)
		
		# 歩行アニメーション開始
		play_animation(ANIM_WALK, false)
		
		# 移動方向を計算して回転
		var direction = next_pos - grid_position
		model_root.rotation.y = atan2(direction.x, direction.y)
		
		# 実際の移動（tweenで補間）
		var tween = create_tween()
		tween.tween_property(self, "position", world_pos, 0.3)
		await tween.finished
		
		# グリッド位置を更新
		grid_position = next_pos
	
	play_animation(ANIM_IDLE)
	return true	
# 2点間の移動経路を計算
func calculate_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current = from
	
	while current != to:
		var diff = to - current
		var step = Vector2i()
		
		# X方向の移動を優先
		if diff.x != 0:
			step.x = sign(diff.x)
		else:
			step.y = sign(diff.y)
		
		current += step
		path.append(current)
	
	return path

# 選択状態の視覚的フィードバック
func set_selected(selected: bool):
	is_selected = selected
	if is_selected:
		# 選択時のエフェクト（例：スケール変更）
		scale = Vector3(1.2, 1.2, 1.2)
	else:
		scale = Vector3.ONE


# 攻撃アニメーション
func perform_attack(target: Unit) -> bool:
	if has_attacked or has_acted:
		return false
	# 攻撃対象への方向ベクトルを計算
	var direction = target.grid_position - grid_position
	# Z軸を基準とした角度計算（Z軸が前方向）
	var target_angle = atan2(direction.x, direction.y)
	# モデルの向きを調整（モデルは+Z方向が前）
	model_root.rotation.y = target_angle
	# 攻撃アニメーションの再生と完了待ち
	await play_animation(ANIM_ATTACK, false)
	var damage = calculate_damage(target)
	target.take_damage(damage)
	has_attacked = true
	if not has_moved:
		has_acted = true
	
	unit_attacked.emit(target, damage)
	
	# アイドルアニメーションに戻る
	play_animation(ANIM_IDLE)
	return true
	
	
# ダメージ計算
func calculate_damage(target: Unit) -> int:
	var base_damage = attack
	var final_damage = max(1, base_damage - target.defense)  # 最小1ダメージ
	return final_damage

# ダメージを受ける
func take_damage(amount: int):
	var old_hp = current_hp
	current_hp = max(0, current_hp - amount)
	print("Unit HP changed: %d -> %d" % [old_hp, current_hp])
	hp_changed.emit(current_hp, max_hp)
	
	if current_hp <= 0:
		print("Unit defeated!")
		await play_death_animation()  
		remove_from_battle()
		
func play_death_animation():
	print("Playing death animation")
	if animation_player and animation_player.has_animation_library(ANIM_DEATH):
		animation_player.play(ANIM_DEATH + "/mixamo_com")
		await animation_player.animation_finished
	else:
		# フォールバック処理（アニメーションが読み込めない場合）
		print("Death animation not found, using fallback")
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 1.0)
		await tween.finished
		
func remove_from_battle():
	print("Removing unit from battle")
	var grid_manager = get_parent()
	if grid_manager:
		# Enemyをフィールドから削除する
		grid_manager.remove_unit(self)
		unit_defeated.emit()

		# EnemyのHPが0になった場合の処理
		if team == 1:  # Enemy team
			# 残りの敵ユニット数をチェック
			var remaining_enemies = grid_manager.get_remaining_enemies()
			if remaining_enemies == 0:
				# 全Enemyがフィールドから削除された場合
				print("All enemies defeated!")
				grid_manager.end_game(true)  # true = プレイヤーの勝利
			else:
				# それ以外の場合はそのまま続行
				print("Enemy defeated, remaining enemies: ", remaining_enemies)
				
func reset_actions():
	has_acted = false
	has_moved = false
	has_attacked = false

func end_action():
	has_acted = true

func _update_ui():
	# UI更新のシグナルを発行
	hp_changed.emit(current_hp, max_hp)
