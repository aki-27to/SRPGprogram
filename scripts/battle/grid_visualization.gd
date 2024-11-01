# grid_visualization.gd
extends Node3D
class_name GridVisualization

var _grid_manager: GridManager
var _cell_meshes: Dictionary = {}
var _highlight_indicator: MeshInstance3D
var _selection_indicator: MeshInstance3D

func _init(manager: GridManager):
	_grid_manager = manager
	_create_grid_mesh()
	_create_indicators()

func _create_grid_mesh():
	var mesh = _create_cell_mesh()
	var material = _create_cell_material()
	mesh.surface_set_material(0, material)
	
	for x in range(_grid_manager.grid_size.x):
		for y in range(_grid_manager.grid_size.y):
			var pos = Vector2i(x, y)
			var cell = MeshInstance3D.new()
			cell.mesh = mesh
			cell.position = _grid_manager.grid_to_world(pos)
			add_child(cell)
			_cell_meshes[pos] = cell

func _create_cell_mesh() -> BoxMesh:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(_grid_manager.cell_size * 0.9, 0.1, _grid_manager.cell_size * 0.9)
	return mesh

func _create_cell_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.8, 0.8, 1.0)
	return material

func _create_indicators():
	_highlight_indicator = _create_indicator(Color(1.0, 1.0, 0.0, 0.3))
	_selection_indicator = _create_indicator(Color(0.0, 1.0, 0.0, 0.5))
	add_child(_highlight_indicator)
	add_child(_selection_indicator)

func _create_indicator(color: Color) -> MeshInstance3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(_grid_manager.cell_size * 0.95, 0.2, _grid_manager.cell_size * 0.95)
	mesh.surface_set_material(0, material)
	
	var indicator = MeshInstance3D.new()
	indicator.mesh = mesh
	indicator.visible = false
	return indicator

func highlight_cell(pos: Vector2i):
	if _grid_manager.is_valid_position(pos):
		_highlight_indicator.visible = true
		_highlight_indicator.position = _grid_manager.grid_to_world(pos)

func select_cell(pos: Vector2i):
	if _grid_manager.is_valid_position(pos):
		_selection_indicator.visible = true
		_selection_indicator.position = _grid_manager.grid_to_world(pos)
