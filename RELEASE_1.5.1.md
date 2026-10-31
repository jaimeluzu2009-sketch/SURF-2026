# BARRELS 1.5.1

Novedades respecto a 1.5.0:
- Menús: se puede deslizar con el dedo para bajar aunque empieces sobre un botón; los selectores abren al soltar.
- Controles táctiles: «Respuesta del joystick» (Suave/Normal/Directa) y joystick que sigue al pulgar.
- Modo asistido (Ajustes > Controles, activado por defecto en móvil): remada automática con la ola, más margen para pararse y ayuda de equilibrio.
- Olas más largas: la rompiente está 45 m mar adentro (~26 s de pie en vez de ~17 s).
- Ya no se puede remar tumbado hasta la arena: fuera del pico vuelves al lineup.
- Nuevo top turn; bombeo limitado por la energía de la ola; tubo puntuado por profundidad, control y salida; la recepción fallida explica el motivo; aviso «REPETIDO» al repetir maniobras.
- Academia en ESCUELA (lecciones 8-12): bombeo, bottom turn, top turn/cutback, impulso y recepción, tubo.
- Cerros y acantilados sin facetas; agua con más grosor en la cara; materiales menos plásticos.

Validación de desarrollo: Godot 4.7.2 Compatibilidad en Windows/RTX 4060, pruebas automáticas en los tres spots. No probado aún en teléfono físico ni en navegador. Android 7+ con GLES 3.0.

## APK verificado

- Paquete ec.barrels.surf, versión 1.5.1, versionCode 9.
- Tamaño: 234109038 bytes.
- SHA-256: 84dfc098d39278102ea60240d6a5e1ce82021ada3635d258c04393259047c151.
- Firma apksigner válida, mismo certificado que 1.4.0/1.5.0 (actualiza sin desinstalar).
- zipalign -c -P 16 4: aprobado. minSdk 24, targetSdk 36. ABIs arm64-v8a, armeabi-v7a, x86_64.

Descarga: https://github.com/jaimeluzu2009-sketch/SURF-2026/releases/download/v1.5.1/barrels-1.5.1.apk
