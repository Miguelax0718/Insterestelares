# 🚀 APOLO / AstraMed: Concepto de Producto Final, Estado Real, Brechas y Diferenciadores UI/UX

**Iniciativa:** NASA Space Apps Challenge — *Interestelares*  
**Producto:** **APOLO** (*AstraMed / Space Health Engine*) — Flutter 100% *Offline-First* + Asistente Clínico Autónomo por Voz  
**Última actualización de auditoría:** Integración completa en `main` (preservando la arquitectura y UI/UX base de `ApoloHomeScreen` + `AstraMedDashboard`), con `flutter analyze` (0 errores/warnings) y `flutter test` (+333 pasando, 3 skip externos por CSV gitignored).

---

## 🎯 1. Concepto de Resultado Final (North Star del Producto)

### Definición Central del Producto (Concepto Oficial del Equipo)
> *"software de monitoreo de salud de astronautas centralizada en un asistente interactivo que guia a los tripulantes en los procesos. y los ayuda en los momentos  criticos con los temas de salud. permite acceder y analizar el historial de los signos vitales, diagnosticar y prevenir enfermedades, tambien ayuda o dice como tomar manualmente la medida de los signos vitales y brinda conocimientos medicos para resolver situaciones de salud general y tambien respecto a radiaciones y SAS y SMS"*

### Versión Editorial Pulida (Para Pitch y Ficha Oficial NASA Space Apps)
> **APOLO (AstraMed)** es un software *Offline-First* de monitoreo integral de salud para astronautas en misiones espaciales de larga duración, **centralizado en un asistente clínico interactivo por voz y pantalla (mascota astronauta APOLO + orbes dinámicos)** que guía a los tripulantes en cada proceso y los asiste en momentos críticos. Permite consultar y analizar el historial de signos vitales y biomarcadores, diagnosticar y prevenir enfermedades mediante telemetría pasiva en 4 dimensiones, enseñar y asistir la toma manual de signos vitales sin sensores, y entregar conocimiento médico accionable para salud general, **radiaciones espaciales**, **Síndrome de Adaptación Espacial (SAS)** y **Mareo Espacial (SMS)**.

### Los 6 Pilares del Concepto Final
1. **Asistente Interactivo Centralizado (APOLO):** Mascota astronauta interactiva con voz manos libres y orbes flotantes bajo demanda que centraliza toda la experiencia sin saturar cognitivamente al tripulante.
2. **Soporte en Momentos Críticos:** Detección proactiva de riesgos, semaforización clínica (Verde/Amarillo/Rojo), confirmación humana en acciones de riesgo y guías paso a paso en emergencias.
3. **Acceso y Análisis del Historial de Signos Vitales:** Consulta temporal de signos vitales y biomarcadores, comparación contra línea base individual y detección de tendencias.
4. **Diagnóstico y Prevención de Enfermedades:** Correlación multi-sistema en 4 dimensiones continuas, análisis de 23 biomarcadores urinarios y triage determinista híbrido (*ADA + APOLO*).
5. **Guía para Medición Manual de Signos Vitales:** Instrucciones anatómicas claras, temporizadores/metrónomos táctiles y registro guiado cuando fallan los biosensores.
6. **Conocimiento Médico Espacial Offline:** Protocolos accionables sobre salud general, **radiaciones** (ARS, tormentas solares SPE, astrofarmacia), **SAS** (*Space Adaptation Syndrome*) y **SMS** (*Space Motion Sickness*).

---

## ✅ 2. Qué Ya Construyó el Equipo (Auditoría Real Actualizada en `main`)

El proyecto consolidó los avances principales directamente sobre `main`, preservando intacta la arquitectura y UI/UX base (`ApoloHomeScreen` + `AstraMedDashboard` + `ApoloTheme` / `SpaceTheme`):

### 2.1 Núcleo APOLO, Telemetría Científica, Radiación y Voz (Base + PRs `#9`, `#10` y `#11`)
* **Identidad APOLO + Motor de 23 Biomarcadores Urinarios (`lib/features/apolo/` y `web/apolo/`):**
  * Asistente **APOLO** (perrito astronauta) como `home` nativo en Flutter (`ApoloHomeScreen`, `ApoloDogWidget`, `ApoloOrbWidget`, `ApoloChatOrbs`, `ApoloDetailSheet`) con orbes flotantes y flujo offline (`QueryAwareDeterministicFlow`), junto a su motor determinista en Dart de **23 biomarcadores en orina** y **8 círculos de salud** (`hidratacion`, `renal`, `osea`, `radiacion`, `inmunidad`, `cardio`, `estres`, `metabolismo`), historial sembrado de **40 muestras por tripulante**, registro de agua/ejercicio y **`ApoloUrineSkill`**.
* **Telemetría Pasiva en 4 Dimensiones + Criterios Científicos NASA + Triage Híbrido (PR `#11`):**
  * `ScientificCriteriaEngine` (`lib/features/01_general_health/domain/scientific_criteria_engine.dart` + `DB/scientific_criteria.json` y `DB/references.md`) y `scientificTelemetryAgentSkills()`, evaluando continuamente dimensiones cardiorrespiratoria/metabólica (ajuste 0g de `+3.44 bpm`, VFC `RMSSD`/`SDNN`, FR, $SpO_2$, temperatura central por flujo térmico, hidratación BIS), neurológica/sensorial (`NPi`/`PLR`, ToF SANS, PVT-B), musculoesquelética (IMU/BIS) y circadiana/psicoemocional, cruzadas por `ApolloTriageEngine` y `HybridLlmTriageService` 100% offline.
* **Puente de Radiación y Biomarcadores con el Agente (PR `#9`):**
  * `radiationHealthSkill` (`lib/features/02_radiation/agent/radiation_health_skills.dart`) expone dosis acumulada (contra el límite NASA-STD-3001 de 600 mSv y % de límite por órgano), biomarcadores y síntomas de radiación con resumen determinista offline, escalamiento al *Flight Surgeon*, DONKI y astrofarmacia/Raman.
* **Núcleo Conversacional y Voz Manos Libres (`lib/features/agent/` + `server/`):**
  * STT (`faster-whisper` + fallback local), TTS natural (`Kokoro-82M` + `flutter_tts`), modo *Hands-Free* con detección de actividad de voz (VAD), memoria persistente en Hive (`agent_memory`), bitácora inmutable (`agent_audit`), `ConfirmationGate` y `ProactiveMonitor`.

### 2.2 Integraciones Recientes Aterrizadas en `main` (Sin Romper la UI/UX Base)
* **Corrección de `show_component` + Navegación Clínica Directa desde APOLO (`core_tools.dart`, `agent_providers.dart`, `apolo_home_screen.dart`):**
  * `_ShowComponentTool.call` ejecuta `_hydrateComponentProps` para hidratar automáticamente `crew_status`, `vitals_card`, `telemetry_chart` y `alert_banner` desde el estado en Riverpod cuando el LLM envía `props` vacíos o parciales, eliminando el error `crew_status requires a "crew" list`.
  * Nueva skill `clinical_navigation_and_procedures` (`lib/features/05_clinical_triage/agent/clinical_navigation_and_procedures_skill.dart`) con `open_clinical_terminal` (navegación directa a `AstraMedDashboard` desde comandos como *"abre la terminal"*), `search_medical_procedures` y `get_manual_vitals_guide`, más flujo determinista offline ES/EN.
* **Suites Clínicas de SAS/SMS y SANS con Cámara HUD e IMU + `HiveBootstrap` (`lib/features/03_microgravity/`, `lib/core/calibration/`, `lib/core/sensing/`, `lib/core/storage/hive_bootstrap.dart`):**
  * Cámara frontal en vivo (`ClinicalCameraHud` con `camera`), giroscopio/acelerómetro (`sensors_plus`) y calibración óptica; **Suite SMS** (`sms_suite_page.dart`: escáner facial $\Delta(G/R)$, prueba VOR/DVA a 1 Hz, minijuego 3D *Zero-G Horizon* y asesor EVA Graybiel con alerta *NO-GO EVA* cuando Graybiel $\ge 5$); **Suite SANS** (`sans_suite_page.dart`: tele-medidor IPD/dioptrías $\Delta D$, *Starfield Distortion Hunter* y máquina LBNP a $-20\text{ mmHg}$) e inicialización Hive unificada.
* **Catálogo Médico Offline + Triage Interactivo (`lib/features/05_clinical_triage/`, `DB/Information/`):**
  * Integrados los 4 JSON clínicos (`medical_procedures_catalog.json` con 10 protocolos, `clinical_situations_triage.json`, `medical_kit_inventory.json`, `medical_procedures_schema.json`) en `medical_procedures_data.dart` y `TriageView` (selector de situación + detalle paso a paso offline, preservando *"Autodiagnóstico Guiado por Síntomas"*).
* **Toma Manual Interactiva (*Tap-to-Count* + Cronómetros) y Tendencias `fl_chart` (`lib/features/01_general_health/presentation/general_health_view.dart`):**
  * Gráfica histórica `fl_chart` (`LineChart` para pulso, $SpO_2$, PA sistólica y temperatura frente a línea base y umbrales NASA) y diálogo manual interactivo con contador *Tap-to-Count* (15s $\times 4$ pulso, 30s $\times 2$ respiración) y cronómetro de llenado capilar.

---

## 🚧 3. ¿Qué Nos Falta Ahora (Solo Pulido Final y Opcionales de Pitch)?

Con todas las integraciones funcionales aterrizadas y verificadas en `main`, la brecha crítica está cerrada. Solo quedan **4 puntos de cierre y diferenciación**:

1. **Pulido Visual de Placeholders del Agente y Unificación de Idioma (Español / Inglés):**
   * Reemplazar los `_PlaceholderComponentCard` restantes en `lib/features/agent/presentation/component_widget_registry.dart` por tarjetas con la estética espacial de APOLO (`apolo_theme.dart`) y alinear el idioma de voz/prompts (`server/` actualmente en inglés `en`) con la UI en español (o modo bilingüe consistente para el pitch).
2. **Accesos Rápidos de 1 Clic desde Orbes a Pruebas Cámara/IMU (Opcional UX):**
   * Además de abrir la terminal por comando (`open_clinical_terminal`), exponer accesos directos visuales desde los orbes hacia la cámara SMS/SANS y al diálogo *Tap-to-Count* sin pasar por la pestaña secundaria.
3. **Diferenciadores Opcionales de Alto Impacto (Pitch NASA Space Apps):**
   * Portar a Flutter la silueta anatómica cliqueable (*HUD Body Map*), añadir modo automático *"SAS & SANS Safe UI"*, modo *"Buddy System" & RCP en microgravedad* o una barra demo *"Mission Control Simulation"* de 1 clic.
4. **Validación Final en Dispositivo Físico Sin Conexión y Video Pitch:**
   * Probar end-to-end en hardware real sin internet (cámara frontal, giroscopio/acelerómetro, micrófono/TTS e historial Hive) y grabar el video demo de 2 minutos.

---

## 🌟 4. Factores Diferenciadores ("Wow Factors") para Destacar el Proyecto

* **Ya construidos (Potenciarlos en el Pitch):**
  1. **Interfaz Centralizada "APOLO + Orbes Bajo Demanda":** Mascota astronauta reactiva al estado clínico que evita la saturación cognitiva; solo despliega círculos de salud o respuestas cuando están en alerta o cuando el tripulante los pide, además de abrir directamente la terminal clínica con comandos por voz/texto (`open_clinical_terminal`).
  2. **Telemetría Pasiva en 4 Dimensiones + 23 Biomarcadores Urinarios + Tendencias `fl_chart`:** Cruza fisiología continua (ajustada a microgravedad, ej. `+3.44 bpm`), pupilometría IR, bioimpedancia y análisis urinario en una sola evaluación preventiva, con gráficas temporales interactivas de signos vitales generales.
  3. **Visión por Computador Real (`ClinicalCameraHud`) e IMU para SAS/SMS y SANS:** Escaneo facial de palidez $\Delta(G/R)$, test VOR con metrónomo de 1 Hz, estimación trigonométrica de dioptrías por IPD, minijuego vestibular 3D *Zero-G Horizon* y *Starfield Distortion Hunter*.
  4. **Cadena Clínica Integrada Clima Espacial $\rightarrow$ Astrofarmacia $\rightarrow$ Vía Farmacocinética SMS + Catálogo Médico:** Conecta tormentas solares (DONKI) con degradación de fármacos y verificación Raman, cambia vía oral a intranasal/parenteral cuando Graybiel indica gastroparesia y consulta 10 protocolos offline vía `search_medical_procedures`.
  5. **Medición Manual *Tap-to-Count* + Cronómetros Guiados (`get_manual_vitals_guide`):** Elimina errores aritméticos al contar pulso (15s $\times 4$), respiración (30s $\times 2$) y llenado capilar cuando fallan los sensores.
* **Diferenciadores Adicionales Recomendados (Opcionales):**
  6. **Modo "Buddy System" & RCP en Microgravedad:** Guía por voz en segunda persona para atender a un compañero inconsciente, con metrónomo auditivo de compresiones adaptado a gravedad cero.

---

## 🎨 5. Mejoras Opcionales de UI/UX de Alto Impacto

| Propuesta UI/UX (Opcional) | Descripción | Impacto en NASA Space Apps |
| :--- | :--- | :--- |
| **1. Widget "Tap-Rhythm & Metrónomo" en Orbe Nativo APOLO** | Llevar el contador *Tap-to-Count* y cronómetro de llenado capilar (ya disponibles en `GeneralHealthView`) también a un orbe flotante en `ApoloHomeScreen`. | Cierra con excelencia el requisito de medir signos vitales sin salir de la vista principal de APOLO. |
| **2. Portar el Gemelo Digital Anatómico (HUD Body Map) a Flutter** | Llevar a Flutter la silueta anatómica cliqueable ya prototipada en la web, vinculando cada órgano/sistema con los 8 orbes de APOLO y las pruebas SMS/SANS/Radiación. | Cumple la recomendación textual del reto NASA con altísimo atractivo visual. |
| **3. Modo Automático "SAS & SANS Safe UI"** | Switch (o disparo automático cuando Graybiel $\ge 5$ o SANS positivo) que detiene flotación de orbes/cometas, agranda fuente/contraste y prioriza voz 100%. | Demuestra empatía clínica real frente a vértigo vestibular y edema ocular en vuelo espacial. |
| **4. Unificar Estética APOLO en las Vistas Clásicas y Placeholders** | Aplicar la paleta `#0B0C1E` / `#1E2050` / `#F0FFF1` de `apolo_theme.dart` al resto de componentes inyectados del agente y microanimaciones Lottie de procedimientos. | Evita saltos visuales entre APOLO y las tarjetas clínicas heredadas. |
| **5. Barra Demo "Mission Control Simulation" (1 Clic)** | Selector oculto/discreto para inyectar en vivo durante el pitch: (a) Tormenta solar SPE, (b) Crisis SAS/SMS Pre-EVA, (c) Falla de sensores + Toma manual guiada. | Asegura un video pitch de 2 minutos fluido, dramático y sin fallos en vivo. |

---

## 🗺️ 6. Hoja de Ruta de Cierre Final (Post-Integración en `main`)

1. **✅ Completado en `main`:** Integración funcional de catálogo médico (`05_clinical_triage`), suites cámara/IMU SMS & SANS (`03_microgravity`), historial `fl_chart` + contadores *Tap-to-Count* (`01_general_health`), hidratación defensiva de `show_component` y skill `clinical_navigation_and_procedures` (`open_clinical_terminal`, `search_medical_procedures`, `get_manual_vitals_guide`).
2. **Pulido Visual e Idioma:** Unificar el estilo de `_PlaceholderComponentCard` con `ApoloTheme` y alinear idioma ES/EN en prompts de voz.
3. **Opcional UX de Alto Impacto:** Añadir acceso de 1 clic desde orbes hacia cámara SMS/SANS, modo automático *SAS/SANS Safe UI* o barra *"Mission Control Simulation"* para el pitch.
4. **Pruebas Finales en Dispositivo Offline:** Validación end-to-end en dispositivo físico sin internet (cámara + giroscopio + voz + Hive) y grabación del video demo de 2 minutos.
