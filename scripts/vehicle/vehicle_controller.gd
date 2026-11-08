class_name VehicleController
extends RigidBody2D

signal died(reason: String)
signal fuel_changed(current: float, max_value: float)

@export var stats: VehicleStats

@onready var _wheel_back: VehicleWheel = $WheelBack
@onready var _wheel_front: VehicleWheel = $WheelFront

var is_alive: bool = true
var fuel_current: float = 100.0
var fuel_max: float = 100.0

var _wheels: Array[VehicleWheel] = []
var _terrain_generator: TerrainGenerator = null

# Detección de muerte por impacto fuerte
var _impact_cooldown: float = 0.0
const IMPACT_DEATH_THRESHOLD: float = 2500.0  # Impulso mínimo para morir (ajustable)
const IMPACT_COOLDOWN: float = 0.5  # Segundos entre muertes por impacto


func _ready() -> void:
	if stats == null:
		stats = VehicleStats.new()

	fuel_max = stats.fuel_capacity
	fuel_current = fuel_max
	fuel_changed.emit(fuel_current, fuel_max)

	_wheel_back.drive_share = 0.55
	_wheel_front.drive_share = 0.45

	for wheel: VehicleWheel in [_wheel_back, _wheel_front]:
		wheel.apply_from_stats(stats)
		_wheels.append(wheel)

	center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector2(-4.0, 10.0)
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE


func setup_terrain_generator(generator: TerrainGenerator) -> void:
	_terrain_generator = generator


func apply_stats(new_stats: VehicleStats) -> void:
	stats = new_stats
	fuel_max = stats.fuel_capacity
	fuel_current = fuel_max

	for wheel: VehicleWheel in _wheels:
		wheel.apply_from_stats(stats)

	fuel_changed.emit(fuel_current, fuel_max)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)

	var gas := Input.get_action_strength("gas")
	var brake := Input.get_action_strength("brake")

	_consume_fuel(delta, gas)
	if not is_alive:
		return

	var grounded := false
	for wheel: VehicleWheel in _wheels:
		wheel.update_physics(self, gas, brake, stats.engine_force, stats.brake_force, stats.grip, stats, _terrain_generator)
		grounded = grounded or wheel.is_grounded

	if not grounded:
		var air_input := gas - brake
		if not is_zero_approx(air_input):
			var facing := signf(cos(rotation))
			if is_zero_approx(facing):
				facing = 1.0
			apply_torque(air_input * stats.air_torque * facing)

	# Comprobar muerte por impacto (head hit)
	_check_impact_death()


func _check_impact_death() -> void:
	# Verificar si la cabeza/techo del vehículo golpea el suelo con fuerza
	# Raycast hacia ABAJO en espacio mundo (no relativo al vehículo)
	var roof_pos := global_position + Vector2(0.0, -30.0).rotated(rotation)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(roof_pos, roof_pos + Vector2(0.0, 60.0))  # 60px hacia abajo en mundo
	query.collide_with_bodies = false
	query.exclude = [get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)
	
	if result:
		var hit_point: Vector2 = result.position
		var distance_to_ground := roof_pos.distance_to(hit_point)
		
		# Si el techo está muy cerca del suelo (< 20px) Y vamos rápido hacia abajo
		var vertical_speed := linear_velocity.y
		if distance_to_ground < 20.0 and vertical_speed > 300.0:
			die("impact")
			_impact_cooldown = IMPACT_COOLDOWN
			return
	
	# También detectar impacto fuerte en cualquier colisión (atterizaje brusco)
	# Usamos la velocidad vertical como proxy
	var vertical_speed := linear_velocity.y
	if vertical_speed > 500.0 and _impact_cooldown <= 0.0:
		# Verificar que estemos cerca del suelo (aterrizando)
		var ground_query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0.0, 80.0))
		ground_query.collide_with_bodies = false
		ground_query.exclude = [get_rid()]
		var ground_result: Dictionary = space_state.intersect_ray(ground_query)
		if ground_result:
			var dist := global_position.distance_to(ground_result.position)
			if dist < 50.0:
				die("impact")
				_impact_cooldown = IMPACT_COOLDOWN


func is_grounded() -> bool:
	for wheel: VehicleWheel in _wheels:
		if wheel.is_grounded:
			return true
	return false


func add_fuel(amount: float) -> void:
	if not is_alive:
		return

	fuel_current = minf(fuel_max, fuel_current + amount)
	fuel_changed.emit(fuel_current, fuel_max)


func get_fuel_ratio() -> float:
	if fuel_max <= 0.0:
		return 0.0
	return fuel_current / fuel_max


func get_gas_input() -> float:
	return Input.get_action_strength("gas")


func die(reason: String) -> void:
	if not is_alive:
		return

	is_alive = false
	freeze = true
	died.emit(reason)


func _consume_fuel(delta: float, gas: float) -> void:
	var consumption: float = stats.fuel_idle_rate * delta
	if gas > 0.0:
		consumption += stats.fuel_accel_rate * gas * delta

	fuel_current = maxf(0.0, fuel_current - consumption)
	fuel_changed.emit(fuel_current, fuel_max)

	if fuel_current <= 0.0:
		die("fuel")


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	state.angular_velocity = clampf(
		state.angular_velocity,
		-stats.max_angular_velocity,
		stats.max_angular_velocity,
	)
