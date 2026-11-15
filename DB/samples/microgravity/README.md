# Muestras de microgravedad (módulo `03_microgravity`)

Generadas con:

```
dart run lib/features/03_microgravity/data/generate_microgravity_sample.dart
```

Misión de 180 días, 5 astronautas (AST-01…AST-05). Mismo día 0 que las otras
muestras (2027-01-01).

| Archivo | Contenido |
|---|---|
| `bone_density_<escenario>.csv` | Densidad mineral ósea (DMO) por zona: columna lumbar, cuello femoral, trocánter, cadera total |
| `muscle_volume_<escenario>.csv` | Cambio de volumen muscular: pantorrilla, muslo, brazo |
| `exercise_sessions_<escenario>.csv` | Sesiones diarias de contramedidas (ARED, T2, CEVIS) |

`realistic` = `synthetic_from_real`; `extreme` = `synthetic_hypothetical`.

## Columnas clave

- `measurement_type`: `dxa` o `mri` (antes del vuelo, día −30, y al regresar,
  día 182) o `model_estimate` (cada 30 días en vuelo: no hay DXA ni RM a bordo).
- `change_from_baseline_pct`, `loss_rate_pct_per_month` (hueso) y
  `volume_change_pct` (músculo).
- Ejercicio: `device_name`, `duration_minutes`, `calories_burned` y
  `target_reached` siguen los campos de `ExerciseSession`.
- `event` (solo extremo): `ared_out_of_service`, `low_compliance`.

## De dónde sale cada valor

| Variable | Valor usado | Fuente |
|---|---|---|
| Pérdida ósea | Columna 0,8–1,2 %/mes; cadera 1,0–1,5 %/mes (uno por astronauta) | LeBlanc et al. 2000, cosmonautas de Mir (~1 %/mes en columna, 1–1,5 %/mes en cadera) |
| Volumen muscular a 6 meses | Pantorrilla −10 a −16 %, muslo −4 a −7 %, brazo sin cambio | Gopalakrishnan R., Genc K.O. et al. 2010, *Aviat Space Environ Med* 81(2):91–102, misiones de 6 meses en la ISS |
| Tiempo de ejercicio | ~100 min/día, 6 días por semana (~540 min/semana en la muestra) | npj Microgravity 2023 ([s41526-023-00256-5](https://www.nature.com/articles/s41526-023-00256-5)): ~600 min/semana (450–720) en 46 astronautas de la ISS |
| DMO de partida (g/cm²) | 1,10 columna, 0,95 cuello femoral, 0,80 trocánter, 1,02 cadera | Estimación (valores típicos de adulto sano) |
| Forma de la curva muscular | Más rápida al inicio (1 − e^(−t/60)) | Estimación |
| Calorías | MET × kg × horas (ARED 6, T2 8, CEVIS 7 MET); masa corporal del equipo | Estimación |

> [!NOTE]
> La cifra de LeBlanc 2000 se cita a través de resúmenes de la NASA; antes de la
> presentación conviene confirmar los valores por zona en el artículo original.

## Escenario extremo (hipotético)

- El ARED se avería el día 60 y no se repara: sin ejercicio de fuerza, la
  pérdida ósea va 1,8 veces más rápido y la muscular termina 1,6 veces mayor.
- AST-03 hace ~18 min menos por sesión (`low_compliance`).
