# grid_test.gd
extends Node3D

@onready var grid_manager: GridManager = $GridManager
@onready var camera: Camera3D = $Camera3D

func _ready():
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
	print("Setting up test units")  # デバッグ出力追加
	
	# プレイヤーユニット
	var player_unit = Unit.new()
	player_unit.team = 0
	grid_manager.add_child(player_unit)
	var placed = grid_manager.place_unit(player_unit, Vector2i(1, 1))
	grid_manager.turn_manager.register_unit(player_unit)
	print("Player unit placed: ", placed)  # デバッグ出力追加
	
	# 敵ユニット
	var enemy_unit = Unit.new()
	enemy_unit.team = 1
	grid_manager.add_child(enemy_unit)
	grid_manager.place_unit(enemy_unit, Vector2i(8, 8))
	grid_manager.turn_manager.register_unit(enemy_unit)

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("Mouse clicked!")
