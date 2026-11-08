# Hoja de ruta — Hill Climbing Temu (Godot 4.6)

> **Estado actual (2025-08-27): MVP completo + Sistema de contenido (Garaje) implementado. Fase A (Superficies) COMPLETA — 4 superficies con física + partículas visuales funcionando.**

---

## ✅ Qué YA funciona (MVP + Garaje + Fase A)

| Sistema | Estado | Detalle |
|---------|--------|---------|
| **Física del vehículo** | ✅ Completo | Raycast wheels, suspensión, torque en aire, límites de velocidad angular |
| **Terreno procedural infinito** | ✅ Completo | Chunks 2000px, noise + ondas, ramp de dificultad, reciclaje |
| **Combustible + Game Over** | ✅ Completo | Consumo idle/acel, bidones, muerte por vacío o crash (cuello) |
| **Monedas + Economía** | ✅ Completo | Spawn en suelo/aire, contador persistente, récord por mapa |
| **Mejoras (3 tipos, 5 niveles)** | ✅ Completo | Motor (+12%/nvl), Suspensión (amortiguación), Tanque (+15%/nvl) |
| **Menús** | ✅ Completo | Main → Garage (Vehículos/Mapas/Mejoras) → Game → GameOver |
| **Persistencia** | ✅ Completo | `user://save.json` con vehículos/mapas desbloqueados, upgrades, récords |
| **Content Registry** | ✅ Completo | Carga `VehicleDef`, `MapDef`, `SurfaceProfile` desde `.tres` en `resources/content/` |
| **Garaje UI** | ✅ Completo | 3 pestañas, desbloqueo/equipado/selección, precios, récords por mapa |
| **Sistema de superficies (Fase A)** | ✅ Completo | 4 superficies (dirt, ice, mud, sand) con física distinta + partículas visuales por rueda |
| **Terreno con superficies por segmento** | ✅ Completo | `TerrainChunk.surface_ids` array, `TerrainGenerator` asigna por ruido + suavizado 3-pasos |
| **Ruedas aplican física por superficie** | ✅ Completo | `Wheel.gd` lee `SurfaceProfile` vía `TerrainGenerator.get_surface_at()` y aplica 4 multiplicadores |
| **Partículas por superficie (Fase A2)** | ✅ Completo | `VehicleEffects` emite GPUParticles2D por rueda según `particle_enum` (dust/ice/mud/sand) |

---

## 📦 Contenido definido (data-only, **listo para usar**)

| Tipo | ID | Disponible | Coste | Notas |
|------|-----|------------|-------|-------|
| **VehicleDef** | `jeep` | ✅ Sí | 0 | Vehículo base, usa `vehicle.tscn` + `vehicle_stats.tres` |
| **VehicleDef** | `big_finger` | ❌ No | 500 | **Mismo scene/stats que Jeep** — falta mecánica deformable y 4 ruedas |
| **MapDef** | `countryside` | ✅ Sí | 0 | Mapa base, surfaces `["dirt", "ice"]` (parches) |
| **MapDef** | `arctic` | ❌ No | 350 | Tags `ice`, `frozen_lakes` — surface `["ice", "dirt"]`, **sin lagos aún** |
| **SurfaceProfile** | `dirt` | ✅ Sí | — | friction 1.0, lateral 1.0, drive 1.0, drag 0.0, `particle_enum=dust` |
| **SurfaceProfile** | `ice` | ✅ Sí | — | friction 0.15, lateral 0.3, drive 0.6, drag 0.0, `particle_enum=ice` |
| **SurfaceProfile** | `mud` | ✅ Sí | — | friction 0.45, lateral 0.35, drive 0.5, drag 0.15, `particle_enum=mud` |
| **SurfaceProfile** | `sand` | ✅ Sí | — | friction 0.55, lateral 0.45, drive 0.6, drag 0.12, `particle_enum=sand` |

**VehicleStats** ya tiene `tire_grip_multipliers = { "dirt": 1.0, "ice": 0.4, "rock": 0.9 }` y **Wheel.gd** lee `terrain_generator.get_surface_at()` — **AHORA devuelve superficie correcta por posición.**

---

## 🎯 Próximos hitos (orden de dependencia)

### Fase B — Mapa Ártico (hielo + lagos congelados) — **5–7 días**
> **Objetivo:** Mapa con mecánicas únicas que premie neumáticos de hielo.

| Tarea | Detalle |
|-------|---------|
| B1. Generación de lagos: detectar valles profundos (`height < local_mean - threshold`), aplanar, marcar `frozen_lake` (fricción aún menor, ej. 0.10) | `TerrainGenerator._spawn_chunk()` + nuevo `_generate_lakes()` |
| B2. Transición suave bordes lago (blend 80px) | Suavizado extra en `_smooth_surface_points` |
| B3. Visual: parallax azul/gris, suelo blanco-azul, lagos cian semitransparente | `GameParallax.apply_map()`, `TerrainChunk.ground_color` por segmento |
| B4. `arctic.tres`: `available = true`, `default_surface_id = "ice"` | Editar resource |
| B5. Balance: bidones +15% spacing, monedas +10% | Ajustar `PickupManager` params por mapa (extender `MapDef`) |
| B6. Neumáticos de hielo (upgrade): `tire_grip_multipliers["ice"] = 0.85` en `VehicleStats` | Nuevo upgrade tipo `CHAINS` o `ARCTIC_TIRES` en `UpgradeDefs` |

**Entregable B:** Ártico jugable en garaje; sin neumáticos de hielo es casi imposible pasar 500m.

---

### Fase C — Big Finger (neumáticos deformables + 4 ruedas) — **7–10 días**
> **Objetivo:** Vehículo pesado con grip dependiente de compresión visual/física.

| Tarea | Archivos |
|-------|----------|
| C1. `DeformableWheel` extends `VehicleWheel`: `compression_ratio` escala sprite Y, `deform_grip = lerp(base, max, compression * 0.8)` | `scripts/vehicle/deformable_wheel.gd` (nuevo) |
| C2. Escena `big_finger.tscn`: chasis más ancho/pesado (120–150kg), **4 ruedas** (2 ejes, drive_share 0.25 c/u), `air_torque` reducido | `scenes/game/vehicles/big_finger.tscn` (nuevo) |
| C3. `big_finger_stats.tres`: masa alta, suspensión blanda, `tire_grip_multipliers` con `ice: 0.3` | `resources/vehicles/big_finger_stats.tres` (nuevo) |
| C4. `big_finger.tres`: `scene_path = "res://scenes/game/vehicles/big_finger.tscn"`, `stats_path = "...big_finger_stats.tres"` | Editar resource |
| C5. Mejoras propias (Motor V8, Neumáticos blandos, Suspensión reforzada) — máx 3/vehículo | Extender `UpgradeDefs` o `VehicleDef.upgrades_override` |

**Entregable C:** Big Finger desbloqueable (500 monedas), dominante en Campo, terrible en Ártico sin upgrades.

---

### Fase D/E — Backlog de contenido (tras validar B–C)

| Vehículo | Mecánica clave | Mapa ideal |
|----------|----------------|------------|
| Motocross | Ligera, control aéreo extremo | Campo / Colinas |
| Tanque | Orugas (sin ruedas), grip constante | Ártico / Desierto |
| Monociclo | 1 rueda, equilibrio activo | Modo experto |
| Lunar Rover | Gravedad 0.4×, suspensión larga | Luna (mapa futuro) |

| Mapa | Mecánica clave | Requiere |
|------|----------------|----------|
| Desierto | Arena (drag alto, grip bajo subida) | Neumáticos anchos |
| Montaña | Pendientes extremas, acantilados | Motor + suspensión |
| Luna | Gravedad reducida, saltos largos | Lunar Rover |
| Autopista | Tramos planos + obstáculos | Velocidad pura |

---

## 📋 Checklist técnico inmediato (acción hoy)

- [ ] **B1:** Implementar `_generate_lakes()` en `TerrainGenerator` — detectar valles y crear segmentos `frozen_lake`
- [ ] **B2:** Suavizado extra en `_smooth_surface_points` para bordes de lago
- [ ] **B3:** Actualizar `GameParallax.apply_map()` para colores Ártico + lagos cian
- [ ] **B4:** Poner `arctic.tres available = true` y testear en garaje
- [ ] **Test manual:** F5 → Garage → Desbloquear Ártico (o temporal `unlock_cost=0`) → Jugar → Verificar lagos + partículas hielo

---

## 🗂️ Arquitectura actual (resumen para onboarding)

```
res://
├── scenes/
│   ├── game/
│   │   ├── game_world.tscn       # Nivel principal: TerrainGenerator, Vehicle, PickupManager, Camera, Parallax
│   │   ├── terrain_chunk.tscn    # StaticBody2D + Polygon2D (visual) + CollisionPolygon2D
│   │   └── vehicle.tscn          # RigidBody2D (chasis) + 2× Wheel (RayCast2D) + DriverHead(area) + StuntTracker + VehicleEffects
│   └── ui/
│       ├── main_menu.tscn
│       ├── garage_menu.tscn      # TabContainer: Vehículos | Mapas | Mejoras
│       ├── game_over.tscn
│       └── upgrade_menu.tscn     # (legacy, garage ya incluye mejoras)
├── scripts/
│   ├── autoload/
│   │   ├── game_state.gd         # Estado global: coins, best_distance, unlocked[], upgrades{}, map_bests{}
│   │   ├── content_registry.gd   # Catálogo runtime: load *.tres → Dict[VehicleDef], Dict[MapDef], Dict[SurfaceProfile]
│   │   └── scene_paths.gd        # Navegación entre escenas
│   ├── vehicle/
│   │   ├── vehicle_controller.gd # RigidBody2D: input, fuel, air torque, wheel loop, death
│   │   ├── wheel.gd              # RayCast2D spring + drive/lateral forces + surface grip (multipliers aplicados)
│   │   ├── driver.gd             # Area2D head hitbox → crash detection
│   │   ├── stunt_tracker.gd      # Air time, flips → bonus coins
│   │   └── vehicle_stats.gd      # Resource: engine_force, grip, suspension, fuel, tire_grip_multipliers{}
│   ├── terrain/
│   │   ├── terrain_generator.gd  # Chunks, noise, height, get_surface_at() [REAL], apply_map(), surface assignment
│   │   └── terrain_chunk.gd      # Build polygon from surface_points + surface_ids array
│   ├── pickups/
│   │   ├── pickup_manager.gd     # Spawn fuel/coins ahead, cull behind
│   │   ├── coin.gd / fuel_can.gd
│   ├── ui/
│   │   ├── garage_menu.gd        # 3 tabs, dynamic rows, unlock/equip/upgrade buttons
│   │   ├── main_menu.gd / game_over.gd / upgrade_menu.gd
│   │   └── touch_pedal.gd        # Mobile gas/brake buttons
│   ├── upgrades/
│   │   └── upgrade_defs.gd       # 3 types, costs, max_level=5
│   ├── content/
│   │   ├── vehicle_def.gd        # id, name, desc, scene_path, stats_path, unlock_cost, available
│   │   ├── map_def.gd            # id, name, terrain params, mechanic_tags, default_surface_id, surface_ids[]
│   │   └── surface_profile.gd    # SurfaceProfile: id, display_name, friction, lateral, drive, drag, color, particle_enum
│   └── effects/
│       └── vehicle_effects.gd    # GPUParticles2D por rueda según surface.particle_enum + landing dust
├── resources/
│   ├── vehicle_stats.tres        # Base stats (Jeep)
│   └── content/
│       ├── vehicles/jeep.tres, big_finger.tres
│       ├── maps/countryside.tres, arctic.tres
│       └── surfaces/dirt.tres, ice.tres, mud.tres, sand.tres
```

---

## ⚠️ Riesgos conocidos y mitigación

| Riesgo | Mitigación |
|--------|------------|
| **Superficies rotan colisión** | Generar polígonos convexos por segmento; lagos = rectángulos simples |
| **Big Finger inestable (física 4 ruedas)** | Empezar con raycast wheels conservadores; masa/damping altos; `angular_damp` extra |
| **Scope creep en upgrades** | Máx 3 por vehículo; costes escalados; `UpgradeDefs` centralizado |
| **Rendimiento móvil** | Chunks activos ≤ 7; sprites simples; sin partículas pesadas en MVP |
| **Lagos generados en zonas planas** | Requerir `height < local_mean - threshold` (solo valles reales) |

---

## 📅 Cronograma estimado (tiempo parcial ~3–4h/día)

| Fase | Duración | Acumulado |
|------|----------|-----------|
| A. Superficies por chunk + visual | **COMPLETA** | 5 días |
| B. Mapa Ártico + lagos | 5–7 días | 12 días |
| C. Big Finger (4 ruedas + deform) | 7–10 días | **~20 días** |
| **Total post-MVP core** | | **~3–4 semanas** |

---

## 🔗 Referencias rápidas

- **ROADMAP_CONTENT.md** — Detalle de vehículos/mapas backlog (Fase D/E)
- **game_state.gd:221** — `build_vehicle_stats()` aplica upgrades al resource base
- **wheel.gd** — Aplica 4 multiplicadores de `SurfaceProfile` (friction, lateral, drive, drag)
- **terrain_generator.gd** — `get_surface_at()` **REAL** + asignación procedural de superficies
- **garage_menu.gd** — UI completa de desbloqueo/equipado/upgrades
- **vehicle_effects.gd** — Partículas por superficie (dust/ice/mud/sand) + landing dust
- **references/surface-terrain-debugging.md** (skill godot-debugging) — Patrones de debug Fase A
- **references/surface-terrain-system.md** (skill roadmap-authoring) — Arquitectura completa Fase A
