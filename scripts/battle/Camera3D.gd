extends Camera3D

@export var rotation_speed: float = 0.005
@export var zoom_speed: float = 0.5
@export var min_zoom: float = 5.0
@export var max_zoom: float = 30.0

var _dragging: bool = false
var _initial_mouse_pos: Vector2
var _camera_rotation: Vector3

func _ready():
	_camera_rotation = rotation
	print("Initial camera rotation: ", rotation)

func _input(event):  # _unhandled_inputから_inputに変更
	if event is InputEventMouseButton:
		# 右クリックドラッグで回転
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			if _dragging:
				_initial_mouse_pos = event.position
				_camera_rotation = rotation
				print("\n=== Right Button Pressed ===")
				print("Dragging started: ", _dragging)
				print("Initial mouse position: ", _initial_mouse_pos)
				print("Initial camera rotation: ", _camera_rotation)
			else:
				print("\n=== Right Button Released ===")
				print("Dragging ended: ", _dragging)
		
		# マウスホイールでズーム
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			position -= transform.basis.z * zoom_speed
			print("Zoom in - New position: ", position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			position += transform.basis.z * zoom_speed
			print("Zoom out - New position: ", position)
			
	# マウス移動による回転
	elif event is InputEventMouseMotion:
		if _dragging:  # ドラッグ中のみ処理
			var delta = event.position - _initial_mouse_pos
			print("\n=== Mouse Motion While Dragging ===")
			print("Mouse delta: ", delta)
			print("Before rotation: ", rotation)
			
			# X軸とY軸の回転を更新
			rotation.x = _camera_rotation.x + delta.y * rotation_speed
			rotation.y = _camera_rotation.y - delta.x * rotation_speed
			
			# X軸の回転を制限（-90度から90度）
			rotation.x = clamp(rotation.x, -PI/2, PI/2)
			
			print("After rotation: ", rotation)
