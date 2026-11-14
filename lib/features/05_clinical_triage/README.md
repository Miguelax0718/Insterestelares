# 🚨 Módulo 5: Autodiagnóstico, Triage Autónomo y Tratamientos Offline

## 🎯 Objetivo del Módulo
Guiar a la tripulación ante emergencias médicas o síntomas inesperados cuando no hay comunicación en tiempo real con la Tierra (Distance from Earth). Implementa árboles de decisiones clínicas deterministas de la NASA, clasificando en Verde, Amarillo o Rojo, y ofreciendo procedimientos paso a paso y uso del botiquín médico.

## 📁 Estructura del Módulo
- `models/`: Nodos de decisión, síntomas y prescripciones locales (`TriageNode`, `MedicalSupply`).
- `providers/`: Motor de resolución de árbol de triage médico offline.
- `widgets/`: Cuestionario escalonado interactivo, animaciones de primeros auxilios (Lottie/Rive).
- `presentation/`: Pantalla del flujo de triage (`triage_view.dart`).

## 👨‍💻 Asignación de Tareas
- Integrante responsable de frontend: Flujo interactivo paso a paso de síntomas y visualizador de procedimientos.
- Integrante de lógica médica: Protocolos de emergencia de la NASA (RCP en microgravedad, vendajes, analgesia, tratamiento de radiación aguda).
