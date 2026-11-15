# Plan de Arquitectura: Agente Clínico Autónomo

## 1. Visión General y Cambio de Paradigma
* **Problema de origen:** En misiones de espacio profundo con alta latencia de comunicación y sin personal médico especializado, un panel de control estático satura cognitivamente a un tripulante afectado por fatiga, mareo o alteraciones visuales.
* **Propuesta de valor:** Mantener la arquitectura actual de procesamiento de datos, umbrales clínicos de la NASA y correlación de variables en segundo plano, reemplazando la navegación por pestañas por un asistente clínico autónomo y conversacional.
* **Principio operativo:** Dosificación de la información. El sistema permanece en silencio visual cuando los parámetros son nominales y solo despliega módulos interactivos cuando el usuario lo solicita o cuando el motor detecta o predice un riesgo.

## 2. Estructura de la Interfaz

### Lienzo Principal del Agente
* **Representación del Agente:** Indicador visual central del estado del sistema junto con metadatos de contexto de la misión (día de misión, nivel de gravedad, latencia de comunicación con la Tierra).
* **Zona de Inyección Dinámica de Componentes:** Espacio adaptativo donde el agente renderiza temporalmente las tarjetas de datos, gráficas o pruebas interactivas según el flujo de la conversación o emergencia activa. Al finalizar la acción, el componente se oculta.
* **Canal de Voz Bidireccional:**
  * **Reconocimiento de voz (Speech-to-Text):** Entrada principal manos libres para consultas, registro de síntomas, bitácoras y control de pruebas durante procedimientos físicos o cuando existe deterioro visual.
  * **Síntesis de voz (Text-to-Speech):** Salida auditiva para guiar procedimientos médicos paso a paso, emitir alertas críticas y realizar cuestionarios clínicos sin exigir fijación visual en pantalla.

### Barra Lateral de Tripulación (Sidebar)
* **Vista general de la cohorte:** Lista permanente o desplegable con tarjetas de resumen compacto para cada miembro de la tripulación.
* **Datos por tarjeta de tripulante:**
  * Identificación y rol operativo.
  * Estado clínico global (nominal, precaución, crítico).
  * Métricas base resumidas: frecuencia cardíaca actual, horas de sueño recientes y estado de cumplimiento de la bitácora diaria.
  * Indicador de alertas activas o contramedidas pendientes.
* **Selector de contexto:** Seleccionar a un tripulante en la barra lateral cambia el contexto activo del agente hacia el expediente y telemetría de ese usuario.

## 3. Capacidades y Flujos Funcionales del Agente

### Consultas a Demanda y Reportes
* **Reporte de estado general:** Síntesis hablada y visual del estado fisiológico actual cruzando todos los subsistemas.
* **Evaluación de aptitud operativa (Pre-EVA / Aterrizaje):** Validación automática de criterios clínicos (ausencia de mareo moderado/severo, nivel de alerta cognitiva, estabilidad cardiovascular) para autorizar o bloquear actividades críticas.
* **Consulta puntual de telemetría:** Visualización bajo demanda de series temporales específicas (signos vitales, dosis de radiación, historial de sueño, inventario farmacéutico).

### Monitoreo Proactivo y Predicción de Riesgos
* **Clima espacial y astrofarmacia:** Monitoreo de eventos solares mediante la API DONKI de la NASA. Cálculo de degradación química por radiación en el inventario médico según la ubicación de almacenamiento, bloqueo de lotes comprometidos, solicitud de verificación por espectrometría Raman y programación de control de leucocitos post-tormenta.
* **Correlación fisiológica cruzada:** Detección de efectos en cascada entre subsistemas (por ejemplo, cruce de episodios de emesis por mareo espacial con baja ingesta hídrica y resorción ósea en microgravedad para predecir riesgo de litiasis renal).
* **Filtrado de artefactos de telemetría:** Cruce de datos biométricos con acelerometría para descartar falsas alarmas de hipoxia o taquicardia durante sesiones de ejercicio físico.

### Ejecución Guiada de Pruebas Clínicas
* **Evaluación de Mareo Espacial (Escala de Graybiel):** Interrogatorio guiado por voz para cuantificar severidad de síntomas vestibulares, bloqueo preventivo de actividades extravehiculares y cambio de vía de administración farmacológica (de oral a intranasal/parenteral) ante sospecha de parálisis gástrica.
* **Evaluación Neurocognitiva y Calibración Farmacológica (PVT y MPT):** Despliegue en pantalla de pruebas de tiempo de reacción y precisión motora calculando la métrica LRM-50 para medir fatiga, autorizar dosis compensatorias de estimulantes tras uso de antihistamínicos y bloquear segundas dosis nocturnas de hipnóticos.
* **Evaluación Neuro-Ocular (SANS):** Pruebas interactivas en pantalla de distorsión de cuadrícula, sensibilidad al contraste y distancia de enfoque para estimar cambios refractivos, asignar el par correspondiente de gafas preventivas y clasificar el grado de afectación.

### Acompañamiento en Contramedidas y Procedimientos
* **Guía de acondicionamiento físico:** Seguimiento en tiempo real de signos vitales y fuerzas de carga durante rutinas de ejercicio resistivo o sesiones de coordinación motora en microgravedad.
* **Asistencia en procedimientos médicos autónomos:** Instrucciones secuenciales interactivas para el uso del dispositivo de presión negativa del tren inferior (LBNP a $-20\text{ mmHg}$) con control de rampa de descompresión gradual, y guías paso a paso para ultrasonido autónomo renal y vesical.

### Bitácora Diaria por Voz y Salud Mental
* **Registro diario estructurado:** Captura diaria de audio corto por parte de cada tripulante relatando su estado general, calidad de descanso y eventos relevantes.
* **Extracción de indicadores psicológicos y cognitivos:**
  * Análisis semántico de la transcripción para identificar marcadores de estrés, aislamiento, conflicto o apatía vestibular (síndrome de Sopite).
  * Análisis de parámetros acústicos y cadencia del habla (pausas, velocidad, monotonía) correlacionados con fatiga central y deuda de sueño.
* **Recomendaciones adaptativas:** Ajuste de rutinas de descanso, pautas nutricionales y actividades de desconexión basadas en las tendencias de la bitácora y el sueño registrado.

## 4. Integración con la Estructura Actual del Repositorio

* **Módulo 01 (Salud General):** Provee el flujo continuo de signos vitales y filtrado de ruido cinético; entrega los datos resumidos al Sidebar y la tarjeta de signos vitales bajo demanda.
* **Módulo 02 (Radiación):** Procesa datos de la API NASA DONKI y el estado del inventario médico; entrega alertas de tormenta solar, control de lotes por RFID y validación Raman al flujo del agente.
* **Módulo 03 (Microgravedad):** Ejecuta la lógica de mareo espacial, SANS y riesgo renal; entrega los componentes interactivos de evaluación visual, cuestionario vestibular, temporizador LBNP y guías de ultrasonido.
* **Módulo 04 (Salud Mental):** Procesa métricas de sueño, cálculo LRM-50 y análisis de las bitácoras de voz; entrega el módulo de grabación diaria, las pruebas psicomotoras (PVT/MPT) y el control de fármacos de sueño.
* **Módulo 05 (Triaje Clínico):** Actúa como el motor central del agente, gestionando la interfaz conversacional, el canal de voz, el estado del Sidebar y la lógica que decide qué componente de los módulos 01 al 04 se inyecta en pantalla en cada momento.