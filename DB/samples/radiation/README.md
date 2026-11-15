# Muestra sintética de dosimetría

Estos archivos representan una misión ficticia de tránsito a Marte de 180 días y cuatro integrantes. No contienen mediciones reales ni deben usarse para decisiones médicas.

## Archivos

- `crew_profiles.json`: identificador ficticio, edad, sexo y dosis efectiva previa de carrera.
- `dosimetry_daily.csv`: una fila por astronauta y día; incluye dosis efectiva diaria en mSv, dosis por órgano en mGy-Eq/mGy y la contribución sintética del SPE.
- `space_weather.csv`: un resumen diario ficticio del flujo de protones; el SPE está en el día 95.

La simulación usa una semilla fija (`20261114`) y se genera con `dart run lib/features/02_radiation/data/generate_radiation_sample.dart`. Los perfiles usan `dataType=synthetic_demo`; las filas CSV usan `data_type=synthetic_demo` para conservar la etiqueta al importar los datos.

## Límites del escenario

- La dosis efectiva de tránsito se centra cerca de 1.65 mSv/día como escala ilustrativa tomada del escenario propuesto por el equipo. No representa una predicción de dosis para una nave concreta.
- Los campos de dosis por órgano son valores sintéticos independientes. No se derivan de la dosis efectiva y no modelan espectro de partículas ni blindaje de forma física.
- El día del SPE añade una dosis de escenario distinta según si el tripulante está en el refugio. Estos valores no equivalen al evento de diseño NASA ni son umbrales clínicos.
- El flujo de protones es una escala de demostración, no una telemetría calibrada en partículas/(cm²·s·sr).
- El modelo no incluye por separado la dosis del SNC de iones pesados Z≥10.

Las unidades de los campos por órgano siguen NASA-STD-3001 Vol. 1 Rev. C, tabla 4.8-1. La dosis efectiva de carrera y el SPE de referencia se documentan en `sources/medical/radiation_dosimetry.md`.

## Shared crew identity

Names and ages follow the global mock crew roster. Sex is unspecified; the global roster does not provide this field. The sample still covers only AST-01 through AST-04. AST-05 remains available in the biological demo but has no physical-dose records. Prior career-dose values and daily dose measurements are unchanged.
