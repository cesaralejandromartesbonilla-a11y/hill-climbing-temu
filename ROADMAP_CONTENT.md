# Hoja de ruta — Contenido post-MVP

> **Estado actual (2025-08-27):** MVP completo + **Garaje** (vehículos, mapas, mejoras por vehículo) implementado y funcional.  
> **Fase A (Superficies) COMPLETA** — 4 superficies (dirt, ice, mud, sand) con física distinta + partículas visuales funcionando.  
> Big Finger y Ártico aparecen en el garaje como contenido bloqueado ("Próximamente").  
> Fase B (Ártico con lagos) es el siguiente paso crítico.

---

## Visión

Expandir Hill Climbing Temu con **vehículos con mecánicas únicas** y **mapas con reglas de superficie distintas**, manteniendo el núcleo de gas/freno + física 2D.

**Principio de diseño:** cada vehículo resuelve (o sufre) mapas de forma distinta. Un mapa debe premiar el vehículo adecuado y castigar el equipamiento incorrecto.

---

## Arquitectura de contenido (ya implementada)

```
resources/content/
├── vehicles/          # VehicleDef (.tres)
└── maps/              # MapDef (.tres)
    └── surfaces/      # SurfaceProfile (.tres)

scripts/content/
├── vehicle_def.gd
├── map_def.gd
└── surface_profile.gd

scripts/autoload/
└── content_registry.gd   # Catálogo en runtime: _vehicles{}, _maps{}, _surface_profiles{}

scripts/ui/
└── garage_menu.gd        # Hub: Vehículos | Mapas | Mejoras
```

---

## Fase A — Sistema de superficies (COMPLETA) ✅

**Objetivo:** El terreno y las ruedas hablan el mismo idioma de fricción + feedback visual.

**Estado:** **COMPLETADA** (3-5 días, implementada en session 2026-08-27)

### Implementado

- [x] **A1** `SurfaceProfile` resource (extiende `SurfaceDef`): `friction`, `lateral_grip`, `drive_multiplier`, `drag_multiplier`, `surface_color`, `particle_enum`
- [x] **A2** `TerrainChunk` guarda `surface_ids: Array[String]` paralelo a `surface_points` (un ID por segmento)
- [x] **A3** `TerrainGenerator._spawn_chunk()` asigna superficie por ruido por mapa (Countryside: 85% dirt/15% ice; Arctic: 60% ice/40% dirt) + suavizado 3-pasos
- [x] **A4** `get_surface_at(world_x)` real: busca chunk → índice de segmento → devuelve `SurfaceProfile` (con interpolación entre chunks)
- [x] **A5** `tire_grip_multipliers` por vehículo en `VehicleStats` (ya existía: `dirt:1.0, ice:0.4, rock:0.9`)
- [x] **A6** `VehicleWheel` rastrea `_current_surface_type`, expone `is_on_surface()` y `get_ray_contact_point()`
- [x] **A7** `VehicleEffects` reescrito: GPUParticles2D por rueda según `particle_enum` (dust/ice/mud/sand) + landing dust puffs
- [x] **A8** 4 superficies definidas: `dirt.tres`, `ice.tres`, `mud.tres`, `sand.tres` con propiedades físicas distintas

### Entregable A — **CUMPLIDO**

El Jeep patina en hielo real en Campo (parches de hielo); `Wheel.gd` lee `terrain_generator.get_surface_at()` y aplica 4 multiplicadores reales (friction, lateral, drive, drag). Partículas cambian visualmente según superficie (polvo marrón / cristales de hielo / barro / arena).

---

## Fase B — Mapa Ártico ⬜ **SIGUIENTE (desbloqueada)**

**Objetivo:** Mapa con hielo resbaladizo y lagos congelados en depresiones del terreno.

**Duración estimada:** 5–7 días

### Mecánicas

| Mecánica | Descripción |
|----------|-------------|
| **Hielo global** | Toda la superficie usa `SurfaceProfile` ICE (fricción ~0.15–0.25) |
| **Neumáticos inadecuados** | Vehículos sin `ice_grip` alto pierden tracción; patinaje extremo en subidas |
| **Lagos congelados** | Si el terreno baja más de `lake_depth_threshold` (ej. 45 px bajo media local), rellenar con segmento plano de `FROZEN_LAKE` (fricción ~0.10) |
| **Bordes de lago** | Transición suave hielo → lago (blend 80px, fricción intermedia) |
| **Visual** | Parallax azul/gris, suelo blanco-azul, lagos con tinte cian semitransparente |

### Generación procedural de lagos

```
1. Generar perfil de altura base (noise + suavizado)
2. Calcular media móvil local en ventana de ~400 px
3. Donde height < local_mean - threshold:
   - Aplanar a altura del valle
   - Marcar segmento como FROZEN_LAKE (nuevo SurfaceProfile o usar ice con friction 0.10)
   - Ancho mínimo del lago: ~200 px (evitar charcos)
4. Suavizar bordes del lago (blend 80 px)
```

### Progresión / balance

- Desbloqueo: **350 monedas** (ya definido en `arctic.tres`)
- Bidones más espaciados (+15%) — más riesgo de quedarse sin gas
- Monedas ligeramente más frecuentes (+10%) — compensación

### Mejoras específicas del mapa

- **Cadenas** (upgrade de mapa): +grip en hielo para el vehículo equipado
- **Neumáticos árticos**: upgrade de vehículo con tag `ice_tires`

### Entregable B

Mapa Ártico jugable en garaje; sin neumáticos adecuados es casi imposible superar 500 m. Récord por mapa guardado en `map_best_distances`.

---

## Fase C — Big Finger (neumáticos deformables + 4 ruedas) ⬜ **BLOQUEADO por B**

**Objetivo:** Vehículo pesado cuyo agarre depende de la deformación visual/física del neumático.

**Duración estimada:** 7–10 días (tras Fase B)

### Referencia (Hill Climb original)

Monster truck grande, ruedas blandas que se aplastan al contacto, excelente en terreno irregular pero inestable en lago/hielo.

### Mecánicas propuestas

| Mecánica | Implementación |
|----------|----------------|
| **Neumático deformable** | `DeformableWheel` extiende `VehicleWheel`; `compression` visual escala el sprite en Y |
| **Contact patch** | A mayor compresión → mayor área de contacto → más grip (hasta un máximo) |
| **Rebote lento** | Amortiguación baja en eje visual; el neumático "late" al salir de un bache |
| **Masa alta** | Chasis ~120–150 kg; más inercia, volcaduras más violentas |
| **4 ruedas** | 2 ejes; tracción repartida 25% por rueda |
| **Control aéreo lento** | `air_torque` reducido vs Jeep |

### Fórmula de grip deformable (borrador)

```gdscript
var compression_ratio = clamp(compression / rest_length, 0.0, 1.0)
var deform_grip = lerp(base_grip, max_grip, compression_ratio * 0.8)
# En hielo: deform_grip *= ice_penalty (0.3)
```

### Archivos a crear/modificar

- `scenes/game/vehicles/big_finger.tscn` (nueva escena: chasis ancho, 4 Wheel nodes)
- `scripts/vehicle/deformable_wheel.gd` (nuevo script)
- `resources/vehicles/big_finger_stats.tres` (nuevo: masa, suspensión blanda, tire_grip_multipliers con ice:0.3)
- `resources/content/vehicles/big_finger.tres` → actualizar `scene_path` y `stats_path`, `available = true`

### Mejoras individuales (Big Finger) — máx 3

| Mejora | Efecto |
|--------|--------|
| Motor V8 | +torque |
| Neumáticos blandos | +deformación máxima, +grip en barro |
| Suspensión reforzada | Menos cabeceo en saltos |

### Entregable C

Big Finger desbloqueable (500 monedas), dominante en Campo, terrible en Ártico sin upgrades. Mejoras individuales solo afectan a Big Finger.

---

## Fase D — Más vehículos (backlog, priorizar tras validar A–C)

| Vehículo | Mecánica clave | Mapa ideal | Complejidad |
|----------|----------------|------------|-------------|
| **Motocross** | Ligera, volcaduras fáciles, gran control aéreo | Campo / Colinas | Media (2 ruedas, masa baja, air_torque alto) |
| **Tanque** | Orugas (sin ruedas), grip constante, no patina en hielo moderado | Ártico / Desierto | Alta (nuevo VehicleModule: tracks) |
| **Monociclo** | 1 rueda, equilibrio activo (PID) | Desafío / modo experto | Muy alta |
| **Lunar Rover** | Gravedad reducida (0.4×), suspensión larga, 4WD | Luna (mapa futuro) | Media (cambia gravity_scale) |

---

## Fase E — Más mapas (backlog)

| Mapa | Mecánica clave | Requiere superficie | Vehículo ideal |
|------|----------------|---------------------|----------------|
| **Desierto** | Arena (drag alto, grip bajo en subidas), dunas | `sand` (friction 0.55, drag 0.12) | Neumáticos anchos / Big Finger |
| **Montaña** | Pendientes extremas (>45°), acantilados, caída mortal | `rock` (friction 1.2, duro) | Motor + suspensión alta |
| **Luna** | Gravedad 0.4×, saltos largos, cráteres | `regolith` (friction 0.8, low gravity) | Lunar Rover |
| **Autopista** | Tramos planos + obstáculos (coches, rampas) | `asphalt` (friction 1.0, alto drag) | Velocidad pura / Motocross |

---

## Orden de implementación recomendado

```
A. Sistema de superficies     ← COMPLETA (base para todo)
B. Mapa Ártico                ← SIGUIENTE: valida superficies + lagos
C. Big Finger                 ← Tras B: valida ruedas deformables + 4 ruedas
D/E. Contenido adicional      ← Según feedback de juego y métricas
```

**Cronograma total estimado (core A–C):** ~20 días (3–4 semanas a tiempo parcial ~3–4h/día).

---

## Criterios de aceptación por hito

### Ártico (Fase B)

- [ ] Patinaje visible sin neumáticos de hielo (Jeep base no sube cuestas de hielo)
- [ ] Lagos aparecen en valles profundos, no en colinas (validar visual + colisión)
- [ ] Se puede completar una run de 2+ min con el vehículo correcto (Big Finger + cadenas o futuro tanque)
- [ ] Récord por mapa guardado en `map_best_distances` y visible en garaje

### Big Finger (Fase C)

- [ ] Neumáticos se deforman visualmente al comprimirse (escala Y del sprite)
- [ ] Grip escala con deformación de forma perceptible (subir cuesta blanda vs dura)
- [ ] Se siente distinto al Jeep en la misma colina (más estable, menos air control)
- [ ] Mejoras individuales solo afectan a Big Finger (no al Jeep)

---

## Riesgos

| Riesgo | Mitigación |
|--------|------------|
| Lag frozen lakes rompen colisión | Generar polígonos convexos por segmento; lagos como rectángulos simples |
| Big Finger inestable (física 4 ruedas) | Empezar con 4 ruedas raycast; masa y damping conservadores; angular_damp extra |
| Demasiados upgrades por vehículo | Máx. 3 por vehículo; costes escalados; `UpgradeDefs` centralizado |
| Scope creep | Un vehículo + un mapa por sprint; congelar features tras validar A–C |

---

## Próximo paso inmediato (HOY)

**Fase B1 — Lagos en Ártico:**

1. Añadir `_generate_lakes(surface_points)` en `TerrainGenerator` — detectar valles y crear segmentos `frozen_lake`
2. Crear `frozen_lake.tres` (SurfaceProfile: friction 0.10, lateral 0.2, drive 0.4, drag 0.05, particle_enum="ice", color cian)
3. Suavizado extra en `_smooth_surface_points` para bordes de lago (blend 80px)
4. Actualizar `GameParallax.apply_map()` para colores Ártico + lagos cian semitransparentes
5. Poner `arctic.tres available = true` y testear en garaje
6. **Test manual:** F5 → Garage → Desbloquear Ártico → Jugar → Verificar lagos + partículas hielo

---

## Referencias técnicas (session 2026-08-27)

- **wheel.gd** — Aplica 4 multiplicadores de `SurfaceProfile` (friction, lateral, drive, drag) + rastrea `_current_surface_type`
- **terrain_generator.gd** — `get_surface_at()` REAL + asignación procedural por ruido + suavizado 3-pasos + interpolación entre chunks
- **terrain_chunk.gd** — `surface_ids` array + `get_surface_id_at(local_x)`
- **vehicle_effects.gd** — GPUParticles2D por rueda según `particle_enum` (dust/ice/mud/sand) + landing dust
- **surface_profile.gd** — Resource con physics props + `particle_enum` enum
- **resources/content/surfaces/** — dirt.tres, ice.tres, mud.tres, sand.tres
- **references/surface-terrain-debugging.md** (skill godot-debugging) — Patrones de debug Fase A/A2
- **references/surface-terrain-system.md** (skill roadmap-authoring) — Arquitectura completa Fase A