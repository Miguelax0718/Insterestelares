# 🚀 APOLO / AstraMed: Concepto de Producto Final, Estado Real, Brechas y Diferenciadores UI/UX

**Iniciativa:** NASA Space Apps Challenge — *Interestelares*  
**Producto:** **APOLO** (*AstraMed / Space Health Engine*) — Flutter 100% *Offline-First* + Asistente Clínico Autónomo por Voz  
**Última actualización de auditoría:** Revisión posterior a los merges en `main` (PRs `#9`, `#10`, `#11`) y ramas activas pendientes de integración (`origin/feat/apolo-chat-orbs`, `origin/feat/microgravity-sms-sans`, `origin/General-Telemetry-System-Miguel`).

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

## ✅ 2. Qué Ya Construyó el Equipo (Auditoría Real Actualizada)

El proyecto dio un salto enorme desde la primera revisión. Hoy contamos con avances sólidos tanto ya integrados en `main` como listos en ramas remotas pendientes de *merge*:

### 2.1 Ya integrado en `main` (PRs `#9`, `#10` y `#11`)
* **Identidad APOLO + Motor de 23 Biomarcadores Urinarios (`lib/features/apolo/` y `web/apolo/`):**
  * Rediseño completo hacia **APOLO** (perrito astronauta asistente) con interfaz web empaquetada en `web/apolo/`.
  * Port determinista en Dart (`apolo_biomarker_engine.dart`, `apolo_repository.dart`) de **23 biomarcadores en orina** y **8 círculos de salud** (`hidratacion`, `renal`, `osea`, `radiacion`, `inmunidad`, `cardio`, `estres`, `metabolismo`), con historial sembrado de **40 muestras por tripulante**, registro de agua/ejercicio y **`ApoloUrineSkill`** conectada al `SkillRegistry` con flujo offline.
* **Telemetría Pasiva en 4 Dimensiones + Criterios Científicos NASA + Triage Híbrido ADA+APOLO (PR `#11`):**
  * `ScientificCriteriaEngine` (`lib/features/01_general_health/domain/scientific_criteria_engine.dart` + `DB/scientific_criteria.json` y `DB/references.md`) y `scientificTelemetryAgentSkills()` registrados en el agente, evaluando continuamente:
    1. **Cardiorrespiratoria/Metabólica:** FC (con ajuste 0g de `+3.44 bpm`), VFC (`RMSSD`/`SDNN`), FR, $SpO_2$, temperatura central por flujo térmico (*Draeger*) e hidratación BIS corregida.
    2. **Neurológica/Sensorial:** pupilometría IR (`NPi`/`PLR`), desplazamiento hipermetrópico ToF para SANS y PVT-B pasivo.
    3. **Musculoesquelética:** impacto/cadencia IMU y atrofia muscular BIS en cuádriceps/gastrocnemio.
    4. **Circadiana/Psicoemocional:** actigrafía de sueño, VFC nocturna y eventos de desaturación.
  * `ApolloTriageEngine` y `HybridLlmTriageService`: cruzan síntomas con las 4 dimensiones pasivas y gases de cabina ($CO_2$/$O_2$), operando 100% offline con respaldo híbrido (determinista + LLM local/Web/Ollama + cloud).
* **Puente de Radiación y Biomarcadores con el Agente (PR `#9`):**
  * `radiationHealthSkill` (`lib/features/02_radiation/agent/radiation_health_skills.dart`) conecta al agente con los mismos datos que ve la pantalla de Radiación (`get_radiation_dose` contra el límite NASA-STD-3001 de 600 mSv y % de límite por órgano, `get_radiation_biomarkers`, `get_radiation_symptoms`) con resumen determinista offline que nombra síntomas urgentes y escala al *Flight Surgeon*, además de DONKI y astrofarmacia/Raman.
* **Núcleo de Agente por Voz Manos Libres (`lib/features/agent/` + `server/`):**
  * STT (`faster-whisper` + fallback local), TTS natural (`Kokoro-82M` + `flutter_tts`), modo *Hands-Free* con detección de actividad de voz (VAD), memoria persistente en Hive (`agent_memory`), bitácora inmutable (`agent_audit`), `ConfirmationGate` y `ProactiveMonitor` con alertas coalescentes.

### 2.2 Ya construido en ramas remotas listas para integrar (*merge*) a `main`
* **`origin/feat/apolo-chat-orbs` — Home Screen Nativo de APOLO en Flutter + Orbes de Respuesta:**
  * Implementa `ApoloHomeScreen`, `ApoloDogWidget`, `ApoloOrbWidget`, `ApoloChatOrbs` y `ApoloDetailSheet` en Flutter y convierte a **APOLO en la pantalla principal (`home`)** (manteniendo el acceso al dashboard clásico desde el menú superior).
  * Las respuestas del chatbot y los componentes clínicos inyectados por herramientas aparecen como **círculos/orbes flotantes** alrededor de Apolo; incorpora `QueryAwareDeterministicFlow` para que la primera consulta sin internet (ej. registro de agua) se ejecute de inmediato.
* **`origin/feat/microgravity-sms-sans` — Suites Clínicas de SAS/SMS y SANS con Cámara en Vivo (HUD) e IMU:**
  * Integra `ClinicalCameraHud` (`lib/core/sensing/presentation/clinical_camera_hud.dart`) con cámara frontal en vivo (`camera`), giroscopio/acelerómetro (`sensors_plus`) y calibración óptica (`lib/core/calibration/`).
  * **Suite SMS (`sms_suite_page.dart`):** Escáner de cromaticidad verde facial $\Delta(G/R)$ de 15s contra tarjeta blanca de referencia, prueba VOR/DVA con metrónomo a 1 Hz, minijuego 3D de acoplamiento *"Zero-G Horizon"* de 45s y asesor EVA con escala de Graybiel (alerta *NO-GO EVA* cuando Graybiel $\ge 5$).
  * **Suite SANS (`sans_suite_page.dart`):** Tele-medidor de distancia de enfoque cercano por IPD y cálculo de desplazamiento hipermetrópico ($\Delta D$) para asignar gafas, *"Starfield Distortion Hunter"* (metamorfopsia + mapa de escotomas con fijación) y máquina de estados para **LBNP a $-20\text{ mmHg}$** con descompresión gradual obligatoria.
* **`origin/General-Telemetry-System-Miguel` — Catálogo de Procedimientos Médicos y Triage Interactivo:**
  * Agrega `DB/Information/medical_procedures_catalog.json` (762 líneas), `clinical_situations_triage.json` y `medical_kit_inventory.json`, conectados en `medical_procedures_data.dart` y `TriageView` interactivo con selector de situaciones clínicas y pasos detallados offline.

---

## 🚧 3. ¿Qué Nos Falta REALMENTE Ahora para Lograr el Concepto Final?

Con todo lo anterior avanzado, la brecha se redujo drásticamente. Estas son las **5 cosas concretas que faltan**:

1. **Integrar (*Merge*) las 3 Ramas Activas hacia `main`:**
   * Fusionar `origin/feat/apolo-chat-orbs` (para tener la Home Screen de APOLO con mascota y orbes en Flutter en `main`), `origin/feat/microgravity-sms-sans` (para traer las suites SMS/SANS con cámara HUD e IMU) y `origin/General-Telemetry-System-Miguel` (para traer el catálogo médico y `TriageView` interactivo), resolviendo los puntos de encuentro en `lib/main.dart`, `pubspec.yaml`, `medical_thresholds.dart` y `test/widget_test.dart`.
2. **Skill y Componente Interactivo de Toma Manual de Signos Vitales (`manual_vitals_guide`):**
   * Hoy `GeneralHealthView` tiene un diálogo manual básico en texto, pero el asistente **APOLO todavía no tiene una skill ni un componente interactivo dedicado** para enseñar y guiar por voz cómo medir manualmente pulso, respiración, llenado capilar y presión arterial cuando fallan los sensores.
   * Falta añadir en APOLO un **cronómetro visual/auditivo (15s/30s) y botón "Tap-to-Count"** (tocar en pantalla con cada latido o respiración para calcular BPM/RPM automáticamente sin cálculos mentales bajo estrés), además de temporizador de 5s + 2s para llenado capilar.
3. **Gráficas Temporales (`fl_chart`) de Historial de Signos Vitales en `GeneralHealthView` y `telemetry_chart`:**
   * Ya existen gráficas de tendencia para orina (en `ApoloDetailSheet` de la rama APOLO) y para radiación (`RadiationView`), pero en `GeneralHealthView` y en el componente `telemetry_chart` del agente los signos vitales generales (FC, PA, $SpO_2$, FR, Temp, VFC) aún no muestran gráficas `fl_chart` con historial acumulado, bandas de umbral NASA y análisis de desviación frente a línea base.
4. **Conectar el Catálogo de Procedimientos (`medical_procedures_catalog.json`) y las Suites Cámara/IMU con Tools de APOLO:**
   * Crear una tool en APOLO para buscar, resumir por voz y proyectar cualquier protocolo de `medical_procedures_catalog.json` (salud general, radiación, SAS, SMS) y permitir lanzar desde un orbe de APOLO las pruebas reales con cámara de `sms_suite_page.dart` y `sans_suite_page.dart`.
5. **Pulido Visual de Placeholders del Agente y Unificación de Idioma (Español / Inglés):**
   * Reemplazar los `_PlaceholderComponentCard` restantes en `lib/features/agent/presentation/component_widget_registry.dart` por tarjetas con la estética espacial de APOLO (`apolo_theme.dart`) y alinear el idioma de voz/prompts (`server/` actualmente en inglés `en`) con la UI en español (o modo bilingüe consistente para el pitch).

---

## 🌟 4. Factores Diferenciadores ("Wow Factors") para Destacar el Proyecto

* **Ya construidos (Potenciarlos en el Pitch):**
  1. **Interfaz Centralizada "APOLO + Orbes Bajo Demanda":** Mascota astronauta reactiva al estado clínico que evita la saturación cognitiva; solo despliega círculos de salud o respuestas cuando están en alerta o cuando el tripulante los pide.
  2. **Telemetría Pasiva en 4 Dimensiones + 23 Biomarcadores Urinarios:** Cruza fisiología continua (ajustada a microgravedad, ej. `+3.44 bpm`), pupilometría IR, bioimpedancia y análisis urinario en una sola evaluación preventiva.
  3. **Visión por Computador Real (`ClinicalCameraHud`) e IMU para SAS/SMS y SANS:** Escaneo facial de palidez $\Delta(G/R)$, test VOR con metrónomo de 1 Hz, estimación trigonométrica de dioptrías por IPD, minijuego vestibular 3D *Zero-G Horizon* y *Starfield Distortion Hunter*.
  4. **Cadena Clínica Integrada Clima Espacial $\rightarrow$ Astrofarmacia $\rightarrow$ Vía Farmacocinética SMS:** Conecta tormentas solares (DONKI) con degradación de fármacos y verificación Raman, y cambia vía oral a intranasal/parenteral cuando Graybiel indica gastroparesia por mareo espacial.
* **Diferenciadores Adicionales Recomendados (Faltan por Agregar):**
  5. **Toma Manual "Tap-Rhythm" + Cronómetro Guiado:** Elimina errores humanos al contar pulso/respiración cuando no hay sensores.
  6. **Modo "Buddy System" & RCP en Microgravedad:** Guía por voz en segunda persona para atender a un compañero inconsciente, con metrónomo auditivo de compresiones adaptado a gravedad cero.

---

## 🎨 5. Mejoras Opcionales de UI/UX de Alto Impacto

| Propuesta UI/UX (Opcional) | Descripción | Impacto en NASA Space Apps |
| :--- | :--- | :--- |
| **1. Widget "Tap-Rhythm & Metrónomo" dentro de APOLO** | Orbe interactivo para medición manual de pulso/respiración por toques en pantalla y guía cronometrada de llenado capilar (5s+2s). | Cierra con excelencia el requisito de ayudar a medir manualmente signos vitales sin ser médico. |
| **2. Portar el Gemelo Digital Anatómico (HUD Body Map) a Flutter** | Llevar a Flutter la silueta anatómica cliqueable ya prototipada en la web, vinculando cada órgano/sistema con los 8 orbes de APOLO y las pruebas SMS/SANS/Radiación. | Cumple la recomendación textual del reto NASA con altísimo atractivo visual. |
| **3. Modo Automático "SAS & SANS Safe UI"** | Switch (o disparo automático cuando Graybiel $\ge 5$ o SANS positivo) que detiene flotación de orbes/cometas, agranda fuente/contraste y prioriza voz 100%. | Demuestra empatía clínica real frente a vértigo vestibular y edema ocular en vuelo espacial. |
| **4. Unificar Estética APOLO en las Vistas Clásicas y Placeholders** | Aplicar la paleta `#0B0C1E` / `#1E2050` / `#F0FFF1` de `apolo_theme.dart` al resto de componentes inyectados del agente y microanimaciones Lottie de procedimientos. | Evita saltos visuales entre APOLO y las tarjetas clínicas heredadas. |
| **5. Barra Demo "Mission Control Simulation" (1 Clic)** | Selector oculto/discreto para inyectar en vivo durante el pitch: (a) Tormenta solar SPE, (b) Crisis SAS/SMS Pre-EVA, (c) Falla de sensores + Toma manual guiada. | Asegura un video pitch de 2 minutos fluido, dramático y sin fallos en vivo. |

---

## 🗺️ 6. Hoja de Ruta Inmediata (Orden de Cierre)

1. **Paso 1 — Merge de Ramas en `main`:** Integrar `feat/apolo-chat-orbs`, `feat/microgravity-sms-sans` y `General-Telemetry-System-Miguel` y verificar `flutter test` + `flutter analyze`.
2. **Paso 2 — Toma Manual Guiada + Historial `fl_chart`:** Implementar la skill/orbe `manual_vitals_guide` con cronómetro y *Tap-to-Count*, más las curvas temporales `fl_chart` de signos vitales generales.
3. **Paso 3 — Conectar Procedimientos y Suites con APOLO:** Exponer `medical_procedures_catalog.json` y los lanzadores de cámara SMS/SANS como herramientas invocables desde los orbes de APOLO.
4. **Paso 4 — Pulido UI/UX, Idioma y Demo del Pitch:** Unificar idioma de voz/UI, sustituir placeholders visuales pendientes, añadir modo *SAS/SANS Safe UI* y probar de extremo a extremo 100% offline.
