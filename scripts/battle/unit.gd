# scripts/battle/unit.gd
extends Node3D
class_name Unit

# 基本パラメータ
@export var unit_name: String = "Unit"
@export var team: int = 0  # 0: プレイヤー, 1: 敵
@export var max_hp: int = 10
@export var current_hp: int = 10
@export var attack: int = 3
@export var defense: int = 2
@export var move_range: int = 3
@export var attack_range: int = 1

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
	# 仮の3Dモデル表示（開発用）
	var mesh = CylinderMesh.new()
	mesh.height = 0.5  # 高さを少し低く
	mesh.top_radius = 0.4  # 半径を少し大きく
	mesh.bottom_radius = 0.4
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.3  # グリッドの上に浮かせる
	
	# チームによって色を変える
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.BLUE if team == 0 else Color.RED
	mesh_instance.material_override = material
	add_child(mesh_instance)
	
	current_hp = max_hp
# 選択状態の視覚的フィードバック
func set_selected(selected: bool):
	is_selected = selected
	if is_selected:
		# 選択時のエフェクト（例：スケール変更）
		scale = Vector3(1.2, 1.2, 1.2)
	else:
		scale = Vector3.ONE

# 攻撃処理
func perform_attack(target: Unit) -> bool:
	if has_attacked or has_acted:
		print("Attack failed - unit has already acted")  # デバッグ追加
		return false
	
	var damage = calculate_damage(target)
	print("Unit %s attacks %s for %d damage" % [
		"Player" if team == 0 else "Enemy",
		"Player" if target.team == 0 else "Enemy",
		damage
	])  # デバッグ追加
	
	target.take_damage(damage)
	has_attacked = true
	if not has_moved:
		has_acted = true
	
	unit_attacked.emit(target, damage)
	return true

# ダメージ計算
func calculate_damage(target: Unit) -> int:
	var base_damage = attack
	var final_damage = max(1, base_damage - target.defense)  # 最小1ダメージ
	return final_damage

# ダメージを受ける
func take_damage(amount: int):
	var old_hp = current_hp  # デバッグ用
	current_hp = max(0, current_hp - amount)
	print("Unit HP changed: %d -> %d" % [old_hp, current_hp])  # デバッグ追加
	hp_changed.emit(current_hp, max_hp)
	
	if current_hp <= 0:
		print("Unit defeated!")  # デバッグ追加
		remove_from_battle()
		
func remove_from_battle():
	print("Removing unit from battle")
	var grid_manager = get_parent()
	if grid_manager:
		grid_manager.remove_unit(self)
		unit_defeated.emit()
		# 勝敗判定の追加
		if grid_manager.turn_manager:
			# 勝敗判定を実行
			var game_ended = grid_manager.turn_manager.check_game_end()
			if game_ended:
				print("Game has ended!")
				
func reset_actions():
	has_acted = false
	has_moved = false
	has_attacked = false

func end_action():
	has_acted = true
