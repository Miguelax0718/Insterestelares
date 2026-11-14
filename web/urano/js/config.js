// Configuración de URANO dentro de AstraMed.
// mode: 'mock'     -> datos de demostración incluidos (100% offline, por defecto)
//       'rest'     -> API REST en restUrl (ver tools/urano_api)
//       'supabase' -> proyecto de Supabase (supabaseUrl + supabaseKey anónima)
window.URANO_DB = {
  mode: 'mock',
  restUrl: '/api',
  supabaseUrl: 'https://TU-PROYECTO.supabase.co',
  supabaseKey: 'TU_ANON_KEY',
};
// Enlace para volver a la app Flutter (raíz de la versión web).
window.URANO_BACK = '../';
