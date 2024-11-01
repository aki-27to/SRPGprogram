# grid_input_handler.gd
extends Node
class_name GridInputHandler

signal cell_clicked(position: Vector2i)
signal cell_hovered(position: Vector2i)

var _grid_manager: GridManager

func _init(manager: GridManager):
	_grid_manager = manager

func _input(event):
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _handle_mouse_button(event: InputEventMouseButton):
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var grid_pos = _get_grid_position_from_mouse(event.position)
		if grid_pos:
			cell_clicked.emit(grid_pos)

func _handle_mouse_motion(event: InputEventMouseMotion):
	var grid_pos = _get_grid_position_from_mouse(event.position)
	if grid_pos:
		cell_hovered.emit(grid_pos)

func _get_grid_position_from_mouse(mouse_pos: Vector2) -> Vector2i:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return Vector2i(-1, -1)
		
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	
	var space_state = _grid_manager.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		return _grid_manager.world_to_grid(result.position)
	return Vector2i(-1, -1)
