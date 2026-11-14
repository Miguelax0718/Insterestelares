# ☢️ Módulo 2: Monitoreo y Afectación por Radiación Espacial

## 🎯 Objetivo del Módulo
Monitorear la tasa de dosis instantánea ($\mu\text{Sv/h}$ o $\text{mSv/h}$) y la dosis acumulada de radiación cósmica galáctica (GCR) y eventos de partículas solares (SPE). Detectar picos de tormenta solar y guiar a la tripulación al *Storm Shelter*.

## 📁 Estructura del Módulo
- `models/`: Entidades de telemetría de radiación (`RadiationDose`, `SolarStormAlert`).
- `providers/`: Evaluador de umbrales NASA ($1\,\text{mSv/h}$ alerta, $250\,\text{mSv}$ crítico).
- `widgets/`: Dosímetro visual radial, historial de dosis en 24 horas (`fl_chart`), animaciones de alarma.
- `presentation/`: Pantalla del módulo de radiación (`radiation_view.dart`).

## 👨‍💻 Asignación de Tareas
- Integrante responsable de frontend: Visualización del dosímetro de cabina y alertas de alta prioridad.
- Integrante de lógica médica: Definición de umbrales clínicos y manual de refugio de tormenta en Markdown.
