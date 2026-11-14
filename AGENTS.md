# Guía y Reglas para Agentes de Inteligencia Artificial (AGENTS.md)

Este documento define el rol, las responsabilidades, los estándares de código y las directrices operativas para cualquier agente de IA (Gemini, Claude u otros colaboradores de IA) que participe en el desarrollo del proyecto **Insterestelares**.

---

## 🚀 1. Contexto del Proyecto

- **Iniciativa:** NASA Space Apps Challenge — *Interestelares*
- **Objetivo Principal:** Crear un software integral de monitoreo de salud para astronautas en misiones espaciales (*Health Monitoring Software for Astronauts on Space Missions*).
- **Enfoque:** Monitoreo en tiempo real, detección temprana de anomalías fisiológicas, gestión de telemetría médica en entornos extremos y soporte predictivo para la tripulación.

### 1.1 Contexto Oficial del Reto (Background)
> With rising investment in spacecraft technology and research, space missions have become more ambitious. NASA’s Artemis program recently accomplished a crewed lunar flyby, and NASA and others have plans to send humans to Mars in the future. With increasingly longer missions, astronauts will be more exposed to the hostile space environment, which brings both physical and mental health risks.
> 
> NASA’s Human Research Program has mapped the five hazards of human spaceflight, which are:
> 1. **Space radiation**
> 2. **Isolation and confinement**
> 3. **Distance from Earth**
> 4. **Gravity fields**
> 5. **Hostile closed environments**
> 
> These hazards can contribute to health problems such as immune system changes, bone density loss, cardiovascular events, inadequate nutrition, behavioral health conditions, and others. Astronauts must be capable of making health assessments on themselves during a mission, to prevent and treat health problems that may arise. Some useful health indicators are blood pressure, heart rate, blood sugar, body temperature, daily sleep hours, and mood.

### 1.2 Objetivos Oficiales (Objectives)
> Your challenge is to create a visual tool that helps astronauts assess their own health during space missions and provides guidance on treatments and health improvements. You may consider gathering data from the user through any kind of input—keyboard text, mouse clicks, or camera images, for example. Any kind of data can be used, as long as it represents a health indicator, such as blood sugar levels in mg/dL or ultrasound images.
> 
> You can use NASA’s Human Research Program resources, along with the publicly available resources from other space agencies, to understand how spaceflight hazards affect human health, and to decide which indicators are useful and how they can support a quick assessment:
> - Which measurements can be performed in space?
> - Why is an exam needed?
> - How do spaceflight hazards affect these health indicators?
> - When might a result warrant attention from the crew or from flight surgeons on the ground?
> - What actions can be taken to prevent a critical health condition?
> 
> User interface design plays an important role in presenting metrics and diagnosis clearly. You may consider taking advantage of animations and interactivity to present the information. For example, the software could display a human figure where each part of the body is clickable and displays information about its function and health status.

### 1.3 Consideraciones Potenciales (Potential Considerations)
> You may (but are not required to) consider the following:
> - **Entornos diversos:** Your tool could provide health insights for astronauts in different environments, such as a spacecraft, a space station, a rover, or a base on another planet or moon.
> - **Rutinas de medición:** Your tool could prompt astronauts to take measurements or complete specific actions from time to time as a part of the mission routine.
> - **Características destacadas:**
>   - A gamification system to help astronauts engage with tasks that support their health.
>   - Dynamic charts that show how astronaut’s health indicators change over time.
>   - Color coding that helps the astronaut interpret the status of a health indicator at a glance.
> - **Usabilidad sin asunciones médicas:** Do not assume that astronauts know everything about how to assess their health. Your tool could provide simple instructions and explanations covering measurements, health indicators, and risks.
> - **Fuentes y recursos:** For data and resources related to this challenge, refer to the Resources tab at the top of the page. More resources may be added before the hackathon begins.

---

## 🤖 2. Roles del Agente

El agente actuará siempre como un **copiloto de ingeniería y consultor multidisciplinario de alto nivel**, desempeñando tres funciones clave:

### A. Asesor de Código y Calidad de Software
- Proponer código limpio, tipado, modular, mantenible y con documentación concisa.
- Aplicar principios de programación defensiva: validación estricta de datos entrantes, manejo de errores robusto y pruebas unitarias/integración.
- Optimizar rendimiento y latencia, teniendo en cuenta que el software simula o procesa flujos continuos de telemetría médica.

### B. Asesor de Arquitectura de la Aplicación
- Guiar la toma de decisiones arquitectónicas (modularidad de componentes, separación clara entre presentación, lógica de negocio y persistencia de datos).
- Diseñar pensando en resiliencia: capacidad de funcionamiento offline/local (crítico para misiones en el espacio profundo con retrasos de comunicación).
- Recomendar estructuras escalables para alertas críticas, dashboards médicos y visualización interactiva de biometría.

### C. Asesor de Salud Espacial y Fisiología de Astronautas
- Aportar conocimiento biomédico aplicado a la vida en microgravedad y vuelos espaciales prolongados:
  - **Cardiovascular y hemodinámica:** Desacondicionamiento cardiovascular, redistribución de fluidos cefálicos.
  - **Radiación espacial:** Monitoreo de dosis acumuladas (partículas solares y rayos cósmicos galácticos).
  - **Sistema musculoesquelético:** Pérdida de densidad mineral ósea y atrofia muscular.
  - **Monitoreo ambiental y respiratorio:** Concentración de $O_2$, $CO_2$, temperatura y presión en cabina.
  - **Salud mental y cognitiva:** Calidad del sueño, ritmos circadianos, estrés de aislamiento y fatiga de la tripulación.
- Asegurar que los rangos de alerta médica y métricas biológicas modeladas tengan base científica coherente.

---

## 🔒 3. Reglas Estrictas de Control de Versiones (Git)

> [!IMPORTANT]
> **REGLA OBLIGATORIA SOBRE COMMITS Y COAUTORÍA:**
> 1. **NUNCA** añadir al agente de IA como co-autor ni colaborador en los mensajes de commit (está estrictamente prohibido incluir líneas como `Co-authored-by: Agent...` o firmas de IA).
> 2. Los commits deben pertenecer **exclusivamente al usuario**.
> 3. Redactar los mensajes de commit siguiendo el formato de **Conventional Commits** (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`), de manera clara, profesional y concisa.

---

## 📁 4. Manejo de Datos y Directorio `/DB`

- `DB/` contiene la **base de datos operativa y telemetría de la app**: datasets simulados/reales, esquemas SQL/NoSQL, archivos JSON/CSV y datos estructurados que consume la aplicación.
- No alterar formatos crudos en `DB/raw/` sin justificación; documentar transformaciones y esquemas en `DB/README.md`.
- Asegurar que cualquier módulo que lea o escriba en `DB/` maneje validación estricta de esquemas y tipos de datos.

---

## 📚 5. Base de Conocimiento y Fuentes (`/sources`)

- `sources/` contiene el **material de investigación, contexto y fuentes oficiales** que el equipo humano y los agentes consultan para fundamentar el desarrollo:
  - `sources/nasa/`: Guías oficiales del reto de la NASA, requerimientos, rúbricas y criterios de evaluación.
  - `sources/medical/`: Literatura científica, papers biomédicos, estudios sobre efectos de microgravedad y manuales de vuelo espacial.
  - `sources/telemetry/`: Especificaciones de biosensores y protocolos de adquisición de datos.
  - `sources/notes/` y `sources/links.md`: Apuntes del equipo, enlaces de referencia y decisiones del proyecto.
- **Instrucción para el Agente:** Siempre que diseñes algoritmos, alertas médicas o arquitectura, consulta y prioriza las fuentes depositadas en `sources/` para garantizar que la solución esté científicamente respaldada y alineada a las pautas de la NASA.

---

## 📝 6. Directrices del Usuario y Especificaciones del Proyecto

# 📄 Documento de Trabajo y Arquitectura de Agentes: *AstraMed / Space Health Engine*

### 6.1 Misión y Alcance del Proyecto
Desarrollar una aplicación en **Flutter** orientada a misiones espaciales de larga duración que opere bajo un modelo **100% Offline-First**. La app permite a los astronautas monitorear signos vitales, realizar autodiagnósticos médicos mediante árboles de decisión clínicos y aplicar tratamientos o procedimientos guiados por animaciones (Lottie/Rive) y documentación local cuando la conectividad con la Tierra no está disponible.

---

### 6.2 Pila Tecnológica y Estructura del Repositorio
* **Framework:** Flutter (Null-safe, compatible con Android, Web/Desktop).
* **Base de Datos / Persistencia Local:** `Isar` o `Hive` (NoSQL ultrarrápido en Flutter para almacenar perfiles, histórico de signos vitales y registros de triage offline).
* **Gestión de Estado:** `Riverpod` o `Provider` (modular y escalable).
* **Multimedia y Animaciones:** `rive` o `lottie` para motion graphics interactivos; `flutter_markdown` para guías médicas locales.
* **Estructura Modular (Feature-First):**
    ```text
    lib/
    ├── core/                # Configuración, temas, almacenamiento local base
    ├── features/
    │   ├── vitals/          # Monitoreo de signos vitales y alertas locales
    │   ├── diagnostics/     # Árboles de decisión y motor de autodiagnóstico
    │   ├── treatments/      # Guías de procedimientos, videos y animaciones
    │   └── knowledge_base/  # Visor Markdown y manuales de emergencia
    └── main.dart
    ```

---

### 6.3 Directrices de Desarrollo para los Agentes de IA

Cuando trabajemos juntos en la generación de código, seguiremos estas reglas estrictas:

#### A. Arquitectura Modular y Componentes Reutilizables
* Cada pantalla y widget debe ser **completamente responsive** (adaptable desde una tablet táctil de cabina hasta la pantalla de una laptop).
* No usar paquetes externos innecesarios que aumenten el tamaño de compilación o rompan la compatibilidad offline.

#### B. Enfoque Offline-First Estricto
* Ninguna pantalla o consulta médica puede depender de llamadas a APIs remotas o internet en tiempo real.
* Todos los manuales, guías de triage y animaciones deben estar empaquetados como **Assets locales** (`assets/guides/`, `assets/animations/`).
* Los datos ingresados por el astronauta se guardan localmente en la base de datos embebida y se sincronizan en cola (Queue) únicamente cuando se detecte una pasarela de comunicación con la Tierra.

#### C. Motor de Diagnóstico y Autotratamiento (Triage Espacial)
* Implementar una lógica basada en **reglas clínicas deterministas y árboles de decisión** (ej: protocolos de emergencia médica de la NASA adaptados a formato digital).
* La interfaz debe guiar al usuario mediante preguntas de síntomas escalonadas y arrojar:
    1. **Nivel de gravedad** (Código Verde, Amarillo, Rojo).
    2. **Pasos de autotratamiento inmediato** con animaciones o gráficos explicativos.
    3. **Medicamentos o suministros del kit de primeros auxilios** a utilizar (validando contra inventario local).

---

### 6.4 Plan de Trabajo por Fases (Hackathon Sprint)

* **Fase 1 (Estructura y Core):** Configurar el proyecto base en Flutter, la base de datos local (Hive/Isar) y el sistema de navegación responsive.
* **Fase 2 (Módulo de Signos Vitales y Vistas):** Pantalla de ingreso y monitoreo de métricas de salud con alertas visuales locales (umbrales de peligro).
* **Fase 3 (Módulo de Diagnóstico y Guías):** Implementación del árbol de decisiones médicas offline y el visor de manuales en Markdown con animaciones Lottie/Rive.
* **Fase 4 (Pulido y UI Espacial):** Modo oscuro de alta contraste (tipo cabina espacial), optimización de rendimiento y pruebas sin conexión a internet.

