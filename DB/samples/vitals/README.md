# Muestras de signos vitales (módulo `01_general_health`)

Generadas con:

```
dart run lib/features/01_general_health/data/generate_vitals_sample.dart
```

Misión de 180 días, 5 astronautas (AST-01…AST-05), una medición en reposo por
la mañana. Mismo día 0 que las muestras de biomarcadores (2027-01-01).

| Archivo | Contenido |
|---|---|
| `vitals_daily_realistic.csv` | Valores ajustados a lo publicado en astronautas (`synthetic_from_real`) |
| `vitals_daily_extreme.csv` | La misma misión con emergencias HIPOTÉTICAS para probar alertas (`synthetic_hypothetical`) |

Mediciones: días −92, −44 y −3 (antes del vuelo), diaria en vuelo (1–180),
día 181 (aterrizaje, R+0), 182 (R+1) y 187 (R+6).

## Columnas

`heart_rate_bpm`, `systolic_bp_mmhg`, `diastolic_bp_mmhg`, `spo2_pct`,
`body_temp_c`, `blood_glucose_mg_dl`, `respiratory_rate_rpm` y
`capillary_refill_s` siguen los campos de `VitalsRecord`.

- `activity_state`: `resting`, `post_landing`, `post_eva` o `emergency_triage`.
- `orthostatic_intolerance`: `true` si en el aterrizaje no tolera estar de pie.
- `event` (solo extremo): `post_eva_hypoxia`, `radiation_prodrome`,
  `febrile_infection`, `dehydration`, `hypertensive_crisis`.
- `glucose_origin`: `realInspiration4` (valor medido), `derivedInspiration4`
  (calculado con valores medidos), `simulated` o `hypothetical`.
- `reference_subject`: tripulante de Inspiration4 que se usó para la glucosa
  (C001…C004; AST-05 usa la media de los cuatro, `I4_mean`).

## De dónde sale cada valor

| Variable | Escenario realista | Fuente |
|---|---|---|
| Presión arterial | En vuelo baja 8 mmHg la sistólica y 9 la diastólica (se ajusta en ~2 semanas) | Norsk et al. 2015, *J Physiol* 593:573 (8 astronautas, ISS) |
| Frecuencia cardiaca | En reposo no cambia en vuelo | Norsk et al. 2015 |
| Temperatura | Sube ~1 °C de forma gradual en ~2,5 meses (temperatura **central**) | Stahn et al. 2017, *Sci Rep* 7:16180 |
| Intolerancia ortostática | 4 de 5 al aterrizar: FC +25 y sistólica −15 al ponerse de pie | Meck et al. 2001, *Psychosom Med* 63:865 (5 de 6 tras vuelos largos) |
| Glucosa | Antes del vuelo: valores **reales**. En R+1: media real × cambio real al regresar | NASA OSDR [OSD-575](https://osdr.nasa.gov/bio/repo/data/studies/OSD-575) (Inspiration4) |
| FC, presión y temperatura de partida | Valores del equipo, coherentes con `DB/Users` | Estimación |
| SpO₂ (98 ± 0,6 %), frecuencia respiratoria (14 ± 1,2), llenado capilar (1,4 s) | Rangos clínicos normales; la cabina de la ISS está a presión de nivel del mar | Estimación |

> [!IMPORTANT]
> En el escenario realista la temperatura llega a ~37,6 °C a mitad de misión.
> Es un dato real (Stahn 2017), no fiebre: el monitor no debería marcarlo en
> rojo solo por eso.

> [!NOTE]
> En Inspiration4, la glucosa en R+45 sale entre 36 y 44 mg/dL en tres
> tripulantes. Es probable que se deba al manejo de la muestra (no a
> hipoglucemia), así que no se usa.

## Escenario extremo (hipotético)

| Día | Astronauta | Evento |
|---|---|---|
| 60 | AST-03 | Hipoxia tras EVA: SpO₂ 89 %, FC 118, 92/58 mmHg, FR 26 |
| 95–96 | AST-01 | Pródromo por la tormenta solar: 38,6 °C, FC 104 |
| 120–121 | AST-05 | Crisis hipertensiva: ~168/104 mmHg, glucosa 182 |
| 140–141 | AST-02 | Infección con fiebre: 38,9 °C, FC 110 |
| 165 | AST-04 | Deshidratación: 88/56 mmHg, FC 112, llenado capilar 3,2 s |

Además, la temperatura central sube 1,3 °C en lugar de 1 °C. Ninguno de estos
valores sale de una medición real.
