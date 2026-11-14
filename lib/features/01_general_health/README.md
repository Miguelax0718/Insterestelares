# 🩺 Módulo 1: Monitor de Salud General y Signos Vitales

## 🎯 Objetivo del Módulo
Monitorear, registrar y visualizar en tiempo real los signos vitales estándar de los astronautas durante la misión (frecuencia cardíaca, presión arterial, saturación de oxígeno, temperatura y glucosa).

## 📁 Estructura del Módulo
- `models/`: Clases y entidades de datos (ej: `VitalsRecord`).
- `providers/`: Gestión de estado con Riverpod y persistencia en Hive.
- `widgets/`: Gráficos con `fl_chart`, tarjetas biométricas y medidores en tiempo real.
- `presentation/`: Pantalla principal del monitor de signos vitales (`general_health_view.dart`).

## 👨‍💻 Asignación de Tareas
- Integrante responsable del frontend: Diseñar widgets con gráficos interactivos y alertas visuales por color (verde, amarillo, rojo).
- Integrante de datos/lógica: Crear la simulación de flujo continuo de telemetría y guardado local offline.
