# BARRELS — instrucciones y continuidad para Claude

Actualizado: 30 de octubre de 2026. Entrega 1.4.0: agua y anatomía mejoradas.
Trabaja sobre este proyecto existente.
Esta guía registra el estado del traspaso; verifica los cambios posteriores con
Git y los informes antes de asumir que una prueba o publicación sigue vigente.

## 1. Ubicación y preferencias del usuario

- Proyecto: `A:\PROYECTOS 3D GODOT\barrels-`; entrada: `project.godot`.
- Conversa en español, implementa lo solicitado y conserva las funciones existentes.
- Reutiliza esta guía y los archivos identificados. Inspecciona las partes necesarias
  para la tarea; no repitas una auditoría completa ni reconstruyas sistemas útiles.
- Muestra capturas reales ingame al entregar cambios visuales. Los bocetos o imágenes
  generadas deben identificarse como tales; no sustituyen una validación en Godot.
- No generes APK, AAB ni exportación web automáticamente por cada cambio. Consulta
  antes, salvo autorización explícita vigente para esa entrega.
- Autorización de la entrega ya completada: «Continuar y crear APK subir al github», del 30 de octubre.
  La entrega 1.3.0 ya se completó. Consulta antes de otra compilación o publicación.
- Conserva datos y cambios locales. No uses reset/clean/force-push para simplificar
  una entrega. No publiques claves, contraseñas, SDK, cachés ni capturas en el repo.

## 2. Proyecto y compatibilidad

Godot **4.7.2**, renderizador **Compatibilidad** (GLES3/WebGL2), 3D, Android y web.
Escena principal: `scenes/main.tscn`. Autoloads: Ajustes, Controles y Perfil.
Orientación horizontal, teclado WASD/flechas, táctil y mando.

Spots existentes:
- Montañita, La Punta: derecha.
- La Rinconada, Manabí: derecha tubular y potente.
- La FAE, Salinas: izquierda, con series y entorno de base aérea.

No cambies a Forward+/Mobile ni añadas efectos que requieran otro renderizador.
El objetivo de 30 FPS en móvil sigue siendo un objetivo pendiente de medir en teléfono.
No se puede afirmar compatibilidad con todos los Android; se requiere GLES 3.0.

## 3. Estado de funciones

Ya funcionan remada, incorporación, equilibrio, giros, caída, cámara, flotación,
tubo, puntuación, retos, récords, carrera, audio, calidad y controles configurables.

Cambios recientes que debes preservar:
- Bombeo rítmico, snap validado por trayectoria, floater sobre la rotura.
- Vuelo con gravedad, aéreos con agarre y 180°, recepción y continuación en switch.
- El aéreo/floater puntúa después de aterrizar. Una caída descarta el premio pendiente.
- Agarre de canto en el tubo, mano en el agua para frenar y salida con bonus validado.
- Flujo, ventana de combo y penalización por repetir familia de maniobras.
- REMAR/PARARSE pasan a IMPULSO/TRUCO al surfear; conservan sus reasignaciones.
- Menú de personalización rehecho con pestañas APARIENCIA, ROPA y TABLA.
- Cuatro estilos y dos prendas por estilo. Cambiar ropa ya NO borra `style_id`.
- Piel y cabello configurables, vista inferior de la tabla y guardado automático.
- Los colores con NV mantienen el requisito de nivel; no son botones averiados.

## 4. Mapa de archivos para continuar

| Área | Archivos |
| --- | --- |
| Escena, modos y conexiones | `scripts/game.gd`, `scenes/main.tscn` |
| Superficie compartida física/render | `scripts/wave_model.gd`, `shaders/wave_common.gdshaderinc` |
| Agua, tubo y espuma | `scripts/water.gd`, `scripts/barrel.gd`, `shaders/water.gdshader` |
| Surfista y contactos | `scripts/surfer.gd` |
| Trucos, vuelo y recepción | `scripts/surf_tricks.gd` |
| Clasificación de giros | `scripts/surf_turns.gd` |
| Animación y cámara | `scripts/surfer_animator.gd`, `scripts/camera_rig.gd` |
| Perfil, colores y prendas | `scripts/profile.gd`, `scripts/surf_materials.gd` |
| Menús y personalización | `scripts/ui/menus.gd`, `scripts/ui/surf_customizer.gd` |
| Controles y HUD | `scripts/controls.gd`, `scripts/touch_controls.gd`, `scripts/hud.gd` |
| Puntos y progreso | `scripts/score.gd`, `scripts/spots.gd`, `scripts/profile.gd` |
| Modelos procedurales | `tools/build_assets.py`, `tools/build_styles.py`, `tools/build_summer.py` |

El rig tiene 19 huesos; los clips recientes suman 17. Los estilos comparten rig,
animaciones y rest pose: el juego intercambia la malla, no todo el esqueleto.
Variantes alternativas: `surfer_local_wetsuit.glb`, `surfer_pro_beach.glb` y
`surfer_retro_wetsuit.glb`. No las borres: permiten combinar ropa con identidad.

Mantén `WaveModel` como fuente de altura: no separes una ola decorativa de la física.
En vuelo no debe haber flotación, nueva espuma de contacto ni puntos de recepción.
Al salir de personalización se restauran surfista y leash; la tabla invertida es
solo una vista previa. El modo remar alternable no debe enclavar IMPULSO.

## 5. Herramientas disponibles en este PC

```text
Godot:  A:\CLAUDE\Herramientas\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe
Blender: A:\CLAUDE\Herramientas\blender-5.2.2-windows-x64\blender.exe
Python: C:\Users\Usuario\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe
GitHub: A:\CLAUDE\Herramientas\gh\bin\gh.exe
JDK: A:\CLAUDE\Herramientas\jdk-17
Android SDK: A:\CLAUDE\Herramientas\android-sdk
```

Para scripts Python usa explícitamente `encoding="utf-8"` al leer/escribir: la
configuración regional de Windows usa cp1252 y puede corromper acentos.
Los helpers y copias de seguridad bajo `A:\CLAUDE` son históricos; NO los ejecutes
a ciegas: algunos sobrescriben archivos o esperan una versión anterior del código.

## 6. Validación y capturas

Lee primero `VALIDACION_TRUCOS.md` y `VALIDACION_PERSONALIZACION.md` para conocer
el contexto de las pruebas. Otros informes `VALIDACION_*.md` son históricos.

Ejemplos PowerShell, desde la carpeta del proyecto:

```powershell
$godot = 'A:\CLAUDE\Herramientas\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --editor --import
& $godot --path . --resolution 1280x720 --fixed-fps 60 -- --qa --custom-test
& $godot --path . --resolution 1280x576 --fixed-fps 60 -- --qa --custom-test
& $godot --path . --resolution 1280x720 --fixed-fps 60 -- --qa --tricks-test --tricks-shots
& $godot --headless --path . --fixed-fps 60 -- --qa --styles-test
& $godot --headless --path . --fixed-fps 60 -- --qa --controls-test
& $godot --headless --path . --fixed-fps 60 -- --qa --features-test
& $godot --headless --path . --fixed-fps 60 -- --qa --turns-test
& $godot --headless --path . --fixed-fps 60 -- --qa --wake-test
& $godot --headless --path . -s res://tests/score_test.gd
& $godot --path . -- --qa --water-look-test --spot=1
& $godot --headless --path . --fixed-fps 60 -- --qa --bot --runs=1 --spot=0
```

Usa `--qa` para no modificar datos reales. Personalización utiliza
`user://custom-test.cfg`, eliminado al terminar; apariencias usan otro archivo aislado.
Las pruebas gráficas necesitan GPU; `water-look-test` no valida parámetros de shader
con el backend headless. Revisa los logs, no solo el código de salida ni RESULTADO OK.

Resultados anteriores al traspaso: personalización aprobada con clics, toques
simulados, arrastre y persistencia en dos formatos; 100 comprobaciones de trucos,
regresiones de controles/ropa/tubo y 3/3 olas aprobadas en PC RTX 4060.
Algunos procesos headless conservan avisos de 4–6 objetos ObjectDB al cerrar.
Android físico y una nueva ejecución web siguen pendientes; no los des por probados.

Capturas reales: `capturas/personalizacion/`, `capturas/trucos/`. Están ignoradas
por Git. Usa imágenes de la ejecución que corresponde a tus cambios y mira su
contenido antes de entregarlas. Para pruebas de puntero con viewport escalado,
convierte coordenadas mediante `get_viewport().get_final_transform()`; en escritorio
las pruebas de arrastre táctil habilitan `Input.emulate_touch_from_mouse` SOLO en QA.

## 7. GitHub, APK y firma

Repositorio: https://github.com/jaimeluzu2009-sketch/SURF-2026 (rama main).
Último commit de referencia previo a esta entrega: `479f353`. Los trucos y el menú
corregido estaban pendientes de commit al comenzar la entrega 1.3.0.
Comprueba el estado actual: esta nota no reemplaza `git status` ni el historial.

Versión preparada para esta entrega: **1.4.0**, Android versionCode **7**,
paquete `ec.barrels.surf`, minSdk 24, targetSdk 36, ABIs arm64/armeabi-v7a/x86_64.
Estos valores describen la configuración; no certifican cumplimiento Play Store.

Compila solo el formato autorizado:

```powershell
& .\tools\build_android.ps1 -Format APK
```

El script obtiene el nombre de versión de `export_presets.cfg`, configura temporales
y Gradle en A:, usa el almacén Windows-ROOT para TLS y restaura el entorno al salir.
La carpeta `android/build` y las plantillas deben existir en esta máquina; no están
incluidas en Git. La carpeta privada de firma es hermana del proyecto,
`barrels-claves`; el script lee la contraseña internamente. No imprimas su contenido,
no la pongas en comandos, documentos, chats, logs ni presets. Conserva la misma firma
para actualizar instalaciones anteriores. Certificado SHA-256 esperado:
`957425f97caee6d9e6f1d6bbd0b372acfc7f3bdf4cdff3fa3f3f03613f5a05ec`.

Antes de publicar: valida apksigner, zipalign con páginas de 16 KB, manifiesto,
versión, recursos nuevos y SHA-256 del APK. La instalación en un teléfono es una
prueba independiente. No sustituyas una release anterior; usa nueva versión/tag.
No subas APK al historial Git; publícalo como asset de una release con notas claras.
Incluye el commit que corresponde al artefacto y verifica el enlace público.

## 8. Cómo seguir sin perder el trabajo

1. Lee esta guía y los dos informes recientes; consulta el estado de Git.
2. Continúa con la solicitud concreta del usuario, conservando los cambios locales.
3. Ejecuta las pruebas pertinentes y captura ingame si hay cambios visuales.
4. Describe lo cambiado, las pruebas realmente ejecutadas y lo pendiente.
5. Actualiza los informes. Pide autorización para la siguiente exportación si no
   ha sido solicitada explícitamente; la aprobación de esta entrega no es permanente.

Pendientes reales: prueba humana en Android, calibrar sensibilidad y dificultad de
trucos en móvil, medir FPS reales y validar de nuevo en navegador cuando se autorice.
Esta guía no autoriza por sí sola nuevas funciones, compilaciones ni publicaciones.


## Pulido visual de 1.4.0

Agua sin hashes de ruido por celda; texturas simplex continuas, mipmaps y rugosidad
ajustada. Ocho surfistas anatómicos con datos gráficos MakeHuman CC0, colores,
pesos de cuello/pies y LOD de cerca corregidos; 19 huesos y 17 clips se conservan.
Lee `VALIDACION_AGUA_ANATOMIA.md` y `assets/models/APARIENCIAS.md`. Nuevo adaptador:
`tools/human_anatomy.py`; datos fuente/licencias en `assets/sources/makehuman/`.
Regenera las ocho combinaciones y conserva los datos fuente al trasladar el proyecto.
Pruebas nuevas: `--qa --anatomy-test` y capturas con `--qa --visual-polish-test`.
El usuario autorizó generar y subir el APK 1.4.0 y esta guía a GitHub.
Consulta RELEASE_1.4.0.md y la release v1.4.0 para comprobar el resultado publicado.
Android físico y web siguen pendientes. Consulta antes de futuras exportaciones.
