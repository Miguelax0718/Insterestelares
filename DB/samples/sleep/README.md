# Muestras de sueño (módulo `04_mental_health`)

Generadas con:

```
dart run lib/features/04_mental_health/data/generate_sleep_sample.dart
```

Una fila por noche y astronauta (AST-01…AST-05). Mismo día 0 que las otras
muestras (2027-01-01).

| Archivo | Contenido |
|---|---|
| `sleep_nightly_realistic.csv` | Horas de sueño según actigrafía real de astronautas (`synthetic_from_real`) |
| `sleep_nightly_extreme.csv` | La misma misión con insomnio y privación HIPOTÉTICOS (`synthetic_hypothetical`) |

## Columnas

- `interval`: periodo del estudio de referencia: `SL-90` (noches −97 a −84),
  `L-11` (−11 a −1), `inflight` (1–180) y `R+7` (182–188).
- `sleep_hours`, `wake_episodes` y `morning_mood` siguen los campos de
  `SleepRecord` (`great`, `good`, `neutral`, `fatigued`, `stressed`).
- `sleep_medication`: tomó medicación para dormir esa noche.
- `pre_eva_night`: la noche antes de una caminata espacial.
- `event` (solo extremo): `stress_insomnia`, `spe_shelter`, `pre_eva_restriction`.

## De dónde sale cada valor

Barger L.K. et al. 2014, *Lancet Neurology* 13:904–912
([PMC4188436](https://pmc.ncbi.nlm.nih.gov/articles/PMC4188436)). Actigrafía de
64 astronautas del shuttle y 21 de la ISS. Tabla 1, columna ISS, horas de sueño
por noche (media ± DE):

| Periodo | Horas |
|---|---|
| SL-90 (3 meses antes) | 6,41 ± 0,65 |
| L-11 (antes del lanzamiento) | 5,86 ± 0,94 |
| En vuelo | 6,09 ± 0,67 |
| R+7 (al regresar) | 6,95 ± 1,04 |

- **Medicación:** en la ISS se usó en el 11 % de las noches (96 de 852). Antes
  de una EVA, en el 60 % de las noches (dato del shuttle, la ISS no lo reporta).
- **Estimación del equipo:** `wake_episodes` (sube cuando se duerme menos) y
  `morning_mood` (regla por horas: ≥ 7 h `great`, ≥ 6,2 `good`, ≥ 5,5
  `neutral`, ≥ 4,5 `fatigued`, menos `stressed`). No hay datos públicos
  individuales de estas dos variables.

## Escenario extremo (hipotético)

- AST-02, noches 100–130: insomnio por estrés (~4,4 h).
- Toda la tripulación, noches 95–97: noches en el refugio por la tormenta
  solar (~3,6 h).
- AST-03, noches antes de cada EVA: ~3,9 h.
