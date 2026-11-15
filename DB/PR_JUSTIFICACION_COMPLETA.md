# Pull Request: Sistema Contextual de Signos Vitales, Telemetría Médica, Guía Gamificada y Triaje Híbrido (ADA + IA Local/Cloud)

## 1. Resumen Ejecutivo
Este Pull Request evoluciona la plataforma **AstraMed / Insterestelares** en cuatro pilares técnicos y científicos:
1. **Motor de Criterios Científicos Contextuales (`ScientificCriteriaEngine`):** Sustituye umbrales rígidos y etiquetas diagnósticas arbitrarias por evaluación contextualizada (Sueño, Reposo, Actividad Física, Desconocido) y trazable a literatura verificable.
2. **Integración de Telemetría y Pantallas Completas Gamificadas (`GeneralHealthView` + `VitalDetailFullScreenView`):** Vista general limpia con recepción automática de sensores y fallback manual instantáneo, más vistas detalladas por indicador con comparativa por contexto, evolución temporal e instrucciones simples para el astronauta.
3. **Triaje Clínico Híbrido ADA + Chatbot (`ApolloTriageEngine` + `HybridLlmTriageService`):** Combina un árbol determinista tipo ADA como *guardrail* clínico con un modelo conversacional **Local-First (WebLLM/Ollama)**, **respaldo en la nube (Gemini/OpenAI)** cuando hay conectividad, y **operación 100% offline** para misiones en el espacio profundo.
4. **Optimización de Carga/Recarga (`CrewDatabaseService` + Scripts Web):** Caché en memoria y lectura paralela de perfiles JSON en `DB/Users/`, además de `--no-pub` en lanzadores de desarrollo.

---

## 2. Justificación Teórica y Científica

### 2.1 Prohibición de Umbrales Arbitrarios y Separación por Contexto
- **Problema original:** Reglas rígidas como `heartRate > 100 = Taquicardia severa` ignoran el estado fisiológico real (un astronauta en entrenamiento en ARED/CEVIS/T2 supera los 100 lpm de manera normal).
- **Solución implementada:** Todas las mediciones se evalúan según su `ActivityContext` (`sleep`, `rest`, `physicalActivity`, `unknown`). Si no hay lectura válida, se muestra explícitamente **`Sin datos disponibles`** en lugar de valores predeterminados ficticios.

### 2.2 Fuentes Documentales Oficiales (Archivadas en `DB/`)
- **Frecuencia Cardíaca:**
  - *Mendes Zambetta et al. (2024), Frontiers in Physiology:* Incremento medio no uniforme de `+3.44 lpm` en microgravedad; justifica priorizar basales individuales pre-misión y comparar solo contextos equivalentes.
  - *American Heart Association (AHA):* Intervalo terrestre general de 60–100 lpm en reposo.
  - *CSA Bio-Monitor & NASA CARDIOBREATH (Crew-5):* Antecedente de monitoreo textil continuo en la ISS.
  - *Fine et al. (2021), Biosensors:* Limitaciones de sensores PPG por movimiento, perfusión y condiciones de piel.
- **Frecuencia Respiratoria y SpO₂:**
  - *Cleveland Clinic & Berry et al. (2012):* Referencia orientativa de 12–20 rpm en reposo; sin diagnóstico por lectura única.
  - *U.S. FDA (Pulse Oximeters / 510(k) Guidance 2013) & NHLBI (2023):* 95–100 % como referencia terrestre general, sujeta a calidad de señal y artefactos, no como límite universal espacial.
- **Sueño:**
  - *Hirshkowitz et al. (2015, NSF) & Watson et al. (2015, AASM/SRS):* Duración recomendada de **7 a 9 horas** por cada 24 h (corregido el umbral previo de 6.5 h a 7.0 h).
  - *Smith et al. (2018) & Barger et al. (2014):* Uso de actigrafía (sin atribuir detección clínica de fases REM/NREM).
- **Actividad Física y Fuerza Muscular:**
  - *NASA-STD-3001 Vol. 1, Requisito V1 4024:* Conservación de fuerza muscular esquelética $\ge 80\%$ respecto a basal pre-misión bajo protocolo instrumental equivalente.
  - *NASA OCHMO-TB-031 (2023) & Petersen et al. (2016, ESA):* Seguimiento de contramedidas (ARED, CEVIS, T2).

### 2.3 Justificación Pedagógica y Gamificación Segura
Siguiendo la directriz del reto de la NASA (*"Do not assume that astronauts know everything about how to assess their health"*):
- La vista general muestra de inmediato los valores actuales y medias por contexto sin saturación técnica.
- Al tocar cada indicador se abre `VitalDetailFullScreenView` con instrucciones paso a paso (*¿Cómo se mide?*, *¿Qué significa según tu actividad?*, *¿Cuándo prestar atención?*), gráficas de tendencia (`fl_chart`) y misiones de hábito (*Autoconocimiento Vital*) que premian la revisión y registro **sin puntuar ni castigar valores fisiológicos**.

### 2.4 Justificación Arquitectónica del Triaje Híbrido (ADA + LLM Local / Cloud Fallback)
Los modelos de lenguaje generativos (LLMs) aportan empatía, lenguaje natural y adaptación contextual al astronauta, pero presentan riesgo de alucinación si definen niveles de gravedad médica sin control. Por ello se implementa una arquitectura de **3 capas en cascada**:
1. **Guardrail Clínico Determinista (ADA + APOLO):** `ApolloTriageEngine` fija siempre de forma determinista la prioridad (`Green`, `Yellow`, `Red`), el hardware biomédico recomendado, las pautas de acción y las preguntas escalonadas de seguimiento.
2. **Capa Conversacional Local-First (Web/Edge AI):** `HybridLlmTriageService` consulta primero un modelo local (compatible con Ollama / WebLLM en navegador o host local) manteniendo privacidad médica y baja latencia sin internet.
3. **Capa Cloud Fallback + Resiliencia Deep-Space:** Si el modelo local no responde y existe conectividad + API Key, consulta un modelo en la nube (Gemini / OpenAI); si no hay red (misión en espacio profundo), garantiza respuesta inmediata con el motor determinista 100% offline.

---

## 3. Modo Simulación e Integraciones Pendientes
Documentado en `DB/simulation_and_pending_integrations.md`: ante la falta de hardware biomédico físico en el entorno de desarrollo, los equipos (`SpaceMachinesCatalog`) operan en modo simulación explícitamente etiquetado, dejando definidas las interfaces para conectar drivers BLE/ANT+/SpaceBus reales.

---

## 4. Archivos Principales y Verificación
- `lib/features/01_general_health/domain/scientific_criteria_engine.dart`
- `lib/features/01_general_health/presentation/general_health_view.dart`
- `lib/features/01_general_health/presentation/widgets/vital_detail_full_screen_view.dart`
- `lib/features/01_general_health/presentation/providers/telemetry_panel_provider.dart`
- `lib/features/05_clinical_triage/domain/apollo_triage_engine.dart`
- `lib/features/05_clinical_triage/domain/hybrid_llm_triage_service.dart`
- `lib/features/05_clinical_triage/presentation/triage_view.dart`
- `lib/core/storage/crew_database_service.dart`
- `DB/scientific_criteria.json`, `DB/references.md`, `DB/simulation_and_pending_integrations.md`, `DB/PR_JUSTIFICACION_COMPLETA.md`
- `test/features/01_general_health/scientific_criteria_engine_test.dart`
- `test/features/05_clinical_triage/hybrid_llm_triage_service_test.dart`
