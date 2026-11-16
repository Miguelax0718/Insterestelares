# Adaptación diaria de la tripulación sin eventos

Este documento justifica el modelo `lib/features/simulation/domain/crew_adaptation_model.dart`, que decide cómo cambia cada tripulante en cada día del simulador cuando no hay eventos.

> [!IMPORTANT]
> Es un modelo **sintético para la demo**, no un pronóstico médico. Cada parámetro está marcado como **[Fuente]** si sale de documentación publicada, o como **[Estimación]** si es un valor elegido por el equipo de forma coherente con esa documentación.

## 1. Por qué se reemplazó el avance diario original

El simulador original sumaba cada día los mismos valores a los 5 tripulantes, sin límite: FC +1,6 lpm, PAS +0,7 mmHg, sueño −0,12 h, tasa de dosis +4 µSv/h (todo multiplicado por el factor de la misión), y desde el día 12 nadie cumplía el ejercicio. Como todos parten de valores parecidos, en misión lunar los 5 cruzaban los umbrales críticos casi a la vez: la FC pasaba de 115 lpm entre los días 27 y 32, y la tasa de dosis pasaba de 160 µSv/h el día 32 para todos.

Eso contradice las mediciones en vuelo:
- **[Fuente]** Norsk P. et al., 2015 (J Physiol 593(3):573–584): en vuelos largos, la presión de 24 h baja 8/9 mmHg y la FC no cambia.
- **[Fuente]** Barger L.K. et al., 2014 (Lancet Neurol 13(9):904–912): en la ISS se duermen 6,09 ± 0,67 h por noche, no 3 h.
- **[Fuente]** NASA-STD-3001 Vol. 1 Rev. C (ver `radiation_dosimetry.md`): la tasa de GCR es aproximadamente constante para un entorno dado. Lo que crece cada día es la dosis acumulada, no la tasa.

## 2. Modelo nuevo, por tripulante

Cada valor es la línea de base del tripulante (capturada al pulsar Reset) más una adaptación acotada. Toda la aleatoriedad usa la misma semilla fija que el modelo de eventos, combinada con el tripulante y el día, así que la demo es reproducible.

| Variable | Comportamiento | Base |
|---|---|---|
| FC | Sin tendencia; variación diaria de ±1,5 lpm (1 DE) | **[Fuente]** Norsk 2015 (sin cambio de FC). Variación: **[Estimación]** |
| Presión | Baja 8/9 mmHg y se estabiliza (constante de 7 días); variación diaria de ±2/±1,5 mmHg | **[Fuente]** Norsk 2015. Constante de tiempo y variación: **[Estimación]** |
| Sueño | Converge al objetivo de cada persona, sorteado de 6,09 ± 0,67 h y limitado a 4,8–7,8 h (constante de 10 días); variación de ±0,25 h por noche | **[Fuente]** Barger 2014. Constante de tiempo, límites y variación: **[Estimación]** |
| Ejercicio | Cada persona falla una sesión de vez en cuando, con una probabilidad propia de 3–10 % por día | **[Fuente]** ~600 min/semana (450–720) en 46 astronautas, npj Microgravity 2023, lo que indica cumplimiento alto pero no perfecto. Probabilidades: **[Estimación]** |
| Tasa de dosis | Constante según el tipo de misión. Tránsito 54 µSv/h (1,3 mSv/día) y superficie 37,5 µSv/h (0,9 mSv/día) | **[Fuente]** Requisitos de diseño GCR de NASA-STD-3001. Órbita 24 µSv/h y Luna 40 µSv/h: **[Estimación]** |
| Dosis acumulada | Crece cada día según la tasa (tasa × 24 h) | Consecuencia directa de la tasa |
| Agua | Ingesta diaria del 85–105 % de la meta, en vez de bajar cada día | **[Estimación]** |

La frecuencia respiratoria, la SpO₂ y el llenado capilar ya no cambian solos. El modelo original los ligaba a la subida de la FC, y esa subida no ocurre.

## 3. Resultado

- Sin eventos, nadie llega a estado crítico en 180 días en ninguno de los cuatro tipos de misión (test `crew_adaptation_test.dart`).
- Los tripulantes no cambian de estado a la vez. Como en vuelo real (Barger 2014) la mayoría duerme menos de 7 h, que es el umbral de aviso de la app (Watson 2015), es normal que varios estén en aviso por sueño.
- Los casos graves salen de los eventos (`event_variability.md`), que ya afectan a cada tripulante de forma distinta.

## 4. Tormenta solar y blindaje

Los valores originales de la tormenta (180 µSv/h, es decir +140, y +1,5 mSv) se toman ahora como la lectura en el módulo **menos blindado** (Cúpula, factor 1,35). Los demás módulos reciben una parte proporcional a su factor. Con la tripulación nominal, la Cúpula y la esclusa quedan en crítico, y Destiny, Harmony y Columbus quedan en aviso.
- **[Fuente]** NASA OCHMO-TB-020 y SRAG: la dosis es mayor en zonas poco blindadas, y la tripulación se refugia en los módulos más blindados.
- Los factores por módulo son **[Estimación]**, como ya se indica en `event_variability.md`.
