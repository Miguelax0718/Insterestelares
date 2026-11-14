# 🚀 Arquitectura de Código - AstraMed (Space Health Engine)

Esta carpeta contiene la implementación completa de la aplicación en Flutter bajo una arquitectura modular y orientada a los **5 Peligros del Vuelo Espacial de la NASA**.

---

## 📂 Organización de Carpetas y Módulos

```text
lib/
├── core/                               # Lógica transversal compartida
│   ├── constants/                      # Umbrales médicos y límites de radiación NASA
│   ├── storage/                        # Inicialización de base de datos local (Hive / Offline)
│   └── theme/                          # Tema de cabina espacial oscura (SpaceTheme)
│
├── features/                           # MÓDULOS DE PROGRAMACIÓN POR GRUPOS
│   │
│   ├── 01_general_health/              # 🩺 MÓDULO 1: SALUD GENERAL Y SIGNOS VITALES
│   │   ├── models/                     # Entidades (VitalsRecord, frecuencia cardíaca, BP, SpO2)
│   │   ├── providers/                  # Estado reactivo (Riverpod) y flujo de telemetría
│   │   ├── widgets/                    # Tarjetas biométricas y gráficas de signos vitales
│   │   └── presentation/               # Pantalla principal del monitor de salud
│   │
│   ├── 02_radiation/                   # ☢️ MÓDULO 2: RADIACIÓN ESPACIAL (SPE & GCR)
│   │   ├── models/                     # Entidades (RadiationDose, alertas de tormenta solar)
│   │   ├── providers/                  # Cálculo de dosis acumulada (mSv) y detección de picos
│   │   ├── widgets/                    # Dosímetro visual de cabina y alerta de refugio
│   │   └── presentation/               # Pantalla de monitoreo dosimétrico
│   │
│   ├── 03_microgravity/                # 🧑‍🚀 MÓDULO 3: MICROGRAVEDAD Y APARATO LOCOMOTOR
│   │   ├── models/                     # Registros de ejercicio, densidad ósea y fluidos
│   │   ├── providers/                  # Seguimiento de contramedidas diarias (ARED, T2, CEVIS)
│   │   ├── widgets/                    # Mapa anatómico interactivo del cuerpo humano
│   │   └── presentation/               # Pantalla de microgravedad y contramedidas
│   │
│   ├── 04_mental_health/               # 🧠 MÓDULO 4: SALUD MENTAL Y RITMOS CIRCADIANOS
│   │   ├── models/                     # Registros de sueño, niveles de estrés y fatiga
│   │   ├── providers/                  # Tracker de ciclo de sueño y fatiga cognitiva
│   │   ├── widgets/                    # Gráficas de descanso y selector de estado anímico
│   │   └── presentation/               # Pantalla de descanso y bienestar mental
│   │
│   └── 05_clinical_triage/             # 🚨 MÓDULO 5: TRIAGE Y GUÍAS CLÍNICAS OFFLINE
│       ├── models/                     # Nodos del árbol de decisión (Verde/Amarillo/Rojo)
│       ├── providers/                  # Motor de autodiagnóstico determinista
│       ├── widgets/                    # Asistente de síntomas paso a paso y botiquín
│       └── presentation/               # Pantalla de triage y soporte de emergencia
│
└── main.dart                           # Entrada principal con barra de navegación de cabina
```

---

## 👥 Guía Rápida para los Grupos de Trabajo

* **Grupo 1 (Investigación Biomédica & Lógica Clínica):**
  - Trabaja en los modelos y reglas de decisión dentro de `features/02_radiation/`, `features/05_clinical_triage/` y `core/constants/`.
* **Grupo 2 (Arquitectura, UI/UX & Visualización):**
  - Trabaja en las vistas y widgets dentro de `features/01_general_health/`, `features/03_microgravity/`, `features/04_mental_health/` y `core/theme/`.

> [!IMPORTANT]
> **Regla de Oro Offline:** Ningún archivo o componente de estas carpetas debe requerir llamadas a servidores web o APIs externas en tiempo de ejecución.
