# Repositorio de Datos (DB) - Insterestelares

Este directorio está destinado a almacenar y organizar las fuentes de datos, conjuntos de datos (datasets), esquemas y archivos estructurados que alimentan el sistema de monitoreo de salud para astronautas.

---

## 📂 Organización Sugerida

- `raw/`: Datos crudos o simulados sin procesar (CSV, JSON, XML, telemetría sintética).
- `processed/`: Datos normalizados, limpios y listos para consumo por la aplicación o base de datos.
- `schemas/`: Definiciones de esquemas de datos, modelos relacionales (SQL), migraciones o esquemas JSON/NoSQL.
- `samples/`: Muestras de prueba rápidas para tests unitarios y desarrollo local.

---

## 🛰️ Tipos de Datos Relevantes para la Misión

1. **Signos Vitales y Biometría:**
   - Frecuencia cardíaca (ECG/HR) y variabilidad (HRV).
   - Presión arterial y saturación de oxígeno ($SpO_2$).
   - Temperatura corporal y frecuencia respiratoria.

2. **Condiciones Ambientales de Cabina:**
   - Niveles de radiación acumulada e instantánea (mSv / Gy).
   - Concentración de gases ($O_2$, $CO_2$, presión barométrica).
   - Calidad del aire y contaminantes volátiles.

3. **Métricas de Rendimiento y Estado Físico:**
   - Monitoreo del sueño y ciclos circadianos.
   - Actividad física y protocolo de ejercicio en microgravedad.
   - Indicadores de fatiga, carga cognitiva y estrés psicológico.

---

> [!NOTE]
> Toda nueva información, archivo de soporte o dataset usable para el proyecto se debe documentar en esta sección para mantener la trazabilidad.
