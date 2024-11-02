# battle_manager.gd
extends Node
class_name BattleManager

signal battle_ended(is_victory: bool)

@export var grid_manager: GridManager
@export var turn_manager: TurnManager

func _ready():
	if turn_manager:
		turn_manager.turn_ended.connect(_check_battle_state)

func _check_battle_state():
	print("Checking battle state...")  # デバッグ追加
	
	var player_units = turn_manager.active_units[TurnManager.Team.PLAYER]
	print("Player units: ", player_units.size())  # デバッグ追加
	if player_units.is_empty():
		print("Game Over - Defeat!")  # デバッグ追加
		battle_ended.emit(false)
		return
		
	var enemy_units = turn_manager.active_units[TurnManager.Team.ENEMY]
	print("Enemy units: ", enemy_units.size())  # デバッグ追加
	if enemy_units.is_empty():
		print("Game Over - Victory!")  # デバッグ追加
		battle_ended.emit(true)
		return
