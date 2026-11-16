# APOLO · Asistente de salud con mascota virtual (AstraMed)

APOLO es un chatbot con forma de perrito astronauta. Lee los resultados de las muestras de orina de cada tripulante y le cuenta, conversando, cómo está y qué hacer. Reemplaza a URANO, la primera versión de esta página.

Con cada muestra calcula el estado de 8 datos de salud:

| Círculo | Biomarcadores |
| --- | --- |
| Agua (hidratación) | volumen 24 h, densidad, osmolalidad, color |
| Riñones (riesgo de cálculos) | calcio, oxalato, citrato, ácido úrico, pH, volumen |
| Huesos | NTx, CTx |
| Radiación | 8-OHdG, isoprostanos (+ dosis del dosímetro) |
| Defensas (inmunidad) | leucocitos, nitritos, sangre |
| Corazón | sodio, potasio, relación Na/K, albúmina/creatinina |
| Sueño (estrés y sueño) | cortisol libre, 6-sulfatoximelatonina |
| Energía (metabolismo) | glucosa, cetonas, proteína, urea, creatinina |

Se abre desde el botón del perrito (🐾) en la barra superior de la versión web de AstraMed, o directamente en `/apolo/`. Funciona 100 % offline: las fuentes, los datos demo y el "cerebro" del chat vienen incluidos.

## Estructura

```
web/apolo/index.html             la página
web/apolo/styles.css             estilos y animaciones
web/apolo/fonts/                 Inter y Space Grotesk locales (licencia OFL)
web/apolo/js/config.js           ← aquí eliges de dónde salen los datos
web/apolo/js/db.js               capa de datos: biomarcadores, datos demo y conectores
web/apolo/js/core.js             íconos, módulos y cálculo de estados (verde/amarillo/rojo)
web/apolo/js/dog.js              el perrito (SVG animado: expresiones, parpadeo, orejas, boca)
web/apolo/js/app.js              interfaz: círculos, chat, tarjetas de detalle, menú
DB/schemas/urano_schema.sql      tablas (PostgreSQL / Supabase)
DB/samples/urano_seed.sql        datos demo de los 5 tripulantes (40 muestras cada uno)
tools/urano_api/                 API REST de referencia (Node + PostgreSQL)
```

La base de datos y la API conservan el prefijo `urano_` para no romper lo que ya estaba conectado.

## Cómo correrla

**1. Solo la demo (sin base de datos).** Corre la app con `flutter run -d chrome` y toca el botón del perrito, o abre `web/apolo/index.html` directamente en el navegador. Usa los datos de demostración incluidos en `js/db.js`. Los tripulantes que agregues en este modo se guardan en tu navegador.

**2. Con PostgreSQL y la API incluida**
```bash
createdb urano
psql urano -f DB/schemas/urano_schema.sql -f DB/samples/urano_seed.sql
cd tools/urano_api && npm install
DATABASE_URL=postgres://USUARIO:CLAVE@localhost:5432/urano npm start
```
En `web/apolo/js/config.js` pon `mode: 'rest'` y abre http://localhost:8000/apolo/.
Para servir también la app Flutter compilada: `flutter build web` y arranca la API con `STATIC_DIR=../../build/web`.

**3. Con Supabase**
1. En el SQL Editor de tu proyecto, ejecuta `DB/schemas/urano_schema.sql` y después `DB/samples/urano_seed.sql`.
2. En `web/apolo/js/config.js` pon `mode: 'supabase'`, la URL del proyecto y la clave `anon`.
3. Abre la página.

> `urano_schema.sql` abre lectura y escritura a la clave pública para facilitar el hackathon. No lo uses así con datos médicos reales.

Si la conexión falla, la app sigue funcionando con los datos demo y muestra un aviso.

## Cómo funciona

- **Apolo al centro:** el perrito flota en el centro con su globo de diálogo encima.
  - Su cara cambia con el peor estado del tripulante: feliz (estable), preocupado (atención), orejas caídas y sudor (crítico).
  - Se achica un poco mientras habla y vuelve a su tamaño al terminar.
  - Si lo tocas, mueve la cabeza y dice algo.
- **Círculos bajo pedido:** al abrir solo salen los datos en alerta.
  - Los demás salen del perrito cuando el tripulante pregunta por ellos ("¿cómo está mi agua?"), toca un botón del globo o pide "muéstrame todo".
  - "Solo lo urgente" los vuelve a guardar.
  - En pantalla ancha caben 8 (en zigzag a cada lado); en celular, 6.
- **Detalle:** al tocar un círculo se abre una tarjeta que crece desde él (en celular, una hoja inferior que se cierra arrastrando). Trae:
  - qué hacer, con casillas para marcar;
  - los biomarcadores con su rango personal;
  - la tendencia;
  - por qué importa en el espacio.

  En Agua y Huesos se registra agua o ejercicio con cantidades personalizadas.
- **Chat sin internet:** reglas simples en `app.js` (`ask()`). Entiende:
  - "¿cómo estoy?", "¿qué hago hoy?", "dame un consejo", "mi próxima muestra";
  - "tomé 2 vasos" / "tomé 500 ml";
  - "hice 30 minutos de ejercicio";
  - "¿por qué importa?";
  - el nombre de cualquier dato.
- **Voz:** el micrófono usa el dictado del navegador (Chrome/Edge). En el menú se puede activar que Apolo lea sus respuestas en voz alta.
- **Consejos:** Apolo solo da consejos cuando se le piden. Hay un interruptor opcional en el menú para consejos automáticos (apagado por defecto).
- **Muestra:** la píldora superior muestra la cuenta regresiva a la próxima toma (`MISSION.sampleTimes`) y se pone amarilla cuando toca.
- **Tripulantes:** con la flecha del perfil se cambia de tripulante o se agrega uno nuevo.

## Diseño para cabina (Rol 2 · UI/UX & Motion)

- **Space Cockpit Dark Mode:** fondo casi negro y texto honeydew (#F0FFF1). En el menú está el **modo cabina**, de alto contraste puro (negro y blanco). También responde a `prefers-contrast: more`.
- **Código de emergencia:** verde = Estable, amarillo = Atención, rojo = Crítico (`SC` en `js/core.js`). Siempre va con ícono y texto, nunca solo color. Los datos en alerta salen primero, más grandes y con un halo que pulsa.
- **Animación:** todo flota (círculos, globo, perrito y micrófono). Con `prefers-reduced-motion` todo queda quieto.
- **Responsive:**
  - Laptop y tablet horizontal: tres columnas (datos · Apolo · datos).
  - Tablet vertical: columnas más angostas.
  - Celular: el globo arriba, Apolo al centro y los círculos debajo.

  Se probó en 1512, 1440, 1280, 820 y 390 px de ancho.
- **Pautas (Apple HIG y mobile-native):**
  - botones de al menos 44 pt;
  - hover solo con mouse;
  - `dvh` y áreas seguras;
  - campos de 16 px para evitar el zoom;
  - foco visible y teclado (Esc cierra);
  - `aria-live` en el globo de diálogo.
