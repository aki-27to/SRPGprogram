# scripts/battle/battle_ui.gd
extends Control
class_name BattleUI

@onready var unit_info_panel: Panel = $UnitInfoPanel
@onready var unit_name_label: Label = $UnitInfoPanel/UnitNameLabel
@onready var hp_bar: ProgressBar = $UnitInfoPanel/HPBar
@onready var hp_label: Label = $UnitInfoPanel/HPLabel
@onready var turn_end_button: Button = $TurnEndButton
var game_end_label: Label  # 参照をやめて変数のみ宣言

func _ready():
	# 初期状態では非表示
	unit_info_panel.hide()

	# ゲーム終了メッセージラベルの作成
	game_end_label = Label.new()
	game_end_label.anchors_preset = Control.PRESET_CENTER
	game_end_label.position = Vector2(500, 300)  # 画面中央付近に配置
	game_end_label.visible = false
	game_end_label.add_theme_font_size_override("font_size", 32)
	add_child(game_end_label)
	turn_end_button.visible = false
	turn_end_button.pressed.connect(_on_turn_end_button_pressed)
	
# ユニット選択時の表示更新
func show_unit_info(unit: Unit):
	unit_name_label.text = unit.unit_name
	hp_bar.max_value = unit.max_hp
	hp_bar.value = unit.current_hp
	hp_label.text = str(unit.current_hp) + "/" + str(unit.max_hp)
	unit_info_panel.show()

# ターン終了ボタン表示
func show_turn_end_button():
	turn_end_button.visible = true

# ターン終了ボタン非表示
func hide_turn_end_button():
	turn_end_button.visible = false

# ターン終了ボタンが押されたときの処理
func _on_turn_end_button_pressed():
	var grid_manager = get_parent().get_node("GridManager")
	if grid_manager:
		grid_manager._finish_turn()

# UIをクリア
func hide_unit_info():
	unit_info_panel.hide()

# ゲーム終了メッセージを表示
func show_game_end_message(is_player_victory: bool):
	game_end_label.text = "Victory!" if is_player_victory else "Defeat..."
	game_end_label.visible = true

# ゲーム終了メッセージを非表示
func hide_game_end_message():
	game_end_label.visible = false

# アクションボタンを非表示にする関数を追加
func hide_action_buttons():
	$ActionButtons.hide()

# アクションボタンを表示する関数を追加
func show_action_buttons():
	$ActionButtons.show()

# アクションボタンのシグナルを接続する関数を追加
func connect_action_buttons(grid_manager: GridManager):
	$ActionButtons/AttackButton.pressed.connect(func(): grid_manager.select_action(GridManager.ActionType.ATTACK))
	$ActionButtons/MagicButton.pressed.connect(func(): grid_manager.select_action(GridManager.ActionType.MAGIC))
	$ActionButtons/WaitButton.pressed.connect(func(): grid_manager.select_action(GridManager.ActionType.WAIT))

# アクションボタンが表示されているかどうかを返す関数を追加
func are_action_buttons_visible() -> bool:
	return $ActionButtons.visible
