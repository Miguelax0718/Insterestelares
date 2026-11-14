# Nota Aclaratoria: Modo Simulación e Integraciones Pendientes

## 1. Propósito de la Simulación
En el contexto del desarrollo del software (**NASA Space Apps Challenge — AstraMed / Insterestelares**), el equipo no cuenta con hardware biomédico espacial ni dispositivos clínicos físicos conectados en tiempo real (Bio-Monitor/AstroSkin, bandas ECG/PPG, bandas respiratorias torácicas, pulsioxímetros certificados, actígrafos, ARED, CEVIS, T2 o dinamómetros isocinéticos).

Por ello, la aplicación opera con un **Modo Simulación explícitamente identificado** que permite:
1. Probar y validar el flujo completo de monitoreo fisiológico por contexto (`Sueño`, `Reposo`, `Actividad física`, `Desconocido`).
2. Verificar la visualización de gráficas longitudinales, calidad de señal y trazabilidad de metadatos (`device`, `protocol`, `measurementMethod`, `recordType`, `signalQuality`, `algorithm`, `criterionReference`).
3. Evaluar el motor de criterios científicos (`ScientificCriteriaEngine`) sin depender de hardware externo.

> [!IMPORTANT]
> **Regla de transparencia científica:** Los datos generados por el simulador representan un **entorno de prueba/demostración** y **no** deben interpretarse como telemetría clínica real ni como diagnóstico médico. Cuando no existan paquetes capturados para un astronauta o dispositivo, las gráficas muestran explícitamente **«Sin datos disponibles»**.

---

## 2. Estado Actual de Dispositivos en el Sistema

| Dispositivo / Sistema | Estado en la App | Qué hace actualmente |
|---|---|---|
| **Bio-Monitor / AstroSkin (`DEV-ASTROSKIN`)** | Simulado (`SpaceMachinesCatalog`) | Genera paquetes con FC, FR, PA, SpO₂, temperatura y llenado capilar. |
| **EPM Cardiocavity Module (`DEV-EPM`)** | Simulado (`SpaceMachinesCatalog`) | Genera paquetes de hemodinámica y PA. |
| **ARED / Contramedidas** | Simulado (`SpaceMachinesCatalog`) | Genera métricas de entrenamiento de resistencia. |
| **HERA Radiation Assay (`DEV-HERA`)** | Simulado (`SpaceMachinesCatalog`) | Genera tasa y dosis acumulada de radiación. |
| **Banda ECG / PPG alternativa** | Pendiente de driver físico | Cubierta mediante simulación o ingreso manual offline. |
| **Banda Respiratoria Torácica** | Pendiente de driver físico | Cubierta mediante simulación o ingreso manual offline. |
| **Pulsioxímetro portátil validado** | Pendiente de driver físico | Cubierta mediante simulación o ingreso manual offline. |
| **Actígrafo de muñeca** | Pendiente de implementación | Planificado en Bloque 3 (Sueño) + alternativa de diario manual. |
| **CEVIS / T2 / Dinamómetro estandarizado** | Pendiente de implementación | Planificado en Bloque 4 (Actividad Física y Fuerza Muscular NASA-STD-3001 V1 4024). |

---

## 3. Qué Falta por Añadir para Implementación en Producción (Checklist para el Equipo)

### A. Capa de Adquisición y Hardware (`lib/features/telemetry/`)
- [ ] **Adaptadores de comunicación reales:** Implementar clientes BLE / ANT+ / SpaceBus / SpaceWire para reemplazar `SpaceMachinesCatalog.generateTelemetryPacket(...)` en modo operativo.
- [ ] **Separación estricta de entornos:** Añadir bandera de compilación o configuración (`TelemetryMode.production` vs. `TelemetryMode.simulation`) para deshabilitar generadores sintéticos en operación real.
- [ ] **Validación de señal en origen:** Descartar automáticamente lecturas PPG/SpO₂ con artefactos de movimiento o baja perfusión antes de enviarlas a evaluación (Fine et al., 2021; FDA 510(k)).

### B. Persistencia Histórica Offline (`Hive` / `Isar`)
- [ ] **Series temporales persistentes:** Actualmente `TelemetryState.recentLogs` conserva los últimos 50 paquetes en memoria RAM. Falta persistir el historial completo por astronauta en Hive/Isar para consultas de 24 h, 7 d y toda la misión.
- [ ] **Basales individuales pre-misión:** Cargar y persistir en `DB/Users/` la frecuencia cardíaca basal en reposo, FR basal, SpO₂ basal y fuerza muscular pre-misión de cada astronauta para habilitar comparaciones longitudinales individuales.

### C. Módulos Clínicos Pendientes
- [ ] **Sueño (Bloque 3):** Actigrafía + diario manual subjetivo + 4 gráficas obligatorias (7–9 h NSF/AASM).
- [ ] **Actividad física y Fuerza muscular (Bloque 4):** Integración CEVIS/T2 + cronómetro manual + criterio NASA-STD-3001 V1 4024 (≥ 80 % fuerza conservada).
- [ ] **Gamificación de Misiones de Bienestar (Bloque 5):** Seguimiento de cumplimiento sin puntuaciones de salud ni rankings.
