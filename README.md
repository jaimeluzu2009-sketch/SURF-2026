# BARRELS · Surf en Ecuador

Juego 3D de surf en Godot 4.7.2, renderizador Compatibilidad, para Android y navegador. Spots: Montañita, La Rinconada y La FAE.

## Descargar Android
[BARRELS 1.3.0 — APK](https://github.com/jaimeluzu2009-sketch/SURF-2026/releases/download/v1.3.0/barrels-1.3.0.apk) · [Release y checksum](https://github.com/jaimeluzu2009-sketch/SURF-2026/releases/tag/v1.3.0)

Android 7+ y OpenGL ES 3.0. APK firmado; todavía pendiente de validación en un teléfono físico.

## Abrir el proyecto
Abre `project.godot` con Godot 4.7.2 y conserva Compatibilidad. Espera la importación de GLB, fuentes y audio y ejecuta la escena principal. El código actualizado está en `main`.

Incluye tres apariencias y modo personalizado con ropa combinable, piel y cabello, aéreos/180°, bombeo, snap/floater, Flujo, animaciones, cámara ajustable, controles de teclado/táctil/mando, ola y tubo, bottom turn/carving/cutback con puntuación y combos, estela y gotas según carga del canto, personalización y progresión.

## Continuidad

Para continuar el desarrollo con Claude, lee [CLAUDE.md](CLAUDE.md). Estado y firma de esta entrega en [VALIDACION_1_3.md](VALIDACION_1_3.md).

## Validación
Consulta [LEEME.md](LEEME.md) y los archivos `VALIDACION_*.md`. Las pruebas están en `tests/`; sus capturas se generan localmente en `capturas/` y no se incluyen en Git.

Ejemplos (Godot disponible en PATH):
```sh
godot --headless --path . -- --qa --wake-test
godot --headless --path . -- --qa --turns-test
godot --path . -- --qa --spot=1 --water-look-test
```
Las pruebas de renderizado necesitan GPU. Las verificaciones realizadas hasta ahora son en PC; Android físico y las últimas modificaciones en navegador siguen pendientes.

## Android y firma
Los APK se publican como assets de las releases; no forman parte del historial Git. Para usar `tools/build_android.ps1`, configura `BARRELS_TOOLS` con la carpeta local de herramientas (Godot 4.7.2, JDK 17 y Android SDK) y `BARRELS_KEYS_DIR` con tu carpeta privada de firma. El script documenta la disposición esperada. Las plantillas de exportación oficiales deben estar instaladas, junto con la plantilla de compilación Android del proyecto (`android/build`, excluida de Git).

No se incluyen claves, contraseñas, SDK, cachés de Godot ni compilaciones. La carpeta de firma queda fuera del proyecto. Para conservar la compatibilidad con una aplicación instalada se necesita la misma clave de firma; cada desarrollador debe gestionar sus propias credenciales.

Los modelos se adaptan/generan con las herramientas de `tools/`; la nueva anatomía usa datos gráficos CC0 de MakeHuman. Las texturas de detalle son procedurales. Procedencia de recursos en `assets/models/APARIENCIAS.md`, `audio/PROCEDENCIA.md` y las licencias de `fonts/`.


Versión 1.4.0: agua continua y surfista anatómico. Ver
[VALIDACION_AGUA_ANATOMIA.md](VALIDACION_AGUA_ANATOMIA.md) y [RELEASE_1.4.0.md](RELEASE_1.4.0.md).
