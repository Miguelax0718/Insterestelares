# 🚀 AstraMed / Space Health Engine
## Estructura Organizacional y División de Roles del Equipo (6 Personas)
**Iniciativa:** NASA Space Apps Challenge — *Interestelares*  
**Proyecto:** Health Monitoring Software for Astronauts on Space Missions  
**Pila Tecnológica:** Flutter (100% Offline-First) • Hive/Isar • Riverpod/Provider • Lottie/Rive

---

## 📋 Resumen del Organigrama del Equipo

```text
┌────────────────────────────────────────────────────────────────────────┐
│                      ASTRAMED TEAM (6 INTEGRANTES)                     │
└────────────────────────────────────────────────────────────────────────┘
     │
     ├── 1. Team Lead & Flutter Core Architect (Líder & Arquitectura)
     ├── 2. UI/UX & Motion Designer (Diseño, Cabina Espacial & Lottie/Rive)
     ├── 3. Flutter Frontend & Data Visualizer (Vistas, Gráficos & Gamificación)
     ├── 4. Clinical Logic & Triage Engine Specialist (Árboles de Decisión & Triage)
     ├── 5. Space Biomedical Researcher & Data Engineer (Fuentes NASA & Datasets DB)
     └── 6. QA, Offline Tester & Pitch/Storytelling Lead (Calidad Offline & Demo/Pitch)
```

---

## 👤 Detalle de Roles y Asignación de Tareas

### 👨‍💻 Rol 1: Team Lead & Flutter Core Architect (Líder de Proyecto & Arquitectura)
* **Objetivo:** Garantizar la cohesión del código, la arquitectura modular y la resiliencia offline.
* **Responsabilidades Clave:**
  - Coordinar la sincronización del equipo, milestones del hackathon y entregas en GitHub.
  - Diseñar la estructura base modular *Feature-First* (`lib/core/`, `lib/features/`).
  - Configurar e inicializar la base de datos local NoSQL (`Hive` o `Isar`) para persistencia sin conexión.
  - Gestionar el sistema de inyección de dependencias y estado global (`Riverpod` o `Provider`).
  - Realizar revisiones de código (Code Reviews), resolver conflictos en Git y asegurar el cumplimiento de `AGENTS.md`.

---

### 🎨 Rol 2: UI/UX & Motion Designer (Diseño de Experiencia, Cabina & Animaciones)
* **Objetivo:** Crear una interfaz visual inmersiva, intuitiva y optimizada para entornos extremos.
* **Responsabilidades Clave:**
  - Diseñar el tema visual de alto contraste ("Space Cockpit Dark Mode") optimizado para baja luminosidad.
  - Diseñar el componente interactivo del **cuerpo humano clickable** (donde cada órgano o zona corporal muestre su estado de salud de un vistazo).
  - Diseñar e integrar animaciones interactivas (`Lottie` / `Rive`) para procedimientos médicos y primeros auxilios.
  - Establecer el sistema de codificación de color de emergencia (Verde: Estable, Amarillo: Atención, Rojo: Crítico).
  - Asegurar que todos los componentes sean 100% responsive (tablets de cabina a laptops).

---

### 💻 Rol 3: Flutter Frontend & Data Visualizer (Desarrollador Flutter - UI & Gráficos)
* **Objetivo:** Construir las pantallas interactivas de monitoreo y telemetría médica en tiempo real.
* **Responsabilidades Clave:**
  - Implementar la pantalla principal del astronauta (`features/vitals/`): frecuencia cardíaca, presión arterial, $SpO_2$, glucosa, temperatura y radiación.
  - Implementar gráficos dinámicos interactivos con `fl_chart` para visualizar tendencias temporales de signos vitales.
  - Desarrollar el sistema de **gamificación y rutinas periódicas** (misiones diarias de salud para incentivar a la tripulación).
  - Crear formularios de ingreso ágiles (sliders, botones rápidos, inputs adaptados para uso con guantes o pantallas táctiles).

---

### 🧠 Rol 4: Clinical Logic & Triage Engine Specialist (Lógica Clínica y Triage Espacial)
* **Objetivo:** Desarrollar el cerebro de autodiagnóstico determinista y guías de tratamiento.
* **Responsabilidades Clave:**
  - Programar el motor de autodiagnóstico (`features/diagnostics/`): árbol de decisiones clínicas basado en síntomas escalonados.
  - Diseñar los algoritmos de clasificación de gravedad médica (Código Verde, Amarillo, Rojo).
  - Conectar el resultado del diagnóstico con los pasos de autotratamiento y el inventario del botiquín médico de a bordo.
  - Redactar y estructurar en Markdown las guías de emergencia médica y procedimientos (`assets/guides/` y `features/knowledge_base/`).

---

### 🔬 Rol 5: Space Biomedical Researcher & Data Engineer (Investigación Biomédica & Datos)
* **Objetivo:** Fundamentar científicamente la app según los 5 peligros de la NASA y alimentar los datos.
* **Responsabilidades Clave:**
  - Mapear los **5 Peligros de los Vuelos Espaciales** de la NASA (Radiación, Aislamiento, Distancia, Microgravedad, Ambientes Cerrados) a indicadores medibles.
  - Definir los rangos de normalidad y umbrales de alerta médica para astronautas en microgravedad.
  - Crear y estructurar datasets y telemetría sintética en la carpeta `DB/` (escenarios de astronauta en reposo, ejercicio EVA, radiación alta o hipoxia).
  - Curar y organizar las fuentes científicas oficiales en la carpeta `sources/` (papers, manuales médicos de la ISS, guías de la NASA).

---

### 📢 Rol 6: QA, Offline Tester & Pitch / Storytelling Lead (Calidad, Offline & Presentación)
* **Objetivo:** Validar la experiencia de usuario sin internet y liderar la defensa del proyecto.
* **Responsabilidades Clave:**
  - **Pruebas Offline Extremas:** Auditar que la app funcione al 100% en modo avión, sin caídas ni llamadas de red bloqueantes.
  - Validar accesibilidad, legibilidad del texto en cabina y usabilidad para astronautas no médicos.
  - Redactar el contenido de la ficha de entrega en la plataforma oficial del NASA Space Apps Challenge.
  - Liderar la creación del guion, storyboard y edición del **video pitch de 2 minutos** (criterio decisivo de evaluación del hackathon).

---

## ⏱️ Matriz de Coordinación por Fases (Sprint del Hackathon)

| Fase | Roles 1 & 2 (Core & Diseño) | Roles 3 & 4 (Frontend & Lógica) | Roles 5 & 6 (Ciencia & Validación/Pitch) |
| :--- | :--- | :--- | :--- |
| **Fase 1: Setup & Cimientos** | Setup Flutter, Hive/Isar y paleta espacial. | Prototipo de navegación y árbol inicial de síntomas. | Recopilación de fuentes NASA y dataset base en `DB/`. |
| **Fase 2: Vitals & Datos** | Componente de figura humana interactiva. | Pantalla de métricas y gráficos `fl_chart`. | Simulación de telemetría de astronautas en crisis. |
| **Fase 3: Diagnóstico & Triage** | Animaciones Lottie de primeros auxilios. | Motor de triage y visor de manuales Markdown. | Validación médica de alertas y estructura del pitch. |
| **Fase 4: Pulido & Entrega** | Responsive final y estilo de cabina. | Pruebas de integración de datos locales. | Grabación de video pitch, prueba 100% offline y entrega. |

---

## 👥 Organización de los Grupos de Trabajo

Para optimizar el sprint de trabajo y abordar los desafíos de manera ágil y especializada, el equipo se organiza en dos frentes de trabajo:

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        ORGANIZACIÓN DE LOS GRUPOS DE TRABAJO                           │
└────────────────────────────────────────────────────────────────────────────────────────┘
     │
     ├── 🔬 GRUPO ENFOCADO EN EL ANÁLISIS DE LAS PROBLEMÁTICAS ESPECÍFICAS (3 INTEGRANTES)
     │    ├── Integrantes: Juan, María, Mafe
     │    ├── Foco Inicial: Análisis de la afectación de la radiación espacial en los astronautas
     │    └── Roles Clave: Investigación Biomédica (NASA HRP), Lógica de Triage y QA/Validación
     │
     └── 💻 GRUPO ENFOCADO EN EL MONITOREO DE LA SALUD GENERAL (EQUIPO TÉCNICO & CORE)
          ├── Integrantes: Miguel, Daniel (y equipo de desarrollo)
          ├── Foco Inicial: Arquitectura Flutter Offline-First, Vitals y Dashboard Espacial
          └── Roles Clave: Core Architect, UI/UX Cabina & Motion Graphics, Frontend Visualizer
```

---

## ☢️ Problema 1 (En curso - Trabajo actual del Grupo de 3): "Análisis de la afectación de la radiación espacial en los astronautas"

> **Descripción Oficial:**  
> *Durante las misiones espaciales prolongadas, especialmente hacia la Luna y Marte, los astronautas están expuestos a radiación cósmica y partículas solares que pueden provocar daños celulares, aumentar el riesgo de cáncer y afectar diferentes órganos y sistemas del cuerpo. Aunque existen dispositivos que miden la exposición a la radiación, uno de los principales desafíos consiste en relacionar la dosis acumulada con posibles alteraciones biológicas y evaluar sus efectos sobre la salud de cada astronauta.*

### 📋 Distribución de Tareas por Grupo e Integrante

#### 🔬 GRUPO 1: Análisis de las Problemáticas Específicas (Grupo de 3: Juan, María, Mafe)
*Foco principal:* Modelado fisiopatológico, umbrales de radiación de la NASA, árbol de decisiones clínicas y telemetría médica sintética.

* **Integrante 1 (Investigación Biomédica & Datos NASA):**
  - **Tarea 1.1:** Investigar y documentar los límites de dosis de radiación de la NASA (mSv acumulados diarios, por misión y límites de por vida ajustados a los estándares de NASA/NCRP).
  - **Tarea 1.2:** Crear en `DB/` los esquemas y datasets sintéticos de telemetría de radiación (`radiation_telemetry.json` y `dose_logs.json`) con escenarios de: radiación basal en espacio profundo, alerta por tormenta solar (SPE) y exposición acumulada en EVA.
  - **Tarea 1.3:** Organizar en `sources/medical/` y `sources/nasa/` los papers y guías oficiales de radiación del Human Research Program (HRP).

* **Integrante 2 (Lógica Clínica, Triage & Árboles de Decisión):**
  - **Tarea 2.1:** Diseñar el árbol de decisiones clínicas y triage para radiación: clasificar síntomas iniciales de sobreexposición (náuseas, vómito, cefalea, eritema cutáneo, fatiga extrema).
  - **Tarea 2.2:** Definir los 3 niveles de severidad médica:
    - 🟢 **Verde (Bajo / Normal):** Exposición controlada, monitoreo pasivo de dosímetro.
    - 🟡 **Amarillo (Atención / Pre-Alerta):** Incremento de tasa de dosis ($> 1\,\text{mSv/h}$) o pico por aproximación de evento solar; recomendación de limitar EVA.
    - 🔴 **Rojo (Crítico / Emergencia):** Evento SPE activo o dosis aguda ($> 250\,\text{mSv}$); orden inmediata de retiro al refugio blindado de tormenta (*storm shelter*) y protocolo médico de soporte.
  - **Tarea 2.3:** Redactar en `assets/guides/radiation_safety.md` el manual de autotratamiento y contramedidas (hidratación, uso de antioxidantes/fármacos radioprotectores y blindaje con agua/combustible).

* **Integrante 3 (Validación de Calidad, Casos de Prueba & Storytelling):**
  - **Tarea 3.1:** Validar que los algoritmos de alerta y el triage no dependan de llamadas de red (prueba 100% offline).
  - **Tarea 3.2:** Diseñar los casos de prueba médicos: simular un astronauta en caminata espacial (EVA) alcanzado por una tormenta solar para comprobar la respuesta del software.
  - **Tarea 3.3:** Elaborar la narrativa y el storyboard del pitch demostrando cómo AstraMed salva la vida de la tripulación ante un pico crítico de radiación espacial.

---

#### 💻 GRUPO 2: Monitoreo de la Salud General (Miguel, Daniel y equipo técnico)
*Foco principal:* Implementación de la aplicación en Flutter, widgets de cabina, visualización del cuerpo humano con afectación biológica y persistencia local de dosis.

* **Integrante 1 (Team Lead & Arquitectura Core):**
  - **Tarea 1.1:** Configurar los modelos de datos en Flutter/Dart para radiación (entidades: `RadiationDose`, `CumulativeExposure`, `DosimeterAlert`).
  - **Tarea 1.2:** Implementar la base de datos local (`Hive`/`Isar`) para registrar y almacenar de forma persistente y offline el historial dosimétrico de cada astronauta.
  - **Tarea 1.3:** Crear el servicio o proveedor de estado (`Riverpod`/`Provider`) que evalúe en tiempo real los umbrales de radiación y emita eventos de alarma en la aplicación.

* **Integrante 2 (UI/UX & Motion Designer):**
  - **Tarea 2.1:** Diseñar la interfaz del módulo de radiación con la paleta de cabina espacial de alto contraste (*Space Cockpit Dark Mode*).
  - **Tarea 2.2:** Diseñar el mapa anatómico interactivo resaltando los órganos más vulnerables a la radiación (médula ósea, sistema hematopoyético, tejido gastrointestinal, cristalino y tiroides).
  - **Tarea 2.3:** Crear o integrar microanimaciones (`Lottie` / `Rive`) para los estados de alerta (animación de advertencia por tormenta solar y guía visual de evacuación al *storm shelter*).

* **Integrante 3 (Frontend & Visualización de Datos):**
  - **Tarea 3.1:** Construir la pantalla del dosímetro en Flutter con un indicador radial o barra visual de dosis instantánea ($\mu\text{Sv/h}$) y dosis acumulada ($\text{mSv}$).
  - **Tarea 3.2:** Integrar gráficos temporales con `fl_chart` que muestren la curva de radiación recibida en las últimas 24 horas y durante toda la misión.
  - **Tarea 3.3:** Implementar el panel de autodiagnóstico donde el astronauta reporte síntomas físicos y reciba en pantalla los pasos de respuesta inmediata según el árbol de triage de radiación.

---

## 🚀 Siguientes por Implementar o Resolver (Backlog de Problemáticas Específicas)

---

### 🔄 Problema 2 (Siguiente por implementar): "Análisis de la adaptación sensoriomotora y vestibular de astronautas"

> **Descripción Oficial:**  
> *Durante las misiones espaciales, la exposición a la microgravedad y las transiciones entre diferentes niveles de gravedad pueden alterar el funcionamiento de los sistemas sensoriomotor y vestibular de los astronautas, responsables del equilibrio, la orientación espacial y la coordinación de movimientos. Asimismo, la exposición prolongada a la microgravedad puede provocar pérdida de masa muscular, disminución de la fuerza, reducción de la densidad mineral ósea y alteraciones en la capacidad física, afectando la movilidad, la resistencia y la estabilidad corporal.*  
>  
> *Estas alteraciones pueden provocar mareos, desorientación, náuseas, pérdida de estabilidad, debilidad muscular y dificultades para ejecutar movimientos precisos o realizar esfuerzos físicos. El riesgo es especialmente importante durante el aterrizaje en la Luna o Marte, cuando los astronautas deben adaptarse rápidamente a un nuevo entorno gravitacional y realizar actividades críticas, como desplazarse, mantener el equilibrio, transportar objetos, operar equipos o responder ante emergencias. Por ello, resulta fundamental monitorear de manera integral tanto la adaptación sensoriomotora y vestibular como el estado musculoesquelético de los astronautas, con el fin de identificar posibles deterioros físicos y evaluar su capacidad para desempeñar tareas de forma segura.*

* **Métricas e Indicadores Clave:**
  - Estabilidad postural y equilibrio dinámico.
  - Reflejo vestíbulo-ocular (VOR) y coordinación visomotora (ojo-mano).
  - Síntomas de Síndrome de Adaptación Espacial (SAS / mareo espacial cinético).
  - Fuerza de prensión manual (*grip strength*), fatiga muscular y cumplimiento de rutinas resistivas (ARED).
* **Asignación General de Tareas:**
  - **Grupo 1 (Problemáticas Específicas):** Diseñar los protocolos de autoevaluación sensoriomotora rápida (tests táctiles de coordinación en pantalla y seguimiento visual) y escalas de gravedad SAS.
  - **Grupo 2 (Monitoreo General):** Desarrollar las interfaces de pruebas psicomotrices en Flutter, mapa visual de afectación vestibular/muscular y gráficos de recuperación adaptativa postural.

---

### 🧪 Problema 3 (Siguiente por implementar): "Análisis de fluidos corporales"

> **Descripción Oficial:**  
> *Monitoreo mediante el análisis de fluidos corporales: Incorporar el análisis de biomarcadores presentes en fluidos como la orina, la saliva y el sudor para evaluar el estado de salud de los astronautas, identificar alteraciones fisiológicas y detectar tempranamente riesgos asociados con la deshidratación, los desequilibrios metabólicos y las afecciones renales, como la formación de cálculos. Esto permitiría adaptar el monitoreo a las condiciones individuales de cada astronauta y generar alertas preventivas a partir de los cambios observados.*

* **Métricas e Indicadores Clave:**
  - **Orina:** Densidad urinaria / gravedad específica (hidratación), niveles de calcio y oxalato (riesgo de nefrolitiasis / cálculos renales) y pH urinario.
  - **Saliva:** Cortisol salival (marcador biológico de estrés crónico y fatiga de misión), citoquinas e inmunoglobulina A (estado inmunológico).
  - **Sudor / Transpiración:** Tasa de pérdida de electrolitos ($Na^+$, $K^+$, $Cl^-$) y osmolaridad durante sesiones de entrenamiento físico en el cicloergómetro/ARED.
* **Asignación General de Tareas:**
  - **Grupo 1 (Problemáticas Específicas):** Diseñar el algoritmo de riesgo litogénico (formación de cálculos renales por hipercalciuria en microgravedad), correlación de biomarcadores salivales con el estrés y guías de reposición electrolítica personalizada.
  - **Grupo 2 (Monitoreo General):** Implementar la interfaz de registro rápido de análisis de tiras reactivas/biosensores de fluidos, alertas preventivas automáticas de deshidratación y cálculo de balance hídrico diario en la base de datos local.
