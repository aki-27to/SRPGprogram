# scripts/battle/turn_manager.gd
extends Node
class_name TurnManager

signal turn_changed(team: int)
signal turn_started
signal turn_ended
signal game_ended(is_victory: bool)


enum Team { PLAYER = 0, ENEMY = 1 }
var current_team: int = Team.PLAYER
var turn_count: int = 1
var active_units: Dictionary = {
	Team.PLAYER: [],
	Team.ENEMY: []
}
		
func register_unit(unit: Unit):
	active_units[unit.team].append(unit)

func start_game():
	turn_count = 1
	current_team = Team.PLAYER
	start_turn()

func start_turn():
	print("================")
	print("Turn %d - %s's turn START" % [turn_count, "Player" if current_team == Team.PLAYER else "Enemy"])
	print("Active units for current team: ", active_units[current_team].size())
	
	# ターン開始時に全ユニットのアクション状態をリセット
	for unit in active_units[current_team]:
		unit.reset_actions()
	
	turn_started.emit()
	turn_changed.emit(current_team)  # ここでシグナルを発火

func end_turn():
	print("Current turn ending check...")
	var unfinished_units = []
	
	for unit in active_units[current_team]:
		if not unit.has_acted:
			unfinished_units.append(unit)
	
	if unfinished_units.size() > 0:
		print("Turn cannot end - %d units haven't acted yet" % unfinished_units.size())
		return
		
	print("%s's turn END" % ["Player" if current_team == Team.PLAYER else "Enemy"])
	print("================")
	
	turn_ended.emit()
	switch_team()

func switch_team():
	current_team = Team.ENEMY if current_team == Team.PLAYER else Team.PLAYER
	if current_team == Team.PLAYER:
		turn_count += 1
	start_turn()

func is_player_turn() -> bool:
	return current_team == Team.PLAYER

func check_game_end() -> bool:
	if active_units[Team.PLAYER].is_empty():
		print("Game Over - Player Defeated!")
		game_ended.emit(false)
		return true
	
	if active_units[Team.ENEMY].is_empty():
		print("Victory - All Enemies Defeated!")
		game_ended.emit(true)
		return true
	
	return false
	
# ゲーム終了時にターンを停止する処理を追加
func end_game():
	# ゲーム終了時の処理をここに追加
	print("Game has ended - no more turns will be processed")
