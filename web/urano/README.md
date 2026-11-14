# URANO · Módulo de análisis de orina de AstraMed

**URANO** = **U**nidad de **R**astreo y **A**nálisis **N**efrológico **O**rbital.


Con cada muestra de orina, la app calcula el estado de 8 sistemas del cuerpo de cada astronauta y le da recomendaciones personalizadas:

| Módulo | Biomarcadores |
| --- | --- |
| Hidratación | volumen 24 h, densidad, osmolalidad, color |
| Riesgo renal (cálculos) | calcio, oxalato, citrato, ácido úrico, pH, volumen |
| Salud ósea | NTx, CTx |
| Radiación | 8-OHdG, isoprostanos (+ dosis del dosímetro) |
| Inmunidad | leucocitos, nitritos, sangre |
| Cardiovascular | sodio, potasio, relación Na/K, albúmina/creatinina |
| Estrés y sueño | cortisol libre, 6-sulfatoximelatonina |
| Metabolismo | glucosa, cetonas, proteína, urea, creatinina |

Es una página web dentro de AstraMed: se abre desde el botón de matraz (🧪) en la barra superior de la versión web de la app, o directamente en `/urano/`. Funciona 100 % offline: las fuentes y los datos demo vienen incluidos.

## Estructura

```
web/urano/index.html             la página
web/urano/styles.css             estilos (paleta, tipografía, animaciones)
web/urano/fonts/                 Inter y Space Grotesk locales (licencia OFL)
web/urano/js/config.js           ← aquí eliges de dónde salen los datos
web/urano/js/db.js               capa de datos: biomarcadores, datos demo y conectores
web/urano/js/core.js             módulos, cálculo de estados, gráficas
web/urano/js/pages1-4.js         pantallas
DB/schemas/urano_schema.sql      tablas (PostgreSQL / Supabase)
DB/samples/urano_seed.sql        datos demo de los 5 tripulantes (40 muestras cada uno)
tools/urano_api/                 API REST de referencia (Node + PostgreSQL)
```

## Cómo correrla

**1. Solo la demo (sin base de datos).** Corre la app con `flutter run -d chrome` y toca el botón de matraz, o abre `web/urano/index.html` directamente en el navegador. Usa los datos de demostración incluidos en `js/db.js`. Los tripulantes que agregues en este modo se guardan en tu navegador.

**2. Con PostgreSQL y la API incluida**
```bash
createdb urano
psql urano -f DB/schemas/urano_schema.sql -f DB/samples/urano_seed.sql
cd tools/urano_api && npm install
DATABASE_URL=postgres://USUARIO:CLAVE@localhost:5432/urano npm start
```
En `web/urano/js/config.js` pon `mode: 'rest'` y abre http://localhost:8000/urano/.
Para servir también la app Flutter compilada: `flutter build web` y arranca la API con `STATIC_DIR=../../build/web`.

**3. Con Supabase**
1. En el SQL Editor de tu proyecto, ejecuta `DB/schemas/urano_schema.sql` y después `DB/samples/urano_seed.sql`.
2. En `web/urano/js/config.js` pon `mode: 'supabase'`, la URL del proyecto y la clave `anon`.
3. Abre la página.

> `urano_schema.sql` abre lectura y escritura a la clave pública para facilitar el hackathon. No lo uses así con datos médicos reales.

Si la conexión falla, la app sigue funcionando con los datos demo y muestra un aviso. En el menú lateral y en el perfil se indica qué fuente se está usando.


## Uso y diseño

- **Sin pantalla de inicio:** la app abre directo en el panel del último tripulante usado. Para cambiar de tripulante se toca la flecha junto a su nombre: en computador aparece una lista desplegable y en celular una hoja inferior.
- **Personalizar:** el botón con el ícono de controles activa el modo de edición, tanto en el panel como en las páginas de módulo.
  - Las secciones se arrastran por el asa ⋮⋮ (funciona con mouse y con el dedo).
  - Como alternativa al arrastre, cada sección tiene flechas para moverla y un ojo para ocultarla.
  - Las tarjetas de módulos también se pueden reordenar.
  - El orden se guarda por tripulante en el navegador, y «Restablecer» vuelve al orden original.
- **Multiplataforma:**
  - **Celular (≤ 760 px):** barra de pestañas inferior (Panel, Muestra, Consejos, Historial, Perfil) y encabezado con el tripulante y las alertas.
  - **Tablet:** barra lateral compacta.
  - **Computador:** barra lateral completa.
- **Pautas aplicadas:**
  - Apple HIG: 3 a 5 pestañas, botones de al menos 44 pt, alternativa al arrastre, estado indicado con color, ícono y texto a la vez.
  - mobile-native: hover solo con mouse, sin destello al tocar, `dvh` en lugar de `vh`, áreas seguras, `touch-action: manipulation`, campos de 16 px para evitar el zoom, sin pull-to-refresh.
  - Hay que probarla en un celular real: el emulador no reproduce el notch, el teclado ni la sensación del tacto.


## Diseño para cabina (Rol 2 · UI/UX & Motion)

- **Código de color de emergencia:** verde = Estable, amarillo = Atención, rojo = Crítico (`SC` en `js/core.js`). Siempre va acompañado de ícono y texto, nunca solo color.
- **Modo cabina (alto contraste):**
  - Se activa en Perfil → Preferencias, o solo si el sistema operativo pide más contraste.
  - Fondo casi negro y texto blanco puro, pensado para poca luz.
- **Cuerpo humano interactivo:** está en el panel. Es una silueta anatómica con cada órgano en su lugar y su nombre y estado escritos al lado. Cada órgano se pinta con el estado de su módulo, y los que necesitan atención laten. Al tocar uno aparece su ficha con el valor clave y el acceso al módulo.
  - Cerebro → Estrés y sueño
  - Ganglios → Inmunidad
  - Corazón → Cardiovascular
  - Estómago → Metabolismo
  - Riñones → Riesgo renal
  - Vejiga → Hidratación
  - Huesos → Salud ósea
  - Piel y ADN (sol) → Radiación
- **Nueva muestra con cuenta regresiva:** se muestra en vivo en el panel (primer bloque), en el botón superior, en el menú, en la pestaña del celular y en la página de muestra.
  - Indica "Es hora de tu muestra" si hay una pendiente, o el tiempo que falta para la siguiente.
  - El horario sale de `mission.sample_times` (por defecto 07:30 y 15:30).
- **Agua y ejercicio con valor personalizado:** en el panel se registra el agua con el vaso (+250 ml), con atajos (150, 330 y 500 ml) o escribiendo cualquier cantidad entre 50 y 2000 ml. El ejercicio se registra eligiendo el tipo (fuerza, bicicleta o cinta) y los minutos (atajos o de 1 a 300). La fuerza también suma a las sesiones semanales de Salud ósea. Las metas diarias se cambian en Perfil, y con base de datos se guardan en `water_log` y `exercise_log`.
- **Guías animadas** (`js/guides.js`): cuatro procedimientos de 4 pasos con animaciones SVG que funcionan sin internet.
  - Las guías son: cómo tomar la muestra, cómo leer la tira reactiva, refugio ante tormenta solar, y dolor lumbar intenso (primeros auxilios).
  - Se abren desde Consejos, desde la página de muestra, desde cada módulo relacionado y desde las alertas.
  - Para usar animaciones **Lottie** exportadas por el equipo, agrega `lottie:'ruta/archivo.json'` al paso y carga `lottie-web`: el reproductor las usa en lugar del SVG.

## Cómo se calcula todo

- Cada **muestra** es una fila en `samples` y cada valor medido es una fila en `sample_values` (`biomarker_id` + `value`).
- El **rango personal** de cada biomarcador sale de `personal_ranges`. Si no hay fila, se usa el rango por defecto de `biomarkers`.
- **Estado de un biomarcador:**
  - **Normal** si está dentro del rango.
  - **Atención** si está fuera del rango.
  - **Crítico** si supera el límite alto en más de 35 % o queda por debajo del 65 % del límite bajo.
  - En los biomarcadores de tipo booleano, un **1 (positivo)** cuenta como Atención.
- **Estado de un módulo:** el peor estado entre sus biomarcadores.
- **Resultados:** se compara la última muestra con la anterior para mostrar qué cambió.
- **Gráficas e historial:** salen de todas las muestras guardadas del tripulante.

**Tripulantes nuevos:** se agregan desde el menú del perfil (la flecha junto al nombre del tripulante activo, arriba a la izquierda o en el encabezado del celular). Empiezan sin muestras, y su primera muestra crea la línea base. En modo demo la app simula esa muestra; con base de datos, el contexto llega a `sample_requests` y la muestra aparece cuando el equipo de cálculos la inserta.

**Para el equipo de cálculos:** basta con insertar muestras nuevas en `samples` y `sample_values`, y las recomendaciones y alertas en sus tablas. La app recalcula estados, gráficas y cambios por sí sola. Cuando alguien registra una muestra desde la app, el contexto (volumen, líquidos, síntomas…) se guarda en `sample_requests` para que lo procesen.

## API REST (si usan su propio backend)

| Método | Ruta | Respuesta / cuerpo |
| --- | --- | --- |
| GET | `/api/crew` | `[{id, name, role, initials, color, age, weight, height, dose, hr, bp, water, waterGoal, sleep, sessions, energy, protein, mood}]` |
| GET | `/api/mission` | `{name, day, total, doseLimit, start, events:[{day, cls}]}` |
| POST | `/api/crew` | tripulante nuevo (mismo formato) |
| GET | `/api/crew/:id` | un tripulante (mismo formato) |
| GET | `/api/crew/:id/samples` | `[{id, day, takenAt, method, values:{vol:1.4, ca:290, ...}}]` |
| GET | `/api/crew/:id/recommendations` | `[{id, module, priority, text, why, done}]` |
| GET | `/api/crew/:id/alerts` | `[{id, severity, module, title, cause, action, time, status}]` |
| GET | `/api/crew/:id/ranges` | `{ca:{lo, hi}, ...}` |
| PATCH | `/api/recommendations/:id` | `{done}` |
| PATCH | `/api/alerts/:id` | `{status:'resolved'}` |
| POST | `/api/crew/:id/water` | `{ml}` |
| POST | `/api/crew/:id/samples` | contexto de la muestra nueva |

## Tripulación demo

| Tripulante | Rol | Problema en los datos |
| --- | --- | --- |
| Ana Torres | Comandante | Hidratación baja y riesgo renal (calcio y oxalato altos, citrato bajo) |
| Leo Park | Ingeniero de vuelo | Resorción ósea alta (NTx, CTx) |
| Sami Okoye | Oficial médica | Estrés y sueño (cortisol alto, melatonina baja) |
| Mateo Rojas | Especialista de misión | Radiación: daño oxidativo crítico tras una caminata espacial (8-OHdG) |
| Yuki Tanaka | Piloto | Posible infección urinaria (nitritos positivos, leucocitos altos) |

Los valores son simulados para la demo. Los rangos deben validarse con el equipo de cálculos antes de usarse.
