# scripts/battle/battle_ui.gd
extends Control
class_name BattleUI

# 既存のノード参照
@onready var turn_label: Label = $TurnLabel
@onready var team_label: Label = $TeamLabel
@onready var unit_info_panel: Panel = $UnitInfoPanel
@onready var hp_bar: ProgressBar = $UnitInfoPanel/HPBar
@onready var hp_label: Label = $UnitInfoPanel/HPLabel

# 管理クラスの参照
var turn_manager: TurnManager

# シグナル
signal action_selected(action_type: String)

func _ready():
    # 既存の接続
    turn_manager.turn_started.connect(_update_turn_display)
    # ユニット情報パネルは初期状態で非表示
    unit_info_panel.hide()

func _update_turn_display():
    turn_label.text = "Turn: %d" % turn_manager.turn_count
    team_label.text = "Team: %s" % ("Player" if turn_manager.is_player_turn() else "Enemy")

# ユニット情報の表示を追加
func show_unit_info(unit: Unit):
    if unit:
        hp_bar.value = float(unit.current_hp) / unit.max_hp * 100
        hp_label.text = "%d / %d" % [unit.current_hp, unit.max_hp]
        unit_info_panel.show()
    else:
        unit_info_panel.hide()
func show_battle_end(is_victory: bool):
    var result_panel = $ResultPanel
    result_panel.show()
    
    var result_label = $ResultPanel/ResultLabel
    result_label.text = "Victory!" if is_victory else "Defeat..."
    
    var restart_button = $ResultPanel/RestartButton
    restart_button.pressed.connect(_on_restart_pressed)

func _on_restart_pressed():
    # シーンのリロード
    get_tree().reload_current_scene()
# 戦闘結果の表示（最小限の実装）
func show_battle_result(damage: int):
    # 一時的なダメージ表示
    var damage_label = Label.new()
    damage_label.text = str(damage)
    add_child(damage_label)
    # 2秒後に消去
    await get_tree().create_timer(2.0).timeout
    damage_label.queue_free()
