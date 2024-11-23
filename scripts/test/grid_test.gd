# grid_test.gd
extends Node3D

@onready var grid_manager: GridManager = $GridManager
@onready var battle_ui: BattleUI = $BattleUI
@onready var camera: Camera3D = $Camera3D

func _ready():
	# BattleUIの参照をGridManagerに渡す
	grid_manager.battle_ui = battle_ui
	# カメラの位置設定
	camera.position = Vector3(10, 10, 10)
	camera.look_at(Vector3.ZERO)
	
	# ライトの追加と設定
	var light = DirectionalLight3D.new()
	light.position = Vector3(0, 10, 0)
	light.rotation_degrees = Vector3(-45, 45, 0)
	add_child(light)
	
	# テスト用ユニットの配置
	_setup_test_units()
	
	# ゲーム開始
	grid_manager.turn_manager.start_game()

# アンダースコアを追加して命名規則に準拠
func _setup_test_units():
	print("Setting up test units")

	# プレイヤーユニット
	var player_unit = Unit.new()
	player_unit.unit_name = "Player Knight"    # 固有の名前
	player_unit.max_hp = 15                    # HP設定
	player_unit.current_hp = 15
	player_unit.attack = 4                     # 攻撃力
	player_unit.defense = 2                    # 防御力
	player_unit.move_range = 3                 # 移動力
	player_unit.team = 0
	grid_manager.add_child(player_unit)
	var placed = grid_manager.place_unit(player_unit, Vector2i(1, 1))
	grid_manager.turn_manager.register_unit(player_unit)
	print("Player unit placed: ", placed)

	# 敵ユニット
	var enemy_unit = Unit.new()
	enemy_unit.unit_name = "Enemy Soldier"     # 固有の名前
	enemy_unit.max_hp = 12                     # HP設定
	enemy_unit.current_hp = 12
	enemy_unit.attack = 3                      # 攻撃力
	enemy_unit.defense = 1                     # 防御力
	enemy_unit.move_range = 3                  # 移動力
	enemy_unit.team = 1
	grid_manager.add_child(enemy_unit)
	grid_manager.place_unit(enemy_unit, Vector2i(8, 8))
	grid_manager.turn_manager.register_unit(enemy_unit)

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("Mouse clicked!")
