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
