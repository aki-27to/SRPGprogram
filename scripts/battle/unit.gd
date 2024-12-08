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
var facing_direction: Vector2i = Vector2i.DOWN

func _ready():
	_setup_model()
	current_hp = max_hp

func _setup_model():
	var base_scene = load("res://assets/3dmodels/Crouch Idle.fbx")
	if base_scene:
		model_root = base_scene.instantiate()
		add_child(model_root)
		
		animation_player = model_root.get_node("AnimationPlayer")
		if animation_player and animation_player.has_animation("mixamo_com"):
			animation_player.play("mixamo_com")
		
		skeleton = model_root.get_node("RootNode/Skeleton3D")
		
		_setup_model_transform()
		_load_additional_animations()
		_apply_team_color()

func _setup_model_transform():
	if model_root:
		model_root.rotation_degrees.y = 180
		model_root.scale = Vector3.ONE * 0.5
		model_root.position.y = 0.3

func _load_additional_animations():
	if not animation_player:
		return
	
	var walk_anim = load("res://assets/3dmodels/Unarmed Walk Forward.fbx")
	var attack_anim = load("res://assets/3dmodels/Sword And Shield Attack.fbx")
	var death_anim = load("res://assets/3dmodels/Death From Right.fbx")
	
	if walk_anim:
		_add_animation_from_scene(walk_anim, ANIM_WALK)
	if attack_anim:
		_add_animation_from_scene(attack_anim, ANIM_ATTACK)
	if death_anim:
		_add_animation_from_scene(death_anim, ANIM_DEATH)

func _add_animation_from_scene(scene: PackedScene, anim_name: String):
	var instance = scene.instantiate()
	if instance.has_node("AnimationPlayer"):
		var source_player = instance.get_node("AnimationPlayer")
		var source_anim = source_player.get_animation("mixamo_com")
		if source_anim:
			var new_lib = AnimationLibrary.new()
			new_lib.add_animation("mixamo_com", source_anim)
			animation_player.add_animation_library(anim_name, new_lib)
	instance.queue_free()

func _apply_team_color():
	if not model_root:
		return
		
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.BLUE if team == 0 else Color.RED
	
	if model_root.has_node("RootNode/Skeleton3D/Alpha_Surface"):
		var mesh = model_root.get_node("RootNode/Skeleton3D/Alpha_Surface")
		mesh.material_override = material

# アニメーション再生
func play_animation(anim_name: String, should_loop: bool = true):
	if not animation_player:
		return
	
	if anim_name == ANIM_IDLE:
		if animation_player.has_animation("mixamo_com"):
			if should_loop:
				animation_player.play("mixamo_com")
			else:
				animation_player.play("mixamo_com")
				await animation_player.animation_finished
				play_animation(ANIM_IDLE)
	else:
		if animation_player.has_animation_library(anim_name):
			if should_loop:
				animation_player.play(anim_name + "/mixamo_com")
			else:
				animation_player.play(anim_name + "/mixamo_com")
				await animation_player.animation_finished
				play_animation(ANIM_IDLE)

# 移動アニメーション
func move_to(new_grid_pos: Vector2i) -> bool:
	var path = calculate_path(grid_position, new_grid_pos)
	if path.is_empty():
		return false
	
	for next_pos in path:
		play_animation(ANIM_WALK, false)
		
		var dir = next_pos - grid_position
		model_root.rotation.y = atan2(dir.x, dir.y)
		
		var target_world_pos = get_parent().grid_to_world(next_pos)
		
		var tween = create_tween()
		tween.tween_property(self, "position", target_world_pos, 0.3)
		await tween.finished
		
		grid_position = next_pos
	
	play_animation(ANIM_IDLE)
	return true

# グリッド座標ベースの移動
func move_to_grid(target_grid_pos: Vector2i) -> bool:
	var path = calculate_path(grid_position, target_grid_pos)
	
	for next_pos in path:
		var world_pos = get_parent().grid_to_world(next_pos)
		
		play_animation(ANIM_WALK, false)
		
		var direction = next_pos - grid_position
		model_root.rotation.y = atan2(direction.x, direction.y)
		
		var tween = create_tween()
		tween.tween_property(self, "position", world_pos, 0.3)
		await tween.finished
		
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
		scale = Vector3(1.2, 1.2, 1.2)
	else:
		scale = Vector3.ONE

# 攻撃アニメーション
func perform_attack(target: Unit) -> bool:
	if has_attacked or has_acted:
		return false

	var direction = target.grid_position - grid_position
	var target_angle = atan2(direction.x, direction.y)
	model_root.rotation.y = target_angle
	
	await play_animation(ANIM_ATTACK, false)
	var damage = calculate_damage(target)
	target.take_damage(damage)
	has_attacked = true
	if not has_moved:
		has_acted = true
	
	unit_attacked.emit(target, damage)
	
	play_animation(ANIM_IDLE)
	return true

# ダメージ計算
func calculate_damage(target: Unit) -> int:
	var base_damage = attack
	var final_damage = max(1, base_damage - target.defense)
	return final_damage

# ダメージを受ける
func take_damage(amount: int):
	current_hp = max(0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	
	if current_hp <= 0:
		await play_death_animation()
		remove_from_battle()

func play_death_animation():
	if animation_player and animation_player.has_animation_library(ANIM_DEATH):
		animation_player.play(ANIM_DEATH + "/mixamo_com")
		await animation_player.animation_finished
	else:
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 1.0)
		await tween.finished

func remove_from_battle():
	var grid_manager = get_parent()
	if grid_manager:
		grid_manager.remove_unit(self)
		unit_defeated.emit()

		if team == 1:
			var remaining_enemies = grid_manager.get_remaining_enemies()
			if remaining_enemies == 0:
				grid_manager.end_game(true)

func reset_actions():
	has_acted = false
	has_moved = false
	has_attacked = false

func end_action():
	has_acted = true

func _update_ui():
	hp_changed.emit(current_hp, max_hp)
	
# アクションボタンが表示されているかどうかを返す関数を追加
func are_action_buttons_visible() -> bool:
	return $ActionButtons.visible
	
# 向き変更用の関数を追加
func set_direction(new_direction: Vector2i):
	facing_direction = new_direction
	
	# モデルの向きも更新
	if facing_direction == Vector2i.UP:
		model_root.rotation.y = deg_to_rad(180)  # 上向き
	elif facing_direction == Vector2i.DOWN:
		model_root.rotation.y = deg_to_rad(0)  # 下向き
	elif facing_direction == Vector2i.LEFT:
		model_root.rotation.y = deg_to_rad(90)  # 左向き
	elif facing_direction == Vector2i.RIGHT:
		model_root.rotation.y = deg_to_rad(-90)  # 右向き
