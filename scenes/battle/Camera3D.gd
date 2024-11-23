extends Camera3D

@export var move_speed: float = 10.0
@export var rotation_speed: float = 0.5
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 20.0
@export var initial_position := Vector3(10, 15, 10)
@export var look_at_point := Vector3(5, 0, 5)  # グリッドの中心付近を見るように

var _target_position: Vector3
var _current_rotation: float = 0.0
var _dragging: bool = false
var _initial_mouse_pos: Vector2

func _ready():
	# 初期位置の設定
	position = initial_position
	_target_position = position
	# 初期の注視点設定
	look_at(look_at_point, Vector3.UP)

func _unhandled_input(event):
	# マウス右ドラッグによる回転
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			_initial_mouse_pos = event.position
			get_viewport().set_input_as_handled()
			
	# マウス移動による回転
	elif event is InputEventMouseMotion and _dragging:
		var delta = event.position - _initial_mouse_pos
		_current_rotation += delta.x * rotation_speed * 0.01
		var rotation_transform = Transform3D().rotated(Vector3.UP, _current_rotation)
		transform.basis = rotation_transform.basis
		_initial_mouse_pos = event.position
	
	# ズーム処理の改善
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var new_pos = position - transform.basis.z * zoom_speed
			if new_pos.y > min_zoom:
				position = new_pos
				_target_position = position
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var new_pos = position + transform.basis.z * zoom_speed
			if new_pos.y < max_zoom:
				position = new_pos
				_target_position = position

func _process(delta):
	var input_dir = Vector3.ZERO
	
	# WASD/矢印キーによる移動
	if Input.is_action_pressed("ui_right"):
		input_dir.x += 1
	if Input.is_action_pressed("ui_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_down"):
		input_dir.z += 1
	if Input.is_action_pressed("ui_up"):
		input_dir.z -= 1
	
	# 移動方向をカメラの向きに合わせて調整
	var cam_right = transform.basis.x
	var cam_forward = -transform.basis.z
	cam_forward.y = 0
	cam_forward = cam_forward.normalized()
	
	var movement = cam_right * input_dir.x + cam_forward * input_dir.z
	movement = movement.normalized() * move_speed * delta
	
	if movement.length() > 0:
		_target_position += movement
		position = _target_position
