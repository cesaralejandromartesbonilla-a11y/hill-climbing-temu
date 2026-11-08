class_name SurfaceDef
extends Resource

## Identificador único de la superficie (ej: "dirt", "ice", "rock")
@export var id: String = ""

## Nombre visible para el jugador
@export var display_name: String = ""

## Multiplicador de fricción base. 1.0 = normal, <1.0 = resbaladizo, >1.0 = más agarre
@export var friction_multiplier: float = 1.0

## Color representativo de la superficie (útil para debug o efectos de partículas futuros)
@export var surface_color: Color = Color(0.5, 0.5, 0.5)
