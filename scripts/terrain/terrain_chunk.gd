class_name TerrainChunk
extends StaticBody2D

const GROUND_DEPTH := 450.0

@onready var _visual: Polygon2D = $TerrainVisual
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

var ground_color: Color = Color(0.35, 0.55, 0.22)
## IDs de superficie por segmento (paralelo a surface_points, tamaño = surface_points.size() - 1)
var surface_ids: PackedStringArray = []
## Puntos de superficie guardados para lookup
var _surface_points: PackedVector2Array = []


func setup(surface_points: PackedVector2Array, surface_ids: PackedStringArray = []) -> void:
	if surface_points.size() < 2:
		return

	_visual.color = ground_color
	
	# Guardar puntos de superficie para lookup de IDs
	_surface_points = surface_points

	# Construir polígono visual y colisión
	var polygon := PackedVector2Array()
	polygon.append_array(surface_points)
	
	var last_point := surface_points[surface_points.size() - 1]
	var first_point := surface_points[0]
	polygon.append(Vector2(last_point.x, last_point.y + GROUND_DEPTH))
	polygon.append(Vector2(first_point.x, first_point.y + GROUND_DEPTH))
	
	_visual.polygon = polygon
	
	# Obtener el CollisionPolygon2D hijo de este CollisionShape2D
	var collision_poly: CollisionPolygon2D = $CollisionPolygon2D
	
	collision_poly.polygon = polygon
	
	# Guardar surface_ids (uno por segmento entre puntos)
	self.surface_ids = surface_ids

func get_surface_id_at_local_x(local_x: float) -> String:
	"""Devuelve el surface_id del segmento que contiene local_x."""
	if surface_ids.is_empty() or _surface_points.is_empty():
		return "dirt"

	# Buscar segmento que contiene local_x
	for i in range(_surface_points.size() - 1):
		var x1 := _surface_points[i].x
		var x2 := _surface_points[i + 1].x
		if local_x >= x1 and local_x <= x2:
			if i < surface_ids.size():
				return surface_ids[i]
			break

	# Fallback: primer surface_id o dirt
	return surface_ids[0] if not surface_ids.is_empty() else "dirt"