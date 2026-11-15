# Repositorio de Datos y Telemetría Médica (DB) - AstraMed

Este directorio almacena y estructura las fuentes de datos operacionales, catálogos de hardware médico espacial y perfiles clínicos de la tripulación para el sistema de monitoreo de salud **AstraMed** (*NASA Space Apps Challenge*).

La arquitectura implementada sigue un principio **100% Offline-First**, garantizando que el soporte vital, los diagnósticos y la gestión de telemetría funcionen de manera local e independiente de la conectividad con la Tierra.

---

## 📂 Estructura de Directorios

```text
DB/
├── Information/
│   └── telemetry_machines_catalog.json  # Catálogo técnico de las 7 máquinas y biosensores espaciales
├── Users/
│   ├── AST-01_alex_vance.json           # Registro clínico y telemetría: Cmdte. Alex Vance
│   ├── AST-02_elena_ramos.json          # Registro clínico y telemetría: Dra. Elena Ramos (CMO)
│   ├── AST-03_mateo_torres.json         # Registro clínico y telemetría: Ing. Mateo Torres (EVA)
│   ├── AST-04_sarah_chen.json           # Registro clínico y telemetría: Dra. Sarah Chen
│   ├── AST-05_leo_morales.json          # Registro clínico y telemetría: Téc. Leo Morales (ECLSS)
│   ├── crew_index.json                  # Índice maestro de acceso rápido a los 5 tripulantes
│   └── user_schema.json                 # JSON Schema formal (Draft-07) para validación de perfiles
└── README.md                            # Documentación y trazabilidad del repositorio de datos
```

---

## 🧑‍🚀 Módulo `DB/Users/`

Gestiona la base de datos de los 5 miembros de la misión espacial de espacio profundo (Artemisa / Marte), centralizando signos vitales, dosimetría radiológica, descanso circadiano y protocolos de ejercicio físico en microgravedad.

### 1. `user_schema.json`
- **Estándar:** JSON Schema Draft-07 (`https://astramed.space/schemas/user_schema.json`).
- **Campos obligatorios:**
  - `id`: Identificador único formato `AST-XX`.
  - `name`, `role`, `rank`, `callsign`, `avatarInitials`, `age`, `bloodType`, `currentZone`.
  - `linkedMachineIds`: Arreglo de IDs de dispositivos de telemetría vinculados activamente.
  - `vitals`: Medición de signos vitales (`timestamp`, `astronautId`, `source`, `deviceId`, `device`, `protocol`, `measurementMethod`, `activityState`, `signalQuality`, `recordType`, `algorithm`, `criterionReference`, `heartRate`, `systolicBP`, `diastolicBP`, `spO2`, `bodyTemp`, `bloodGlucose`, `respiratoryRate`, `capillaryRefillSeconds`).
  - `radiation`: Registro dosimétrico (`timestamp`, `astronautId`, `source`, `deviceId`, `device`, `protocol`, `measurementMethod`, `activityState`, `signalQuality`, `recordType`, `algorithm`, `criterionReference`, `doseRateMicroSvPerHour`, `cumulativeDoseMilliSv`, `severity`: `["normal", "warning", "critical"]`).
  - `sleep`: Métricas de descanso (`date`, `astronautId`, `source`, `deviceId`, `device`, `protocol`, `measurementMethod`, `activityState`, `signalQuality`, `recordType`, `algorithm`, `criterionReference`, `sleepHours`, `wakeEpisodes`, `morningMood`: `["great", "good", "neutral", "fatigued", "stressed"]`).
  - `exercise`: Sesión de contramedidas (`date`, `astronautId`, `source`, `deviceId`, `device`, `protocol`, `measurementMethod`, `activityState`, `signalQuality`, `recordType`, `algorithm`, `criterionReference`, `deviceName`, `durationMinutes`, `caloriesBurned`, `targetReached`).
  - **Metadatos clínicos y de telemetría requeridos en cada dominio:** `astronautId`, `source` (`telemetry` | `manual`), `device`, `measurementMethod`, `activityState`, `signalQuality`, `recordType` (`instrumental` | `estimación` | `manual` | `subjetiva`), `algorithm` y `criterionReference`.
  - `riskLevel`: Nivel de triage global (`["nominal", "warning", "critical"]`).
  - `riskTitle`, `riskDescription`, `activeAlerts` (arreglo de strings), `lastTelemetrySync` y `lastUpdated` (ISO8601).

### 2. `crew_index.json`
- Índice de lectura ultrarrápida para componentes de UI (List Views, Selectores de Paciente, Dashboards de Mando) sin necesidad de cargar todos los historiales pesados.
- Contiene referencias a los 5 tripulantes:
  - `AST-01`: Alex Vance (`ARES-1`) — Estado Nominal.
  - `AST-02`: Dra. Elena Ramos (`ATHENA`) — Precaución: Fatiga y Febrícula.
  - `AST-03`: Ing. Mateo Torres (`SPARK`) — Alerta Crítica: Hipoxia Post-EVA.
  - `AST-04`: Dra. Sarah Chen (`NOVA`) — Estado Nominal.
  - `AST-05`: Téc. Leo Morales (`TITAN`) — Precaución: Presión Arterial y Dosis Alta.

---

## 🛰️ Módulo `DB/Information/`

### `telemetry_machines_catalog.json`
Define las especificaciones técnicas, protocolos de comunicación local de cabina y métricas recopiladas por las 7 máquinas y biosensores espaciales soportados por AstraMed:

| ID Dispositivo | Nombre del Equipo | Categoría | Protocolo / Tipo | Método y Criterio de Referencia |
| :--- | :--- | :--- | :--- | :--- |
| `DEV-ASTROSKIN` | Bio-Monitor Astroskin | `biometrics` | ANT+ / BLE SpaceBus v3.2 (`instrumental`) | ECG textil 3 derivaciones, PPG óptica; `NASA-STD-3001 Vol. 1 & Vol. 2 / MedicalThresholds` |
| `DEV-HERA` | HERA Radiation Assay | `dosimetry` | MIL-STD-1553B / Timepix bus (`instrumental`) | Espectrometría en silicio Timepix3; `NASA-STD-3001 Permissible Exposure Limits (PEL)` |
| `DEV-EPM` | EPM Cardiocavity Module | `hemodynamics` | SpaceWire / ISS-LAN (`instrumental`) | PPG arterial y tonometría; `NASA-STD-3001 Cardiovascular Health Monitoring` |
| `DEV-ARED` | ARED Advanced Resistive Device | `countermeasure` | CAN-Bus / Space Wireless (`estimación`) | Dinamometría y cinemática triaxial; `NASA-STD-3001 Musculoskeletal Countermeasure Protocol` |
| `DEV-CEVIS` | CEVIS Cycle Ergometer | `countermeasure` | RS-422 / BLE 5.0 (`estimación`) | Ergometría y estimación de VO2; `NASA-STD-3001 Aerobic Countermeasure Protocol` |
| `DEV-ISTAT` | Abbott i-STAT 1 Analyzer | `bloodLab` | Infrared Data / USB Secure Bus (`instrumental`) | Electroquímica capilar; `NASA-ISS CHeCS Clinical Blood Lab Standards` |
| `DEV-ACTIWATCH` | Actiwatch Plus Circadian Sensor | `circadian` | NFC / Optical Sync (`instrumental`) | Actigrafía triaxial y fotometría; `NASA-STD-3001 Behavioral Health & Circadian Standard` |

---

## 🧪 Validación de Integridad de Datos

Todos los archivos JSON pueden ser validados contra sus esquemas y verificar su parseo correcto mediante PowerShell:

```powershell
Get-ChildItem DB -Recurse -Filter *.json | ForEach-Object {
    Get-Content $_.FullName -Raw | ConvertFrom-Json | Out-Null
    Write-Host "OK: $($_.Name)" -ForegroundColor Green
}
```
> [!NOTE]
> Toda nueva información, archivo de soporte o dataset usable para el proyecto se debe documentar en esta sección para mantener la trazabilidad.

---

## 🐾 APOLO / URANO (análisis de orina)

Datos que consume la página `web/apolo/` (APOLO, antes URANO) cuando se conecta a una base de datos (por defecto usa datos demo internos y no necesita nada de esto):

- `schemas/urano_schema.sql`: tablas PostgreSQL/Supabase (`crew`, `mission`, `solar_events`, `biomarkers`, `personal_ranges`, `samples`, `sample_values`, `recommendations`, `alerts`, `water_log`, `sample_requests`).
- `samples/urano_seed.sql`: 5 tripulantes demo con 40 muestras cada uno (26 biomarcadores por muestra). Cada tripulante tiene un problema distinto: hidratación/riesgo renal, hueso, estrés y sueño, radiación e infección urinaria.

Los valores son simulados y los rangos por defecto deben validarse con el equipo biomédico (Grupo 1). Más detalle en `web/apolo/README.md`.
