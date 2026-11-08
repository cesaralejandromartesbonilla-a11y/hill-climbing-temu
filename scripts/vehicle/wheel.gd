class_name VehicleWheel
extends Node2D

@export var rest_length: float = 16.0
@export var radius: float = 14.0
@export var spring_strength: float = 14000.0
@export var damping: float = 400.0
@export var drive_share: float = 0.5

var is_grounded: bool = false
var _current_surface_type: String = ""

@onready var _ray: RayCast2D = $RayCast2D
@onready var _visual: Node2D = $WheelVisual

var _rotation_angle: float = 0.0
var _prev_grounded: bool = false


func _ready() -> void:
	if _ray == null:
		_ray = get_node_or_null("RayCast2D") as RayCast2D
	if _visual == null:
		_visual = get_node_or_null("WheelVisual") as Node2D
	
	if _ray == null:
		push_error("VehicleWheel: RayCast2D child not found!")
		return
	
	_ray.target_position = Vector2(0.0, rest_length + radius)
	_ray.enabled = true
	_ray.collide_with_areas = false


func apply_from_stats(stats: VehicleStats) -> void:
	rest_length = stats.suspension_rest_length
	radius = stats.wheel_radius
	spring_strength = stats.suspension_stiffness
	damping = stats.suspension_damping
	_ray.target_position = Vector2(0.0, rest_length + radius)


func update_physics(
	body: RigidBody2D,
	gas: float,
	brake: float,
	engine_force: float,
	brake_force: float,
	grip: float,
	stats: VehicleStats,
	terrain_generator: TerrainGenerator = null,
) -> void:
	is_grounded = _ray.is_colliding()

	if not is_grounded:
		_visual.position = Vector2(0.0, rest_length)
		_current_surface_type = ""
		return

	var contact_point := _ray.get_collision_point()
	var ground_normal := _ray.get_collision_normal()
	var ray_origin := _ray.global_position
	var ground_distance := ray_origin.distance_to(contact_point) - radius
	var compression := clampf(rest_length - ground_distance, 0.0, rest_length)

	var contact_velocity: Vector2 = _get_velocity_at_point(body, contact_point)
	var normal_velocity: float = contact_velocity.dot(ground_normal)
	var spring_force := compression * spring_strength
	var damp_force: float = normal_velocity * damping
	body.apply_force(ground_normal * (spring_force + damp_force), contact_point - body.global_position)

	var tangent := ground_normal.orthogonal()
	if tangent.dot(body.global_transform.x) < 0.0:
		tangent = -tangent

	var effective_grip := grip
	var lateral_grip_mult := 1.0
	var drive_mult := 1.0
	var drag_mult := 0.0
	var surface_type := ""

	if terrain_generator != null:
		var surface := terrain_generator.get_surface_at(contact_point.x, contact_point.y)
		if surface != null:
			var tire_mult: float = stats.tire_grip_multipliers.get(surface.id, 1.0)
			effective_grip = grip * surface.friction_multiplier * tire_mult
			lateral_grip_mult = surface.lateral_grip_multiplier
			drive_mult = surface.drive_multiplier
			drag_mult = surface.drag_multiplier
			surface_type = surface.particle_type
			_current_surface_type = surface_type

	# Calcular velocidades tangencial y lateral
	var forward_velocity := tangent * contact_velocity.dot(tangent)
	var lateral_velocity := contact_velocity - forward_velocity

	var drive_input := gas - brake

	if is_zero_approx(drive_input):
		# Sin input de aceleración: fricción de rodadura + inercia
		var friction_force := -forward_velocity * effective_grip * 0.5 * body.mass
		body.apply_force(friction_force, contact_point - body.global_position)
	else:
		var force_amount := engine_force * gas * drive_mult - brake_force * brake
		body.apply_force(tangent * force_amount * drive_share * effective_grip, contact_point - body.global_position)

	# Fricción lateral
	body.apply_force(-lateral_velocity * effective_grip * lateral_grip_mult * body.mass * 8.0, contact_point - body.global_position)

	# Aplicar drag si la superficie lo tiene
	if drag_mult > 0.0:
		body.apply_force(-forward_velocity * drag_mult * body.mass, contact_point - body.global_position)

	# Rotación visual de la rueda
	if _visual and is_grounded:
		var forward_speed := contact_velocity.dot(tangent)
		_rotation_angle += forward_speed * 0.008
		_visual.rotation = _rotation_angle

	var local_contact := to_local(contact_point)
	_visual.position = Vector2(0.0, local_contact.y + radius * 0.5)


func _get_velocity_at_point(body: RigidBody2D, global_point: Vector2) -> Vector2:
	var offset := global_point - body.global_position
	if body.center_of_mass_mode == RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM:
		offset -= body.center_of_mass.rotated(body.rotation)
	return body.linear_velocity + Vector2(-offset.y, offset.x) * body.angular_velocity


func get_current_surface_type() -> String:
	return _current_surface_type


func is_on_surface(surface_type: String) -> bool:
	return _current_surface_type == surface_type


func get_ray_contact_point() -> Vector2:
	if not is_grounded:
		return Vector2.ZERO
	return _ray.get_collision_point()


func get_forward_velocity() -> float:
	"""Velocidad hacia adelante de la rueda en el punto de contacto."""
	if not is_grounded:
		return 0.0
	var body := get_parent().get_parent() as RigidBody2D
	if body == null:
		return 0.0
	var contact_point := _ray.get_collision_point()
	var contact_velocity := _get_velocity_at_point(body, contact_point)
	var ground_normal := _ray.get_collision_normal()
	var tangent := ground_normal.orthogonal()
	if tangent.dot(body.global_transform.x) < 0.0:
		tangent = -tangent
	return contact_velocity.dot(tangent)
