extends Node

@export var terrain_generator_path: NodePath
@export var interval: float = 0.5

var _terrain: TerrainGenerator
var _timer: Timer

func _ready() -> void:
	_terrain = get_node_or_null(terrain_generator_path) as TerrainGenerator
	if _terrain == null:
		printerr("TerrainDebug: TerrainGenerator no encontrado en ", terrain_generator_path)
		return
	
	_timer = Timer.new()
	_timer.wait_time = interval
	_timer.autostart = true
	_timer.one_shot = false
	add_child(_timer)
	_timer.timeout.connect(_dump_chunk_data)


func _dump_chunk_data() -> void:
	if _terrain == null:
		return
	
	var vehicle_x: float = 0.0
	var player = get_tree().get_nodes_in_group("player")
	if player.size() > 0:
		vehicle_x = (player[0] as Node2D).global_position.x
	
	print("=== Terrain Debug (vehicle x=%.1f) ===" % vehicle_x)
	print("Map: %s" % _terrain.get_active_map_id())
	
	var current_index: int = int(floor(vehicle_x / _terrain.chunk_width))
	
	for index in _terrain._chunks.keys():
		var chunk = _terrain._chunks[index] as TerrainChunk
		if chunk == null:
			continue
		
		var points = chunk._visual.polygon
		var surface_count: int = points.size()
		var is_current: bool = index == current_index
		
		print("Chunk %d%s (%d points):" % [index, " <- ACTUAL" if is_current else "", surface_count])
		
		# Imprimir todos los puntos de frontera + interiores
		for i in range(points.size()):
			var p = points[i]
			var dist_to_player := absf(p.x + chunk.position.x - vehicle_x)
			var marker := ""
			if i == 0 or i == points.size() - 3:
				marker = " [FRONTERA]"
			if dist_to_player < 50.0:
				marker += " <-- CERCA JUGADOR"
			
			# Solo mostrar fronteras e interiores cercanos
			if i == 0 or i == points.size() - 3 or dist_to_player < 60.0 or i < 3 or i > points.size() - 5:
				print("  [%d] x=%.1f y=%.1f%s" % [i, p.x + chunk.position.x, p.y, marker])
		
		# Verificar discontinuidad con chunk siguiente
		if is_current:
			var next_chunk = _terrain._chunks.get(index + 1) as TerrainChunk
			if next_chunk != null:
				var last_surf = points[points.size() - 3]
				var first_surf_next = next_chunk._visual.polygon[0]
				var delta_y := last_surf.y - first_surf_next.y
				print("  DISCONTINUIDAD con chunk %d: delta_y=%.1f" % [index + 1, delta_y])
		
	return