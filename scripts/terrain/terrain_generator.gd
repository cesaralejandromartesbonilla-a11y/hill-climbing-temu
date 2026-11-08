class_name TerrainGenerator
extends Node2D

@export var chunk_width: float = 2000.0
@export var sample_step: float = 40.0
@export var base_height: float = 220.0
@export var flat_spawn_length: float = 350.0
@export var spawn_blend_length: float = 280.0
@export var chunks_ahead: int = 4
@export var chunks_behind: int = 2
@export var max_slope: float = 0.38
@export var max_slope_late: float = 0.52
@export var smooth_passes: int = 3
@export var difficulty_ramp_distance: float = 9000.0

## Configuración por mapa (sobrescribe valores base)
@export var map_configs: Dictionary = {
	"countryside": {
		"sample_step": 40.0,
		"smooth_passes": 3,
		"max_slope": 0.38,
		"max_slope_late": 0.52,
		"amplitude_mult_max": 2.0,
		"height_clamp_min": -100.0,
		"height_clamp_max": 100.0,
	},
	"arctic": {
		"sample_step": 35.0,
		"smooth_passes": 5,
		"max_slope": 0.30,
		"max_slope_late": 0.40,
		"amplitude_mult_max": 1.6,
		"height_clamp_min": -50.0,
		"height_clamp_max": 60.0,
	}
}

## Ruido para determinar tipo de superficie
@export var surface_noise_freq: float = 0.003
@export var surface_ice_threshold: float = 0.7
@export var surface_ice_min_width: int = 3  # segmentos mínimos連続 de hielo

var _noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _surface_noise: FastNoiseLite
var _chunks: Dictionary = {}
var _chunk_scene: PackedScene = preload("res://scenes/game/terrain_chunk.tscn")
var _ground_color: Color = Color(0.35, 0.55, 0.22)
var _active_map_id: String = "countryside"
var _active_surface: SurfaceProfile = null
var _surface_cache: Dictionary = {}  # cache de SurfaceProfile por id


func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = randi()
	_noise.frequency = 0.55
	_noise.fractal_octaves = 3
	_noise.fractal_lacunarity = 2.0
	_noise.fractal_gain = 0.45
	_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED  # Crestas naturales, menos picos

	_detail_noise = FastNoiseLite.new()
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.seed = _noise.seed + 97
	_detail_noise.frequency = 0.9
	_detail_noise.fractal_octaves = 2
	_detail_noise.fractal_gain = 0.5

	_surface_noise = FastNoiseLite.new()
	_surface_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_surface_noise.seed = _noise.seed + 193
	_surface_noise.frequency = surface_noise_freq
	_surface_noise.fractal_octaves = 1

	# Precargar superficies base
	_get_surface_profile("dirt")
	_get_surface_profile("ice")


func apply_map(map_def: MapDef) -> void:
	if map_def == null:
		return

	_active_map_id = map_def.id
	base_height = map_def.base_height
	difficulty_ramp_distance = map_def.difficulty_ramp_distance
	_ground_color = map_def.ground_color
	_active_surface = _load_surface(map_def.default_surface_id)
	
	# Aplicar configuración específica del mapa
	var config: Dictionary = map_configs.get(_active_map_id, {})
	if config:
		sample_step = config.get("sample_step", sample_step)
		smooth_passes = config.get("smooth_passes", smooth_passes)
		max_slope = config.get("max_slope", max_slope)
		max_slope_late = config.get("max_slope_late", max_slope_late)


func get_surface_at(world_x: float, world_y: float) -> SurfaceProfile:
	"""Devuelve el SurfaceProfile en la posición mundial dada."""
	var chunk_index := int(floor(world_x / chunk_width))
	var chunk: TerrainChunk = _chunks.get(chunk_index)
	if chunk == null:
		return _active_surface

	var local_x := world_x - chunk.position.x
	var surface_id := chunk.get_surface_id_at_local_x(local_x)
	return _get_surface_profile(surface_id)


func get_active_map_id() -> String:
	return _active_map_id


func get_difficulty(world_x: float) -> float:
	if world_x <= flat_spawn_length:
		return 0.0

	var ramp_x := maxf(world_x - flat_spawn_length, 0.0)
	return clampf(ramp_x / difficulty_ramp_distance, 0.0, 1.0)


func get_height_at(world_x: float) -> float:
	var varied_height := _get_varied_height(world_x)

	if world_x <= flat_spawn_length:
		return base_height

	if world_x < flat_spawn_length + spawn_blend_length:
		var blend_t := (world_x - flat_spawn_length) / spawn_blend_length
		blend_t = smoothstep(0.0, 1.0, blend_t)
		return lerpf(base_height, varied_height, blend_t)

	return varied_height


func get_spawn_position(spawn_x: float = 120.0) -> Vector2:
	var ground_y := get_height_at(spawn_x)
	return Vector2(spawn_x, ground_y - 42.0)


func update_for_position(world_x: float) -> void:
	var center_index := int(floor(world_x / chunk_width))

	for index in range(center_index - chunks_behind, center_index + chunks_ahead + 1):
		if not _chunks.has(index):
			_spawn_chunk(index)

	var indices_to_remove: Array[int] = []
	for index: int in _chunks.keys():
		if index < center_index - chunks_behind or index > center_index + chunks_ahead:
			indices_to_remove.append(index)

	for index: int in indices_to_remove:
		var chunk: TerrainChunk = _chunks[index]
		chunk.queue_free()
		_chunks.erase(index)


func _get_varied_height(world_x: float) -> float:
	var difficulty := get_difficulty(world_x)
	
	# Configuración por mapa
	var config: Dictionary = map_configs.get(_active_map_id, {})
	var amplitude_mult_max: float = config.get("amplitude_mult_max", 2.6)
	var height_clamp_min: float = config.get("height_clamp_min", -100.0)
	var height_clamp_max: float = config.get("height_clamp_max", 100.0)
	
	var amplitude_mult := lerpf(1.0, amplitude_mult_max, difficulty)
	var freq_mult := lerpf(1.0, 1.4, difficulty)

	# Ridged noise principal - crestas naturales
	var noise_height := _noise.get_noise_1d(world_x * 0.0018 * freq_mult) * lerpf(32.0, 72.0, difficulty)
	noise_height *= amplitude_mult

	# Detalle suave (solo 1 octava, menor ganancia)
	var detail := _detail_noise.get_noise_1d(world_x * 0.0045 * freq_mult) * lerpf(0.0, 10.0, difficulty)

	# Una sola onda larga para macro-forma (sin interferencia de 3 senos)
	var macro_wave := sin(world_x * 0.002 * freq_mult) * lerpf(15.0, 40.0, difficulty)

	var base := base_height + noise_height + detail + macro_wave
	
	# Clamp según configuración del mapa
	base = clampf(base, base_height + height_clamp_min, base_height + height_clamp_max)
	
	return base


func _get_max_slope_at(world_x: float) -> float:
	return lerpf(max_slope, max_slope_late, get_difficulty(world_x))


func _spawn_chunk(index: int) -> void:
	var chunk: TerrainChunk = _chunk_scene.instantiate() as TerrainChunk
	chunk.position.x = index * chunk_width
	add_child(chunk)

	var chunk_start_x := chunk.position.x
	var chunk_end_x := chunk_start_x + chunk_width
	
	# Calcular cuántos segmentos caben exactamente
	var num_segments := int(chunk_width / sample_step)
	# Ajustar sample_step para que divida exacto al chunk_width
	var actual_step := chunk_width / num_segments
	
	# Generar puntos: boundary exactos + interior
	var surface_points := PackedVector2Array()
	surface_points.resize(num_segments + 1)
	
	# Puntos de frontera DETERMINÍSTICOS (nunca se modifican)
	surface_points[0] = Vector2(0.0, get_height_at(chunk_start_x))
	surface_points[num_segments] = Vector2(chunk_width, get_height_at(chunk_end_x))
	
	# Puntos interiores
	for i in range(1, num_segments):
		var local_x := i * actual_step
		surface_points[i] = Vector2(local_x, get_height_at(chunk_start_x + local_x))
	
	# Suavizado SOLO interior (índices 1 a num_segments-1)
	var smoothed := _smooth_surface_points_interior(surface_points, chunk_start_x)
	
	# Generar surface_ids para segmentos (num_segments segmentos)
	var surface_ids := _generate_surface_ids(smoothed, chunk_start_x)
	
	chunk.setup(smoothed, surface_ids)
	chunk.ground_color = _ground_color
	_chunks[index] = chunk


func _generate_surface_ids(surface_points: PackedVector2Array, chunk_start_x: float) -> PackedStringArray:
	"""Genera IDs de superficie por segmento basándose en ruido y reglas del mapa."""
	var ids := PackedStringArray()
	var num_segments := surface_points.size() - 1
	if num_segments <= 0:
		return ids

	ids.resize(num_segments)

	# Para mapas futuros con mecánicas especiales (lagos, etc.), se puede extender aquí
	# Por ahora: ruido simple para test (Fase A)
	if _active_map_id == "arctic":
		# Ártico: mayormente hielo
		for i in range(num_segments):
			var world_x := chunk_start_x + surface_points[i].x
			var n := _surface_noise.get_noise_1d(world_x)
			ids[i] = "ice" if n > 0.3 else "dirt"
	else:
		# Campo y otros: mayormente dirt con parches de hielo ocasionales
		for i in range(num_segments):
			var world_x := chunk_start_x + surface_points[i].x
			var n := _surface_noise.get_noise_1d(world_x)
			ids[i] = "ice" if n > surface_ice_threshold else "dirt"

	# Suavizar transiciones: evitar segmentos aislados de hielo
	_smooth_surface_ids(ids)

	return ids


func _smooth_surface_ids(ids: PackedStringArray) -> void:
	"""Elimina segmentos aislados de un tipo (evita parches de 1-2 segmentos)."""
	if ids.size() < 3:
		return

	var min_run := surface_ice_min_width
	for pass_idx in range(2):  # dos pasadas
		for i in range(1, ids.size() - 1):
			if ids[i] != ids[i - 1] and ids[i] != ids[i + 1]:
				# Segmento aislado, fusionar con vecinos
				ids[i] = ids[i - 1]


func _smooth_surface_points_interior(points: PackedVector2Array, chunk_start_x: float) -> PackedVector2Array:
	"""Suaviza solo puntos interiores, mantiene fronteras (índice 0 y -1) fijas."""
	if points.size() < 10:  # mínimo: 2 fronteras + 8 interiores
		return points

	var smoothed := points.duplicate()
	var working := points.duplicate()
	var buffer: int = 3  # puntos de borde que NO se suavizan

	for _pass_index in smooth_passes:
		working = smoothed.duplicate()
		# Suavizar SOLO puntos interiores con buffer de seguridad
		for point_index in range(buffer, smoothed.size() - buffer):
			var prev_y: float = working[point_index - 1].y
			var curr_y: float = working[point_index].y
			var next_y: float = working[point_index + 1].y
			smoothed[point_index].y = prev_y * 0.2 + curr_y * 0.6 + next_y * 0.2

	_limit_slope(smoothed, chunk_start_x)
	return smoothed


func _smooth_surface_points(points: PackedVector2Array, chunk_start_x: float) -> PackedVector2Array:
	if points.size() < 3:
		return points

	var smoothed := points.duplicate()
	var working := points.duplicate()

	for _pass_index in smooth_passes:
		working = smoothed.duplicate()
		for point_index in range(1, smoothed.size() - 1):
			var prev_y: float = working[point_index - 1].y
			var curr_y: float = working[point_index].y
			var next_y: float = working[point_index + 1].y
			smoothed[point_index].y = prev_y * 0.2 + curr_y * 0.6 + next_y * 0.2

	_limit_slope(smoothed, chunk_start_x)
	return smoothed


func _limit_slope(points: PackedVector2Array, chunk_start_x: float) -> void:
	for point_index in range(1, points.size()):
		var world_x: float = chunk_start_x + points[point_index].x
		var max_delta: float = sample_step * _get_max_slope_at(world_x)
		var delta_y: float = points[point_index].y - points[point_index - 1].y
		if absf(delta_y) > max_delta:
			points[point_index].y = points[point_index - 1].y + signf(delta_y) * max_delta

	for point_index in range(points.size() - 2, -1, -1):
		var world_x: float = chunk_start_x + points[point_index].x
		var max_delta: float = sample_step * _get_max_slope_at(world_x)
		var delta_y: float = points[point_index].y - points[point_index + 1].y
		if absf(delta_y) > max_delta:
			points[point_index].y = points[point_index + 1].y + signf(delta_y) * max_delta


func _load_surface(surface_id: String) -> SurfaceProfile:
	if surface_id.is_empty():
		return null
	var path := "res://resources/content/surfaces/%s.tres" % surface_id
	if ResourceLoader.exists(path):
		return load(path) as SurfaceProfile
	return null


func _get_surface_profile(surface_id: String) -> SurfaceProfile:
	if surface_id.is_empty():
		return _active_surface

	if _surface_cache.has(surface_id):
		return _surface_cache[surface_id]

	var profile := _load_surface(surface_id)
	if profile == null:
		profile = _active_surface

	_surface_cache[surface_id] = profile
	return profile