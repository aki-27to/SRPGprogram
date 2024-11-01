# grid_data_factory.gd
extends Object
class_name GridDataFactory

static func create_grid(size: Vector2i) -> Dictionary:
	var grid_data = {}
	for x in range(size.x):
		for y in range(size.y):
			grid_data[Vector2i(x, y)] = CellData.new()
	return grid_data
