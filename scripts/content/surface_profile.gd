class_name SurfaceProfile
extends Resource

## Identificador único de la superficie (ej: "dirt", "ice", "rock", "frozen_lake", "sand")
@export var id: String = ""

## Nombre visible para el jugador
@export var display_name: String = ""

## Multiplicador de fricción base. 1.0 = normal, <1.0 = resbaladizo, >1.0 = más agarre
@export var friction_multiplier: float = 1.0

## Multiplicador de grip lateral (deriva). Afecta cuánto se resbala lateralmente.
@export var lateral_grip_multiplier: float = 1.0

## Multiplicador de tracción (fuerza motriz). Afecta aceleración/freno en esta superficie.
@export var drive_multiplier: float = 1.0

## Color representativo de la superficie (útil para debug, partículas, efectos visuales)
@export var surface_color: Color = Color(0.5, 0.5, 0.5)

## Tipo de partícula al rodar sobre esta superficie (para efectos de polvo/hielo/barro/arena)
@export var particle_type: String = ""
@export_enum("none", "dust", "ice", "mud", "sand") var particle_enum: String = "none"

## Factor de arrastre (drag) adicional al rodar. 0.0 = sin drag extra.
@export var drag_multiplier: float = 0.0


func _validate_property(property: Dictionary) -> void:
	if property.name == "id":
		return
	return