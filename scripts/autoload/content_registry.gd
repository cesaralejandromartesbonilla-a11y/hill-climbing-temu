extends Node

const VEHICLES_DIR := "res://resources/content/vehicles/"
const MAPS_DIR := "res://resources/content/maps/"
const SURFACES_DIR := "res://resources/content/surfaces/"

var _vehicles: Dictionary = {}
var _maps: Dictionary = {}
var _surfaces: Dictionary = {}


func _ready() -> void:
	_load_content()


func _load_content() -> void:
	for path: String in _list_resources(VEHICLES_DIR):
		var def := load(path) as VehicleDef
		if def != null and not def.id.is_empty():
			_vehicles[def.id] = def

	for path: String in _list_resources(MAPS_DIR):
		var def := load(path) as MapDef
		if def != null and not def.id.is_empty():
			_maps[def.id] = def

	for path: String in _list_resources(SURFACES_DIR):
		var def := load(path) as SurfaceProfile
		if def != null and not def.id.is_empty():
			_surfaces[def.id] = def


func _list_resources(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return results

	for file_name: String in dir.get_files():
		if file_name.ends_with(".tres"):
			results.append(dir_path.path_join(file_name))
	return results


func get_all_vehicles() -> Array[VehicleDef]:
	var list: Array[VehicleDef] = []
	for vehicle_id: String in _vehicles.keys():
		list.append(_vehicles[vehicle_id])
	list.sort_custom(func(a: VehicleDef, b: VehicleDef) -> bool:
		return a.unlock_cost < b.unlock_cost
	)
	return list


func get_all_maps() -> Array[MapDef]:
	var list: Array[MapDef] = []
	for map_id: String in _maps.keys():
		list.append(_maps[map_id])
	list.sort_custom(func(a: MapDef, b: MapDef) -> bool:
		return a.unlock_cost < b.unlock_cost
	)
	return list


func get_all_surfaces() -> Array[SurfaceProfile]:
	var list: Array[SurfaceProfile] = []
	for surface_id: String in _surfaces.keys():
		list.append(_surfaces[surface_id])
	return list


func get_vehicle(vehicle_id: String) -> VehicleDef:
	return _vehicles.get(vehicle_id) as VehicleDef


func get_map(map_id: String) -> MapDef:
	return _maps.get(map_id) as MapDef


func get_surface(surface_id: String) -> SurfaceProfile:
	return _surfaces.get(surface_id) as SurfaceProfile


func get_default_vehicle_id() -> String:
	return "jeep"


func get_default_map_id() -> String:
	return "countryside"
