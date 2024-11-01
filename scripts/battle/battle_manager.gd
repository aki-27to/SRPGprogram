# battle_manager.gd
extends Node
class_name BattleManager

signal battle_ended(is_victory: bool)

var grid_manager: GridManager
var turn_manager: TurnManager

func _ready():
	# ターン終了時に状態をチェック
	turn_manager.turn_ended.connect(_check_battle_state)

func _check_battle_state():
	# プレイヤーユニットの全滅チェック
	var player_units = turn_manager.active_units[TurnManager.Team.PLAYER]
	if player_units.is_empty():
		battle_ended.emit(false)  # 敗北
		return
		
	# 敵ユニットの全滅チェック
	var enemy_units = turn_manager.active_units[TurnManager.Team.ENEMY]
	if enemy_units.is_empty():
		battle_ended.emit(true)  # 勝利
		return
