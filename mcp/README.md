# Servidor MCP de Google Drive / Google Docs (`mcp/`)

Este directorio contiene la configuración del servidor **Model Context Protocol (MCP)** para permitir que las herramientas y agentes de IA (Antigravity, Roo Code, Cline o Claude Desktop) interactúen directamente con tu Google Drive y Google Docs.

---

## 🔒 Seguridad Importante
Los archivos de credenciales (`credentials.json`, `token.json`, etc.) están **estrictamente ignorados en `.gitignore`** para evitar que se suban accidentalmente a GitHub.

---

## ⚙️ Pasos para Conectar tu Google Drive (Una sola vez)

Para que el servidor MCP pueda conectarse a tu Drive de manera segura mediante OAuth 2.0:

### 1. Activar la API de Google Drive en Google Cloud
1. Entra a [Google Cloud Console](https://console.cloud.google.com/).
2. Crea un proyecto nuevo (por ejemplo: `AstraMed-MCP`) o selecciona uno existente.
3. En el buscador superior, busca **Google Drive API** y haz clic en **Habilitar** (*Enable*).

### 2. Configurar la Pantalla de Consentimiento (OAuth Consent Screen)
1. En el menú lateral de Google Cloud Console, ve a **APIs y servicios** > **Pantalla de consentimiento de OAuth** (*OAuth consent screen*).
2. Selecciona **Externo** (*External*) y haz clic en **Crear**.
3. Completa los campos básicos:
   - Nombre de la app: `AstraMed MCP`
   - Correo electrónico de asistencia y datos de desarrollador: tu correo de Google.
4. En la pestaña **Usuarios de prueba** (*Test users*), haz clic en **Add users** y añade tu propia cuenta de correo de Google.

### 3. Crear las Credenciales (Desktop App)
1. Ve a **APIs y servicios** > **Credenciales** (*Credentials*).
2. Haz clic en **Crear credenciales** (*Create Credentials*) > **ID de cliente de OAuth** (*OAuth client ID*).
3. En tipo de aplicación, selecciona **App de escritorio** (*Desktop app*).
4. Asigna un nombre (ej. `MCP Desktop Client`) y haz clic en **Crear**.
5. Haz clic en **Descargar JSON** (*Download JSON*).
6. Renombra ese archivo descargado como:
   ```text
   credentials.json
   ```
7. Muévelo y pégalo dentro de esta carpeta:
   ```text
   Insterestelares/mcp/credentials.json
   ```

---

## 🚀 Cómo Iniciar la Autenticación

Una vez colocado el archivo `mcp/credentials.json`:
1. La primera vez que el servidor MCP se ejecute mediante:
   ```bash
   npx -y @modelcontextprotocol/server-gdrive
   ```
2. Se abrirá automáticamente una ventana en tu navegador pidiendo que inicies sesión con tu cuenta de Google y aceptes los permisos de acceso a Drive.
3. Se generará un archivo `token.json` local (también protegido por `.gitignore`).
4. A partir de ese momento, el agente podrá listar, leer y manipular tus documentos de Google Drive.
