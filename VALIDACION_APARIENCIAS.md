# BARRELS 1.1.2: tres apariencias

Validación ejecutada el 29/10/2026 en Windows, Godot 4.7.2, Compatibility/OpenGL, GPU RTX 4060. APK: ec.barrels.surf, versionCode 4, versión 1.1.2, mínimo API24 y objetivo API36.

## Implementación
- Selector Surfista y tabla > Apariencia: Personalizado, Local tropical, Competidor técnico y Retro costero. Las tres nuevas apariencias se pueden usar desde el inicio y editar sus colores.
- Seis GLB originales (tres surfistas y tres tablas), generador tools/build_styles.py, notas de procedencia assets/models/APARIENCIAS.md.
- Perfil: catálogo y colores, guardado y recuperación, compatibilidad con conjuntos anteriores.
- Surfer: intercambio y caché de mallas, mismos huesos/animaciones, materiales existentes. Geometría por surfista: 4.858 / 3.794 / 4.298 triángulos.
- UI: selector y panel con desplazamiento. Vista previa alineada a la superficie y cámara que sigue su posición visual; evita que el paso de las olas oculte la tabla.
- Archivos modificados: scripts/profile.gd, scripts/surfer.gd, scripts/surf_materials.gd, scripts/ui/menus.gd, scripts/camera_rig.gd, scripts/game.gd, export_presets.cfg, tools/build_android.ps1 y LEEME.md. Nuevos: tools/build_styles.py, tests/styles_test.gd y recursos indicados.

## Pruebas ejecutadas
- Importación de seis modelos sin errores.
- tests/styles_test.gd: coincide el orden, nombre y transformación de reposo de los 19 huesos en cada variante; existen los nueve clips; se activan las mallas reales y las tablas correspondientes; colores disponibles desde nivel 1; personalizar conserva el modelo; guardar y recuperar en ConfigFile aislado funciona; se conservan ambos conjuntos anteriores.
- La tabla del selector queda sobre el agua en nueve puntos de contacto, en cinco momentos de la ola. La actualización de la vista previa no actúa fuera de la personalización.
- Ejecución gráfica del test y capturas reales de las tres apariencias desde la misma cámara. Resultado OK y sin errores ni advertencias en barrels-styles-visual.log.
- Tres partidas con el piloto automático: Local tropical/Montañita, Competidor técnico/La Rinconada, Retro costero/La FAE. Una ola completada en cada caso (3/3). Unas ejecuciones sin ventana aún avisan de 6 instancias ObjectDB al salir, advertencia ya observada en la versión anterior; no aparece en la prueba gráfica final.
- Exportación web final completada. Abierta en el navegador integrado con localhost:8067; selector probado con las tres opciones; elección Competidor técnico conservada tras recargar; inicio de partida manual con Retro costero en Montañita. Se observaron las mallas y tablas reales en pantalla. Esto no es una prueba de rendimiento en móvil ni una partida web completa.
- APK y AAB firmados generados. APK: apksigner verifica firma v2 y el certificado anterior; aapt confirma versión/código y SDK. AAB: jarsigner verifica el archivo, con la advertencia esperada de certificado autofirmado. Los seis modelos se encuentran en el contenido del APK.

## Entrega y límites
- build/android/barrels-1.1.2.apk
- build/android/barrels-1.1.2.aab
- build/web/index.html
- capturas/tres_apariencias/{local,pro,retro}_ingame.png y selector.png

Son modelos 3D simplificados derivados de las propuestas visuales, no imágenes 2D colocadas sobre el personaje ni copias fotográficas de los montajes. No se probaron en un Android físico y no se subieron a ninguna nube ni a Google Play. El enlace de archivo local no constituye una descarga pública para móvil.
