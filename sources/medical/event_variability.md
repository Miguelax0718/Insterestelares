# Respuesta individual a los eventos del simulador

Este documento justifica el modelo `lib/features/simulation/domain/crew_event_response_model.dart`. Ese modelo decide cómo afecta cada evento manual del simulador (pérdida de sueño, tormenta solar, sobrecarga y fallo de ejercicio) a cada tripulante.

> [!IMPORTANT]
> Es un modelo **sintético para la demo**, no un pronóstico médico. Cada parámetro está marcado como **[Fuente]**, si sale de documentación publicada, o como **[Estimación]**, si es un valor elegido por el equipo de forma coherente con esa documentación.

## 1. Punto de partida: el modelo original del equipo

Los valores fijos del simulador original se conservan como **respuesta de referencia** de cada evento: una severidad 1,0 los reproduce. Lo nuevo es que cada tripulante recibe su propia fracción de esa referencia, o ninguna.

| Evento | Valores de referencia (modelo original) |
|---|---|
| Pérdida de sueño | Sueño 4,5 h (−3 h), cortisol 92 µg/día, melatonina 7 µg/día |
| Tormenta solar (SPE) | 180 µSv/h (+140), +1,5 mSv acumulados, 8-OHdG 11,2, isoprostanos 1,6 |
| Sobrecarga | FC 118 (+48), FR 26 (+11), SpO₂ 93 % (−6), agua −900 ml, volumen de orina 0,7 L |
| Fallo de ejercicio | NTx 64, CTx 530, meta de ejercicio incumplida |

## 2. Las cuatro etapas, por tripulante

1. **Exposición.** Mide cuánto le llega el evento a cada persona.
   - La tormenta solar llega a **toda la tripulación**, con la dosis escalada por el blindaje del módulo donde está cada uno. Los valores de referencia (180 µSv/h y +1,5 mSv) corresponden al módulo menos blindado (Cúpula); ver `crew_adaptation.md`, sección 4. **[Fuente]** NASA OCHMO-TB-020 y SRAG describen dosis mayores en zonas poco blindadas y que la tripulación se refugia en los módulos más blindados durante un SPE. **[Estimación]** Factores usados: Cúpula ×1,35, esclusa/EVA ×1,25, Columbus/Kibo ×1,0, Destiny ×0,9, Harmony/bahía médica ×0,8, con una variación de ±10 %.
   - Si los otros eventos se aplican a un solo tripulante, la exposición es de 0,85–1,15. **[Estimación]**
   - Si se aplican a toda la tripulación, no a todos les llega igual. **[Estimación]** Rangos: sueño 0,2–1,2, sobrecarga 0,4–1,15 y ejercicio 0,5–1,1.
2. **Susceptibilidad.** Combina un rasgo estable de la persona, sorteado una vez por misión con distribución log-normal (σ = 0,3) y **[Estimación]** en su magnitud, con su estado actual:
   - **[Fuente]** Van Dongen H.P.A. et al., 2004. *Systematic interindividual differences in neurobehavioral impairment from sleep loss: evidence of trait-like differential vulnerability.* Sleep 27(3):423–433. Muestra que la vulnerabilidad a la falta de sueño es un rasgo estable y distinto en cada persona.
   - Una deuda de sueño previa la aumenta un 15 % por cada hora por debajo de 7 h. **[Estimación]** El umbral de 7 h sale de Watson 2015 y Hirshkowitz 2015, que ya están en `links.md`.
   - En la sobrecarga influyen la edad (+2,5 % por año sobre 35), haber incumplido el ejercicio (×1,25) y dormir menos de 6 h (×1,2). **[Estimación]** Coherente con el desacondicionamiento cardiovascular (Meck 2001) y con la FC máxima según la edad (AHA).
3. **¿Se afecta o no?** La probabilidad es `p = 1 − e^(−1,1 · exposición · susceptibilidad)`. **[Estimación]** Con exposición y susceptibilidad de 1, p ≈ 67 %.
4. **Qué afección y cuánta.** La afección se elige con un sorteo ponderado según el perfil de la persona. La severidad es `exposición · susceptibilidad · U(0,7–1,2)`, limitada a 0,1–1,2. Si la severidad pasa de 0,8, hay un 60 % de probabilidad de que se afecte un segundo sistema. **[Estimación]**

| Evento | Afecciones posibles | Base |
|---|---|---|
| Pérdida de sueño | Cardiovascular (FC +6, PAS +8, PAD +5) **[Estimación]** · Estrés: cortisol y melatonina (valores del modelo original) · Metabólica: glucosa +14 mg/dL **[Estimación]** | **[Fuente]** Spiegel K., Leproult R., Van Cauter E., 1999. *Impact of sleep debt on metabolic and endocrine function.* Lancet 354:1435–1439: la deuda de sueño reduce la tolerancia a la glucosa y eleva el cortisol vespertino. |
| Tormenta solar | Estrés oxidativo (8-OHdG e isoprostanos). No hay síntomas agudos. | **[Fuente]** Graille 2020 (rango de 8-OHdG) y Smith & Zwart 2006 (8-OHdG +22 % tras vuelo), ya en `links.md`. A dosis de SPE de pocos mSv no aparecen síntomas agudos de radiación (NASA-STD-3001). |
| Sobrecarga | Siempre: esfuerzo cardiorrespiratorio (valores del modelo original, escalados). Además, posibles: térmica (+0,9 °C) · deshidratación (volumen de orina hacia 0,7 L, −400 ml de agua) · estrés (cortisol) | **[Fuente]** Stahn 2017: la temperatura central sube más rápido con el ejercicio en el espacio. Magnitudes: **[Estimación]**. |
| Fallo de ejercicio | Resorción ósea (NTx/CTx, con más peso a mayor edad) · Desacondicionamiento cardiovascular (FC en reposo +6, PAS −8) | **[Fuente]** Smith S.M. et al., 2012. *Benefits for bone from resistance exercise and nutrition in long-duration spaceflight.* J Bone Miner Res 27(9):1896–1906. También LeBlanc 2000 y Meck 2001. Magnitudes: **[Estimación]**. |

## 3. Evolución y contramedidas

Se asume que la tripulación aplica la contramedida desde el día siguiente al evento. Cada afección sigue esta curva: sube hasta un pico y luego decae exponencialmente con una vida media de `base / (recuperación individual · adherencia)`. La adherencia de cada persona se sortea entre 70 y 100 %. **[Estimación]**

| Afección | Contramedida | Vida media base (días) | Pico | Residuo |
|---|---|---|---|---|
| Déficit de sueño | Sueño de recuperación y horario ajustado | 1,0 | Día 0 | — |
| Dosis del SPE | Refugio en el módulo más blindado | 0,5 | Día 0 | Dosis acumulada permanente |
| Estrés oxidativo | Dieta antioxidante y principio ALARA | 3,0 | Día 1 | — |
| Cardiovascular (sueño) | Reposo y controles de presión | 1,0 | Día 0 | — |
| Estrés hormonal | Higiene de luz y relajación | 1,5 | Día 0 | — |
| Glucosa | Comidas regulares y controles | 2,0 | Día 0 | — |
| Esfuerzo, térmica, deshidratación | Reposo, enfriamiento, rehidratación | 0,5–0,7 | Día 0 | — |
| Resorción ósea | ARED de alta carga y nutrición (Ca y vitamina D) | 7,0 | Día 2 | 25 % persistente |
| Desacondicionamiento cardiovascular | CEVIS/T2 y carga de líquidos | 4,0 | Día 0 | — |

- **[Fuente]** Banks S. et al., 2010. *Neurobehavioral dynamics following chronic sleep restriction: dose-response effects of one night for recovery.* Sleep 33(8):1013–1026. Una noche de recuperación revierte el déficit solo en parte, lo que respalda una vida media de alrededor de 1 día.
- **[Fuente]** Smith 2012 y LeBlanc 2000: en vuelo, la pérdida ósea se mitiga pero no se revierte del todo, de ahí el residuo persistente. El porcentaje de residuo es una **[Estimación]**.
- Las vidas medias concretas son **[Estimación]**.

## 4. Reproducibilidad

Toda la aleatoriedad sale de un generador con semilla fija (`CrewEventResponseModel.defaultSeed`), combinada con el tripulante, el evento y el día. La misma demo da siempre el mismo resultado en web, escritorio y tests. El botón Reset restaura el estado nominal y conserva la semilla.
