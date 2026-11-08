extends Node

@export var min_landing_speed: float = 90.0

var _vehicle: VehicleController
var _was_grounded: bool = true

# Partículas continuas por rueda
var _dust_particles_back: CPUParticles2D
var _dust_particles_front: CPUParticles2D
var _current_surface_type: String = ""

var _wheel_back: VehicleWheel
var _wheel_front: VehicleWheel


func _physics_process(_delta: float) -> void:
	# Inicialización diferida (las ruedas pueden no estar listas en _ready)
	if _vehicle == null:
		_vehicle = get_parent() as VehicleController
		if _vehicle == null:
			return
		_vehicle.died.connect(_on_vehicle_died)
		_wheel_back = _vehicle.get_node_or_null("WheelBack") as VehicleWheel
		_wheel_front = _vehicle.get_node_or_null("WheelFront") as VehicleWheel
		
		# Crear sistemas de partículas para cada rueda
		_dust_particles_back = _create_surface_particles("dust")
		_dust_particles_front = _create_surface_particles("dust")
		if _dust_particles_back:
			_vehicle.add_child(_dust_particles_back)
		if _dust_particles_front:
			_vehicle.add_child(_dust_particles_front)

	if not _vehicle.is_alive:
		_stop_all_particles()
		return

	var grounded := _vehicle.is_grounded()

	# Partículas de aterrizaje
	if grounded and not _was_grounded:
		var impact_speed: float = _vehicle.linear_velocity.length()
		if impact_speed >= min_landing_speed:
			_spawn_dust(impact_speed)

	# Partículas continuas de superficie
	_update_surface_particles(_delta)

	# Partículas de aceleración (patinaje)
	_update_acceleration_particles(_delta)

	_was_grounded = grounded


func _update_surface_particles(delta: float) -> void:
	if _wheel_back == null or _wheel_front == null:
		return

	var back_surface := _wheel_back.get_current_surface_type()
	var front_surface := _wheel_front.get_current_surface_type()

	# Usar el tipo de superficie de la rueda trasera (motor) como principal
	var surface_type := back_surface if not back_surface.is_empty() else front_surface

	# Solo cambiar si es diferente al actual
	if surface_type != _current_surface_type:
		_switch_particle_type(surface_type)

	# Actualizar posición de partículas
	if _current_surface_type != "none" and _current_surface_type != "":
		_update_particle_positions()


func _switch_particle_type(surface_type: String) -> void:
	_current_surface_type = surface_type

	# Detener partículas anteriores
	_stop_all_particles()

	if surface_type.is_empty() or surface_type == "none":
		return

	# Recrear partículas con el nuevo tipo
	_dust_particles_back = _create_surface_particles(surface_type)
	_dust_particles_front = _create_surface_particles(surface_type)

	if _dust_particles_back:
		_dust_particles_back.emitting = true
		_vehicle.add_child(_dust_particles_back)
	if _dust_particles_front:
		_dust_particles_front.emitting = true
		_vehicle.add_child(_dust_particles_front)


func _create_surface_particles(surface_type: String) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.one_shot = false
	particles.emitting = true
	particles.amount = 8
	particles.lifetime = 0.4
	particles.explosiveness = 0.0
	particles.speed_scale = 1.0
	particles.local_coords = false

	match surface_type:
		"dust":
			particles.direction = Vector2(0.0, 1.0)
			particles.spread = 45.0
			particles.gravity = Vector2(0.0, 180.0)
			particles.initial_velocity_min = 20.0
			particles.initial_velocity_max = 60.0
			particles.scale_amount_min = 2.0
			particles.scale_amount_max = 4.0
			particles.color = Color(0.55, 0.42, 0.28, 0.6)
			particles.color_ramp = Gradient.new()
			var ramp_dust: Gradient = particles.color_ramp
			ramp_dust.set_colors(PackedColorArray([
				Color(0.55, 0.42, 0.28, 0.0),
				Color(0.55, 0.42, 0.28, 0.6),
				Color(0.55, 0.42, 0.28, 0.0)
			]))
		"ice":
			particles.direction = Vector2(0.0, 1.0)
			particles.spread = 30.0
			particles.gravity = Vector2(0.0, 80.0)
			particles.initial_velocity_min = 15.0
			particles.initial_velocity_max = 40.0
			particles.scale_amount_min = 1.5
			particles.scale_amount_max = 3.0
			particles.color = Color(0.7, 0.9, 1.0, 0.7)
			particles.color_ramp = Gradient.new()
			var ramp_ice: Gradient = particles.color_ramp
			ramp_ice.set_colors(PackedColorArray([
				Color(0.7, 0.9, 1.0, 0.0),
				Color(0.7, 0.9, 1.0, 0.7),
				Color(0.7, 0.9, 1.0, 0.0)
			]))
		"mud":
			particles.direction = Vector2(0.0, 1.0)
			particles.spread = 60.0
			particles.gravity = Vector2(0.0, 250.0)
			particles.initial_velocity_min = 30.0
			particles.initial_velocity_max = 80.0
			particles.scale_amount_min = 2.5
			particles.scale_amount_max = 5.0
			particles.color = Color(0.35, 0.28, 0.18, 0.8)
			particles.color_ramp = Gradient.new()
			var ramp_mud: Gradient = particles.color_ramp
			ramp_mud.set_colors(PackedColorArray([
				Color(0.35, 0.28, 0.18, 0.0),
				Color(0.35, 0.28, 0.18, 0.8),
				Color(0.35, 0.28, 0.18, 0.0)
			]))
		"sand":
			particles.direction = Vector2(0.0, 1.0)
			particles.spread = 50.0
			particles.gravity = Vector2(0.0, 200.0)
			particles.initial_velocity_min = 25.0
			particles.initial_velocity_max = 70.0
			particles.scale_amount_min = 2.0
			particles.scale_amount_max = 4.5
			particles.color = Color(0.85, 0.75, 0.55, 0.7)
			particles.color_ramp = Gradient.new()
			var ramp_sand: Gradient = particles.color_ramp
			ramp_sand.set_colors(PackedColorArray([
				Color(0.85, 0.75, 0.55, 0.0),
				Color(0.85, 0.75, 0.55, 0.7),
				Color(0.85, 0.75, 0.55, 0.0)
			]))
		_:
			return null

	return particles


func _update_particle_positions() -> void:
	if _wheel_back and _dust_particles_back:
		var contact_pos := _wheel_back.get_ray_contact_point()
		if contact_pos != Vector2.ZERO:
			_dust_particles_back.global_position = contact_pos + Vector2(0.0, 2.0)

	if _wheel_front and _dust_particles_front:
		var contact_pos := _wheel_front.get_ray_contact_point()
		if contact_pos != Vector2.ZERO:
			_dust_particles_front.global_position = contact_pos + Vector2(0.0, 2.0)


func _stop_all_particles() -> void:
	if _dust_particles_back and is_instance_valid(_dust_particles_back):
		_dust_particles_back.emitting = false
		_dust_particles_back.queue_free()
		_dust_particles_back = null

	if _dust_particles_front and is_instance_valid(_dust_particles_front):
		_dust_particles_front.emitting = false
		_dust_particles_front.queue_free()
		_dust_particles_front = null

	_current_surface_type = ""


func _on_vehicle_died(reason: String) -> void:
	_stop_all_particles()

	if reason != "crash":
		return

	_spawn_sparks(_vehicle.global_position)


func _spawn_dust(impact_speed: float) -> void:
	var dust := _create_dust_particles(impact_speed)
	dust.global_position = _vehicle.global_position + Vector2(-10.0, 18.0)
	get_tree().current_scene.add_child(dust)
	_cleanup_after(dust, 0.7)

	if impact_speed >= 140.0:
		var cameras := get_tree().get_nodes_in_group("follow_camera")
		if not cameras.is_empty() and cameras[0].has_method("shake"):
			cameras[0].shake(clampf(impact_speed * 0.04, 2.0, 8.0))


func _spawn_sparks(global_pos: Vector2) -> void:
	var sparks := CPUParticles2D.new()
	sparks.one_shot = true
	sparks.emitting = true
	sparks.amount = 24
	sparks.lifetime = 0.45
	sparks.explosiveness = 0.95
	sparks.direction = Vector2(0.0, -1.0)
	sparks.spread = 180.0
	sparks.gravity = Vector2(0.0, 400.0)
	sparks.initial_velocity_min = 80.0
	sparks.initial_velocity_max = 200.0
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 4.0
	sparks.color = Color(1.0, 0.55, 0.15, 1.0)
	sparks.global_position = global_pos + Vector2(0.0, -20.0)
	get_tree().current_scene.add_child(sparks)
	_cleanup_after(sparks, 0.6)


func _create_dust_particles(impact_speed: float) -> CPUParticles2D:
	var dust := CPUParticles2D.new()
	dust.one_shot = true
	dust.emitting = true
	dust.amount = int(clampf(impact_speed / 18.0, 6.0, 20.0))
	dust.lifetime = 0.55
	dust.explosiveness = 0.85
	dust.direction = Vector2(0.0, -1.0)
	dust.spread = 55.0
	dust.gravity = Vector2(0.0, 120.0)
	dust.initial_velocity_min = 30.0
	dust.initial_velocity_max = 80.0 + impact_speed * 0.15
	dust.scale_amount_min = 3.0
	dust.scale_amount_max = 6.0
	dust.color = Color(0.55, 0.42, 0.28, 0.8)
	return dust


func _cleanup_after(node: Node, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(node):
		node.queue_free()


func _update_acceleration_particles(delta: float) -> void:
	"""Emite partículas extra cuando las ruedas patinan al acelerar sin avanzar."""
	if _wheel_back == null or _wheel_front == null:
		return
	
	var gas := _vehicle.get_gas_input()
	if gas <= 0.05:
		return
	
	# Verificar si la rueda trasera patina (gira pero no avanza mucho)
	var back_velocity := _wheel_back.get_forward_velocity()
	var vehicle_speed := _vehicle.linear_velocity.length()
	
	# Si la rueda gira rápido pero el vehículo avanza lento = patinaje
	var slip_threshold := 30.0
	if abs(back_velocity) > slip_threshold and vehicle_speed < 20.0:
		# Emitir partículas de patinaje
		_emit_slip_particles(_wheel_back, gas)
	
	var front_velocity := _wheel_front.get_forward_velocity()
	if abs(front_velocity) > slip_threshold and vehicle_speed < 20.0:
		_emit_slip_particles(_wheel_front, gas)


func _emit_slip_particles(wheel: VehicleWheel, gas: float) -> void:
	"""Emite un burst de partículas por patinaje."""
	var surface_type := wheel.get_current_surface_type()
	if surface_type.is_empty() or surface_type == "none":
		surface_type = "dust"
	
	var contact_pos := wheel.get_ray_contact_point()
	if contact_pos == Vector2.ZERO:
		return
	
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.amount = int(6.0 * gas)
	particles.lifetime = 0.25
	particles.explosiveness = 0.8
	particles.speed_scale = 1.0
	particles.local_coords = false
	particles.direction = Vector2(0.0, 1.0)
	particles.spread = 70.0
	particles.gravity = Vector2(0.0, 200.0)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 100.0
	particles.scale_amount_min = 2.5
	particles.scale_amount_max = 5.0
	
	match surface_type:
		"ice":
			particles.color = Color(0.8, 0.95, 1.0, 0.9)
			particles.gravity = Vector2(0.0, 60.0)
			particles.spread = 50.0
		"mud":
			particles.color = Color(0.4, 0.3, 0.2, 0.9)
			particles.gravity = Vector2(0.0, 300.0)
		"sand":
			particles.color = Color(0.9, 0.8, 0.5, 0.8)
		_:
			particles.color = Color(0.6, 0.45, 0.3, 0.7)
	
	particles.global_position = contact_pos + Vector2(0.0, 3.0)
	_vehicle.add_child(particles)
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(particles):
		particles.queue_free()