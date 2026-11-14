# Muestras de biomarcadores para la demo

Generadas con:

```
dart run lib/features/02_radiation/data/generate_biomarker_sample.dart
```

Misión de 180 días con 4 astronautas (AST-01…AST-04). Cada uno usa como
referencia a un tripulante real de Inspiration4 (C001…C004). Ver
`DB/real/inspiration4/README.md` para las fuentes.

| Archivo | Contenido |
|---|---|
| `biomarker_baselines_<escenario>.json` | Línea base de cada astronauta (media de 3 visitas previas al vuelo) |
| `urine_samples_<escenario>.csv` | Orina: 3 previas, semanal en vuelo, días 96 y 98 (después del SPE) y día 181 (regreso) |
| `blood_samples_<escenario>.csv` | Sangre: 3 previas (valores **reales**), mensual en vuelo, días 96, 98 y 102, y día 181 |

Columnas útiles:
- `phase`: `preflight`, `inflight` o `postflight`.
- `origin` (sangre): `realInspiration4` es el valor medido; `derivedInspiration4`
  es la media real × el cambio real al regresar; `simulated` es un valor generado.
- `confounder` (orina): `intense_exercise` o `poor_sleep` suben el estrés
  oxidativo sin que intervenga la radiación.
- `data_type`: `synthetic_from_real` (realista) o `synthetic_hypothetical` (extremo).

Escenarios:
- **realistic**: tormenta solar el día 95 con dosis de EJEMPLO (50 mSv fuera del
  refugio, 10 mSv dentro). A estas dosis los biomarcadores casi no cambian; lo
  que se ve es la variación normal y los factores de confusión.
- **extreme**: la misma tormenta, pero HIPOTÉTICA de 1 Gy (0,25 Gy en el refugio)
  para mostrar cómo se vería una alerta roja.

Cuando la dosimetría de María esté lista, sus dosis reemplazan a las de ejemplo
(`exampleSpeDoseMsv` en el generador).
