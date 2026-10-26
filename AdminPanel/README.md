# Admin Panel (IPA)

App iOS que muestra `Resources/admin.html` a pantalla completa.

- Las preguntas (eliminar key, banear, resetear...) salen como ventana flotante dentro de la app.
- Copiar key y exportar CSV/TXT usan el portapapeles y la hoja de compartir de iOS.

## Cómo generar el .ipa

1. Copia la carpeta `AdminPanel/` en la raíz de tu repositorio y el archivo
   `.github/workflows/build-admin-ipa.yml` en `.github/workflows/` del mismo repositorio.
2. Haz commit y push.
3. En GitHub: pestaña **Actions** -> **Build Admin Panel IPA** -> **Run workflow**.
4. Al terminar, descarga el artefacto **AdminPanel-ipa** (contiene `AdminPanel.ipa`).

El .ipa sale **sin firmar**: instálalo como el resto de tus IPAs (TrollStore, Sideloadly, etc.).

## Actualizar el panel

Reemplaza `Resources/admin.html` por la versión nueva y vuelve a ejecutar el workflow.
