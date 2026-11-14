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

## 👥 Organización de Grupos de Trabajo (Subgrupos de 3 Integrantes)

Para optimizar el sprint de trabajo y atacar los desafíos de manera paralela y especializada, el equipo se estructura en **2 Grupos de Trabajo de 3 integrantes cada uno**:

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        DIVISIÓN DE GRUPOS DE TRABAJO (3 + 3)                           │
└────────────────────────────────────────────────────────────────────────────────────────┘
     │
     ├── 🛰️ GRUPO 1: Investigación Biomédica, Lógica Clínica & Validación (3 Integrantes)
     │    ├── Integrante 1: Space Biomedical Researcher & Data Engineer
     │    ├── Integrante 2: Clinical Logic & Triage Engine Specialist
     │    └── Integrante 3: QA, Medical Validation & Storytelling Lead
     │
     └── 💻 GRUPO 2: Arquitectura Core, UI/UX Espacial & Visualización Frontend (3 Integrantes)
          ├── Integrante 1: Team Lead & Flutter Core Architect
          ├── Integrante 2: UI/UX & Motion Designer (Cabina & Animaciones)
          └── Integrante 3: Flutter Frontend & Data Visualizer
```

---

## ☢️ Problema General de Inicio: "Análisis de la afectación de la radiación espacial en astronautas"

El primer problema general en el que trabajará el equipo (con liderazgo e investigación a cargo del **Grupo 1**, e implementación de software y visualización a cargo del **Grupo 2**) es el **análisis de la afectación de la radiación espacial en astronautas** en misiones de larga duración (Artemis, Estación Espacial o tránsito a Marte).

### 🎯 Contexto Científico y Desafío
La radiación en el espacio profundo se compone principalmente de **Rayos Cósmicos Galácticos (GCR)** (flujo constante y penetrante de iones pesados) y **Eventos de Partículas Solares (SPE)** (emisiones de protones de alta energía asociadas a fulguraciones y eyecciones de masa coronal). Sus efectos en el cuerpo humano incluyen daño en el ADN, síndrome agudo por radiación (ARS), alteraciones hematopoyéticas, degeneración cardiovascular, cataratas y riesgos a largo plazo para el sistema nervioso central.

---

### 📋 Distribución de Tareas por Grupo e Integrante

#### 🛰️ GRUPO 1: Investigación Biomédica, Triage Clínico y Datos (Grupo de 3)
*Foco principal:* Modelado fisiopatológico, umbrales de radiación de la NASA, árbol de decisiones clínicas y telemetría médica sintética.

* **Integrante 1 (Investigación Biomédica & Datos NASA):**
  - **Tarea 1.1:** Investigar y documentar los límites de dosis de radiación de la NASA (mSv acumulados diarios, por misión y límites de por vida ajustados a los estándares de NASA/NCRP).
  - **Tarea 1.2:** Crear en `DB/` los esquemas y datasets sintéticos de telemetría de radiación (`radiation_telemetry.json` y `dose_logs.json`) con escenarios de: radiación basal en espacio profundo, alerta por tormenta solar (SPE) y exposición acumulada en EVA.
  - **Tarea 1.3:** Organizar en `sources/medical/` y `sources/nasa/` los papers y guías oficiales de radiación del Human Research Program (HRP).

* **Integrante 2 (Lógica Clínica, Triage & Árboles de Decisión):**
  - **Tarea 2.1:** Diseñar el árbol de decisiones clínicas y triage para radiación: clasificar síntomas iniciales de sobreexposición (náuseas, cefalea, eritema cutáneo, fatiga extrema, leucopenia).
  - **Tarea 2.2:** Definir los 3 niveles de severidad médica:
    - 🟢 **Verde (Bajo / Normal):** Exposición controlada, monitoreo pasivo de dosímetro.
    - 🟡 **Amarillo (Atención / Pre-Alerta):** Incremento de tasa de dosis ($> 1\,\text{mSv/h}$) o pico por aproximación de evento solar; recomendación de limitar EVA.
    - 🔴 **Rojo (Crítico / Emergencia):** Evento SPE activo o dosis aguda ($> 250\,\text{mSv}$); orden inmediata de retiro al refugio blindado de tormenta (*storm shelter*) y protocolo médico de soporte.
  - **Tarea 2.3:** Redactar en `assets/guides/radiation_safety.md` el manual de autotratamiento y contramedidas (hidratación, uso de antioxidantes/fármacos de mitigación y blindaje con agua/combustible).

* **Integrante 3 (Validación de Calidad, Casos de Prueba & Storytelling):**
  - **Tarea 3.1:** Validar que los algoritmos de alerta y el triage no dependan de llamadas de red (prueba 100% offline).
  - **Tarea 3.2:** Diseñar los casos de prueba médicos: simular un astronauta en caminata espacial (EVA) alcanzado por una tormenta solar para comprobar la respuesta del software.
  - **Tarea 3.3:** Elaborar la narrativa y el storyboard del pitch demostrando cómo AstraMed salva la vida de la tripulación ante un pico crítico de radiación espacial.

---

#### 💻 GRUPO 2: Arquitectura Core, UI/UX Espacial y Visualización Frontend (Grupo de 3)
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

## 🚀 Próximos Problemas Generales por Implementar / Resolver (Backlog Clínico)

Una vez consolidado el módulo de radiación espacial, el equipo abordará los siguientes 2 problemas clave de salud en vuelos espaciales de larga duración (completando los 3 problemas prioritarios del sistema):

---

### 🩸 Problema 2 (Siguiente en Pipeline): "Desacondicionamiento Cardiovascular y Redistribución Cefálica de Fluidos en Microgravedad"
* **Contexto del Peligro NASA:** *Gravity Fields (Microgravedad y Transiciones Gravitatorias)*.
* **Fisiopatología:** Al cesar la gravedad terrestre, la sangre y los fluidos corporales migran desde las extremidades inferiores hacia el tórax y la cabeza (*cephalic fluid shift* o síndrome de "cabeza hinchada"), provocando congestión facial, elevación transitoria de la presión intracraneal, disminución del volumen plasmático circulante y remodelado miocárdico. Esto causa intolerancia ortostática severa, mareos y riesgo de síncope al aterrizar en Marte o la Luna.
* **Métricas e Indicadores Clave:** Frecuencia cardíaca (HR en bpm), Presión Arterial sistólica/diastólica (mmHg), saturación de oxígeno ($SpO_2$), variabilidad de la frecuencia cardíaca (HRV) y volumen diario de ingesta hídrica.
* **Asignación General de Tareas:**
  - **Grupo 1 (Biomédica & Triage):** Diseñar el árbol de triage para eventos de hipotensión/arritmia en cabina, definir umbrales de alerta y crear el dataset de telemetría cardiovascular en reposo y ejercicio en `DB/`.
  - **Grupo 2 (Core, UI/UX & Frontend):** Diseñar la visualización del flujo hemodinámico en el avatar interactivo, gráficos en tiempo real con `fl_chart` y guías animadas de contramedidas (ejercicios de compresión y rehidratación con sales).

---

### 🦴 Problema 3 (Siguiente en Pipeline): "Pérdida de Densidad Mineral Ósea y Atrofia Musculoesquelética"
* **Contexto del Peligro NASA:** *Gravity Fields & Hostile Closed Environments (Desuso y Microgravedad Prolongada)*.
* **Fisiopatología:** La ausencia de carga gravitacional induce una pérdida acelerada de masa ósea (1% a 1.5% mensual en pelvis, fémur y vértebras lumbares) debido a la hiperresorción osteoclástica y calciuria elevada (lo que incrementa el riesgo de nefrolitiasis / cálculos renales), junto a una rápida atrofia de los grupos musculares posturales y extensores.
* **Métricas e Indicadores Clave:** Cumplimiento diario de ejercicio resistivo (ARED) y aeróbico (minutos y kilocalorías), balance de calcio/nutrición, fuerza muscular estimada y escala subjetiva de dolor lumbar o articular.
* **Asignación General de Tareas:**
  - **Grupo 1 (Biomédica & Triage):** Modelar la cinética de pérdida ósea según el tiempo de vuelo, protocolo de alertas por hipercalciuria/cálculos renales y pautas de prescripción de ejercicio.
  - **Grupo 2 (Core, UI/UX & Frontend):** Desarrollar el sistema de **gamificación y rutinas periódicas** (misiones diarias de salud), mapa corporal con degradación ósea/muscular por zonas y registros persistentes en Hive/Isar.
