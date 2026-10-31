# BARRELS — instrucciones y continuidad para Claude

Actualizado: 30 de octubre de 2026. APK 1.4.0 publicado; instalación confirmada por el usuario.
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
- La entrega autorizada 1.4.0 ya se completó y publicó. Esta guía no autoriza otra
  compilación ni publicación. Consulta antes de generar APK/AAB/web o subir nuevas entregas.
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
El usuario confirmó que 1.4.0 ya se instala en su POCO F7 Pro. No confirmó todavía
una sesión completa de juego, FPS, controles ni las tres olas en ese teléfono.
Una nueva ejecución web sigue pendiente.

Capturas reales: `capturas/personalizacion/`, `capturas/trucos/`. Están ignoradas
por Git. Usa imágenes de la ejecución que corresponde a tus cambios y mira su
contenido antes de entregarlas. Para pruebas de puntero con viewport escalado,
convierte coordenadas mediante `get_viewport().get_final_transform()`; en escritorio
las pruebas de arrastre táctil habilitan `Input.emulate_touch_from_mouse` SOLO en QA.

## 7. GitHub, APK y firma

Repositorio: https://github.com/jaimeluzu2009-sketch/SURF-2026 (rama main).
Commit del código de la release 1.4.0: `a70c68cacbd62a1e30dbdd8d67b8e85ff8cf7673`.
Los cambios de esta guía son posteriores al APK; no implican una nueva compilación.
Comprueba el estado actual: esta nota no reemplaza `git status` ni el historial.

Versión publicada: **1.4.0**, Android versionCode **7**,
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

Pendientes reales: sesión de gameplay documentada en Android, calibrar sensibilidad y dificultad de
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
La instalación en POCO F7 Pro fue confirmada por el usuario. Gameplay medido en
Android y una nueva exportación/prueba web siguen pendientes. Consulta antes de futuras exportaciones.


## 9. Última conversación y siguiente trabajo

- Dispositivo del usuario: POCO F7 Pro; versión comunicada de HyperOS:
  `3.0.303.0.WOKMIXM.C09`. No se verificó por separado la versión de Android.
- Al instalar apareció «el paquete no es válido». El usuario eliminó la instalación
  anterior y comunicó un tamaño de descarga de aproximadamente 234 MB.
- Se revisó el APK: firma v2 válida, CRC ZIP correcto, recursos.arsc sin comprimir y
  alineado a 4 bytes, bibliotecas nativas sin comprimir y alineadas a 16 KB.
  La copia descargada desde GitHub tenía el mismo SHA-256 que el original.
- Después el usuario dijo «Ya funciona». Esto confirma resolución del bloqueo de
  instalación según su reporte. No atribuyas la solución a Chrome, a HyperOS ni a
  una modificación del APK: no indicó qué acción concreta resolvió el problema.
- No se cambió ni recompiló el APK durante ese diagnóstico.
- Solicitud actual atendida: actualizar esta guía para continuar con Claude.

Enlaces de la entrega ya publicada:
- Release: https://github.com/jaimeluzu2009-sketch/SURF-2026/releases/tag/v1.4.0
- APK: https://github.com/jaimeluzu2009-sketch/SURF-2026/releases/download/v1.4.0/barrels-1.4.0.apk
- Proyecto del tag: https://github.com/jaimeluzu2009-sketch/SURF-2026/archive/refs/tags/v1.4.0.zip
- SHA-256 APK: `d653af2c09c7488ab86007523e502ef2040d19f08124455d5023bed4e198a4a8`.
- Tamaño exacto: 234070994 bytes. Los enlaces públicos devolvieron HTTP 200 al publicar.
- El CLAUDE.md adjunto a la release es la guía de ese momento: esta actualización
  local es posterior. No supongas que el adjunto remoto está actualizado.

Próximo paso recomendado si el usuario solicita seguir: recoger resultados reales
sobre agua, anatomía, prendas, controles y una ola en cada spot desde su POCO.
Corregir únicamente los problemas reportados y medir rendimiento cuando exista
acceso a un dispositivo. No presentar FPS de RTX 4060 como FPS de móvil.
Mantener como límites conocidos el acabado simplificado del cabello/piel/entorno
 y la ordenación de transparencias del tubo. No prometer calidad fotorrealista.

Antes de editar: lee AGENTS.md, esta guía y el informe del área concreta, comprueba
`git status` y conserva cambios locales. No ejecutes helpers históricos sin leerlos.

Regla permanente del usuario: después de cada cambio, actualizar CLAUDE.md al finalizar, con cambios, pruebas y pendientes reales.


## 10. Cámaras, tubo, posturas y mando (local, posterior a 1.4.0)

Regla permanente: después de CADA cambio actualizar esta guía al finalizar.
Solicitud: tres POV, pulir tubo 3D, posturas adaptadas, ideas de interfaz táctil,
y soporte de mando al jugar en web. Implementación y resultados detallados en
`VALIDACION_CAMARAS_MOVIMIENTO.md`; leerlo antes de continuar estas áreas.

- Ajustes.camera_view: 0 tercera persona, 1 primera persona, 2 frontal; guardado
  en ajustes. Cambiar con C, R3, Ajustes > Controles o botón CÁMARA táctil.
- CameraRig oculta solo la malla del cuerpo en primera persona y la restaura al
  salir de ese modo/abrir personalización. Sigue cabeza animada y conserva rig.
- WaveModel.tube_section ahora varía radios de forma suave por longitud/tiempo;
  usarla tanto para malla como para techo físico. No duplicar fórmula en otro sitio.
- SurferAnimator.tube_compression proviene del espacio al techo; mezcla posturas
  existentes. Se ampliaron correcciones de torso, cabeza y brazos por maniobra.
- Controles conecta gamepad_changed/gamepad_lost, navegación UI y R3. La pérdida
  del último mando pausa la partida. Detección/ayuda visible en ajustes.
- Nueva prueba: `--qa --camera-motion-test` (GPU para capturas).
- Pasaron cámara/movimiento, controles, trucos, características, polish y techo
  de tubo; piloto 3/3 olas. Algunas pruebas headless mantienen avisos ObjectDB.
- Capturas: `capturas/camaras_movimiento/`; no incluirlas por defecto en Git.
- No hay prueba de mando físico en navegador ni móvil de estos cambios. No llamar
  a esto compatibilidad web certificada; los eventos de mando se probaron sintéticos.
- Ideas táctiles pendientes de elección: pulir dos botones contextuales (recomendada),
  modo práctica con ayudas o editor de posiciones/opacidad. Detalles en el informe.
- NO se exportó APK/AAB/web ni se publicó. 1.4.0 continúa como APK público anterior.
  Solicitar autorización antes de exportar o publicar otra entrega.


## 11. Interior de tubo, botones táctiles y propuesta de tutorial (local)

Leer VALIDACION_TUBO_TACTIL.md para cambios y pruebas. Regla vigente: actualizar
esta guía al final de cada cambio, sin generar/publicar APK/AAB/web automáticamente.

- WaveModel.tube_roof(section,z) es ahora la fuente común del arco asimétrico y
  la altura de techo; Barrel usa esa función. No restaurar el antiguo arco sin
  cambiar juntos malla/colisión. water-look-test valida coincidencia <5 mm.
- Material del tubo distingue interior por signo de normal y vista; opacidad más
  alta en interior y espuma menos rayada. Mantiene una sola superficie.
- TouchControls redibujado con doble contorno, subtexto contextual, porcentaje,
  anillo y aviso SUELTA. Mismos IDs táctiles y áreas de toque. Campo launch_ready
  recibe SurfTricks.launch_available, que verifica requisitos y cooldown.
- MIN_AIR_CHARGE=0.18: valor previo del gameplay centralizado, no nueva dificultad.
- Ajustes.touch_opacity guardado en controles/opacidad, rango .35–1, default .8;
  alto contraste mantiene alfa mínimo .85. Restablecer controles restaura .8.
- Nueva prueba --qa --tube-touch-test (GPU para capturas); config aislada
  user://tube-touch-test.cfg, eliminada al terminar. No usar ajustes reales en QA.
- Pasaron: prueba tubo/táctil, water-look, tricks, features, controls, polish,
  camera-motion y pilotos 3/3 spots. Avisos ObjectDB headless conocidos permanecen.
- Un mando fue detectado durante QA. La prueba de pérdida no debe asumir lista
  vacía; probar por separado que un mando restante no pausa y que gamepad_lost sí.
- Capturas: capturas/tubo_controles/. Estados controlados de la escena real.
- Tutorial solicitado como ideas/diseño: docs/TUTORIAL_DISENO.md define Escuela
  del Pacífico, dos rutas, 16 lecciones, talleres, UI y criterios de validación.
  NO hay todavía modo tutorial jugable ni entrada de menú funcional.
- No se exportó ni publicó. El APK GitHub 1.4.0 no contiene estas mejoras locales.
- Pendientes: confirmar diseño tutorial y después implementar la ruta inicial;
  evaluar interior de tubo y lectura de botones en POCO F7 Pro, probar web/mando
  y medir FPS en dispositivo cuando esté disponible y se autorice exportar.


## 12. Escuela jugable, PC y primera persona — estado local más reciente

Leer primero VALIDACION_ESCUELA_PC.md. Esta sección sustituye las notas anteriores
que describían todo el tutorial como pendiente o toda la malla oculta en primera persona.

- Menú > ESCUELA: ruta inicial «Mi primera ola» con siete lecciones y resultados,
  progreso/repetición. scripts/surf_school.gd coordina estados reales, sin duplicar
  movimiento ni física. Usa el spot actual y condición limpia; checkpoints de pie
  solo para equilibrio/giro. Academia avanzada/tubo/talleres aún NO implementados.
- Escuela guarda progreso en user://surf_school.cfg, formato 1. Game desvía
  resultados ANTES de Perfil.record_ride: no conceder XP ni récords de carrera.
- Pausa, reintento, perder ola y salida restauran estado. El overlay escolar DEBE
  procesar ALWAYS porque el mundo se pausa en resultados. Verificar botones con
  clics/eventos reales, no solo con pressed.emit(). Escape vuelve al selector.
- scripts/settings.gd: F11/Alt+Enter, fullscreen y tamaños de ventana hasta
  1920×1080 (limitados por espacio del escritorio). Base UI sigue 1280×720;
  salida/3D no están fijados a 720p. ui/display_info.gd actualiza tamaño de ventana,
  framebuffer y escala real. No confundir tamaño lógico/DPI con píxeles renderizados.
- F11 está reservado; no permitir asignarlo a otra acción. Las preferencias se
  guardan, pero cambios de audio/calidad no deben forzar el tamaño de ventana.
- Caída: Surfer._fall_orientation se captura una vez. La pose usa tiempo absoluto,
  no multiplicar otra vez el tumble sobre el transform del frame anterior. Se
  limpia velocidad y estados al reset; no reentrar a WIPEOUT/DONE.
- FirstPersonBody genera/cacha brazos filtrados de cada malla, mismo skeleton/skin
  y materiales, sin cabeza/torso/piernas. No exportar modelos nuevos para ello ni
  perder las variantes. CameraRig orienta hacia la cubierta y tabla original.
  FOV 88° tumbado/82° de pie y near .04; revisar clipping desde más maniobras.
- HUD oculta desafíos en primera persona y retos/puntuación competitiva en escuela.
- Nueva prueba --qa --school-test (GPU para capturas); --school-layout prueba
  formato 1280×576. Configs aisladas school-test.cfg y school-settings-test.cfg.
- Pasaron siete lecciones con piloto/física en Montañita; guardado y aislamiento
  de carrera; pausa, reintentos, clics GUI y Escape; ocho estilos/ropa de brazos;
  caída 30/60/120 Hz y F11/Alt+Enter reales. También regresiones controls, tricks,
  features, polish, camera-motion y anatomy. Persisten avisos ObjectDB headless.
- Capturas: capturas/escuela_pc/ y capturas/escuela_pc_576/. Son del motor real;
  las de remada usan poses controladas para comparar dos fases del ciclo.
- Pantalla completa informó ventana 1920×1080 y framebuffer 2880×1620 en este
  entorno, escala3D 1.0. No describirlo como prueba universal de 1080p.
- No se probó nueva versión en móvil físico ni navegador; no se generó ningún
  APK/AAB/web/ejecutable ni se subió GitHub. APK público sigue 1.4.0 anterior.
- Pendiente: calibrar tutorial con personas y otros spots, academia avanzada,
  controles/mando en navegador y móvil, medir FPS y revisar primera persona en
  todas las maniobras. Consultar antes de futuras compilaciones/publicaciones.

Regla del usuario vigente: al finalizar cada cambio, actualizar esta guía con
lo implementado, las pruebas realmente ejecutadas y los pendientes.


## 13. Release 1.5.0 publicada (31 oct 2026) — sustituye a 1.4.0 como APK público

El usuario autorizó compilar y publicar 1.5.0 con todo lo de las secciones 10–12.
- export_presets: version/name 1.5.0, version/code 8 (ambos presets Android).
- Commit de la release: `afe5cb5cfca77598815ace9c9c4460509f683c82` (main, empujado).
- Release: https://github.com/jaimeluzu2009-sketch/SURF-2026/releases/tag/v1.5.0
- APK: https://github.com/jaimeluzu2009-sketch/SURF-2026/releases/download/v1.5.0/barrels-1.5.0.apk
  (HTTP 200 comprobado). 234098009 bytes, SHA-256
  `dcbd1d7d4c2d265e7dffdb5c9816acc1f59dcc81d37c764d459c6e77d36d9d5c`.
- Verificado: certificado SHA-256 esperado (misma firma que 1.4.0), zipalign -c -P 16 4
  OK, paquete ec.barrels.surf, minSdk 24, targetSdk 36, ABIs arm64/armeabi-v7a/x86_64.
- Notas: RELEASE_1.5.0.md. Solo APK; no se generó AAB ni exportación web.
- No se re-ejecutaron las pruebas QA para esta compilación; valen las de secciones 10–12.
- Pendiente: que el usuario instale 1.5.0 en el POCO F7 Pro (debería actualizar
  sobre 1.4.0 sin desinstalar) y reporte escuela, cámaras, botones, tubo y FPS.
  Futuras compilaciones/publicaciones requieren nueva autorización.


## 14. Scroll táctil en menús (local, posterior a 1.5.0)

Reporte del usuario en su POCO con 1.5.0: en los menús no se podía bajar deslizando,
y los controles táctiles se sienten difíciles (pidió opciones; aún sin elegir).
- Nuevo `scripts/ui/touch_scroll.gd` (TouchScroll.attach): arrastre vertical con
  dedo aunque empiece sobre botón/panel/deslizador; al pasar 14 px cancela la
  pulsación (movimiento + soltar fuera inyectados) y traga el soltar real del dedo y
  de su ratón emulado; inercia. Enganchado en Carrera, Ajustes, Escuela y Personalizar.
- UiKit.option: OptionButton abre al SOLTAR (antes al tocar abría el desplegable y
  se tragaba el arrastre: causa principal en Ajustes).
- Prueba nueva `--qa --menu-scroll-test` (con ventana; 1600x720 simula 20:9):
  arrastre sobre botón desplaza y no lo activa; toque corto sí activa. PASÓ.
  Regresiones: custom-test OK, controls-test OK.
- No probado en teléfono; NO se compiló ni publicó (APK público sigue 1.5.0).


## 15. Joystick, modo asistido, ola más larga y pulido visual (local)

Solicitado: opciones A+B de controles táctiles y el prompt de realismo/ola larga.
- Joystick táctil: Controles.touch_curve (Ajustes.stick_response 0 Suave/1 Normal/
  2 Directa, potencia 1.9/1.45/1.0; borde = giro máx). Solo afecta al táctil.
  TouchControls._update_stick: el centro sigue al pulgar si sale del aro.
- Modo asistido Ajustes.assist (guardado controles/asistido; por defecto ON en móvil,
  OFF en PC; el bot y QA juegan siempre sin ayuda: Surfer.assisted()). Rema solo con
  la ola cerca, endereza a la orilla, ventana de pararse amplia, mitad de
  desequilibrio, más tiempo antes de caer, y retención en el bolsillo con
  orientación suave si te quedas atrás. Botón REMAR muestra «AUTO CON OLA».
- Ajustes > Controles: «Modo asistido» y «Respuesta del joystick táctil».
- Prueba `--qa --assist-test [--spot=N]` (principiante simulado con entrada táctil
  real): sin ayuda 0/9 olas, ~5 s de pie (se pasa por detrás de la cresta); con
  ayuda 8/9 olas completas, ~17 s (antes de alargar). Una Rinconada cerró el tubo.
- Ola más larga: Spots.OFFSHORE=45 m. break_z y lineup 45 m mar adentro, start_z =
  break_z-44, shoaling y activación del tubo relativos a break_z, envolvente
  lateral ampliada (-250/-205) en WaveModel y wave_common.gdshaderinc, cabo de
  beach.gd alargado lo mismo, barra «Completa la ola» relativa a break_z.
  tricks_test usa start_z=break_z-58. FINISH_Z y orilla sin cambios.
- Medido con bot (mismo bot, 2 olas/spot): antes 17.1/17.5/17.9 s y 118 m;
  después 25.7/26.6/27.1 s y 180-183 m (≈ +51 % tiempo, +54 % distancia).
- Terreno: normales y colores suaves por vértice en Beach._grid (antes facetado).
- Agua: grosor de la cara (base oscura, labio claro), tinte según ángulo de
  vista y emisión transmitida mayor cerca del labio. Paridad GPU OK (máx 2.5 cm).
- Materiales: piel rough .60/spec .32/rim .10; pelo .62; cubierta .40; fondo .30.
- Capturas: capturas/ola_larga/antes_N, despues_N (solo alargado) y visual_N.
- Pruebas OK: features, controls, styles, anatomy, tricks, school, tube-touch,
  camera-motion, water-look, turns, wake, score, menu-scroll, assist, paridad y bot
  3/3 spots. custom-test falló 1 vez en lote largo y pasó 4/4 aislado: vigilar.
- NO hecho de lo pedido: vegetación/rocas nuevas, rediseño de malla del tubo,
  posturas/silueta, revisión manual de primera persona, cielo/sombras por spot.
  Sin medición en POCO. No se compiló APK ni se publicó (público sigue 1.5.0).


## 16. Zona de remada, jugabilidad y academia (local)

- Bug corregido: tumbado se podía remar hasta la arena. Game._check_paddle_zone:
  fuera de PADDLE_ZONE (40 m lateral / 28 m hacia playa del lineup) avisa y a 1,5 s
  vuelve al lineup. Prueba `--qa --paddle-zone-test`.
- Referencias revisadas (reseñas/fichas, no manuales oficiales; no se jugaron):
  True Surf (física táctil en tiempo real, bombeo/stall), Barton Lynch (condiciones
  configurables, retos de trucos), Kelly Slater's Pro Surfer (medidor de equilibrio
  en tubo, trucos de cara para enlazar), Endless Summer (ola de aprendizaje,
  variedad de rompientes, botón para volver al pico).
- Bombeo: ganancia × energía de la ola (cero cerca de 2,3× velocidad de ola, más en
  pared alta); aviso si no rinde. Métrica `--qa --surf-metrics`: ritmo 0,32 s antes
  12.0/7.6/11.7 m/s → 10.7/7.2/10.1; spam ≤ ritmo; sin bombear 9.8/7.0/9.3.
- SurfTurns: nuevo top_turn (arranca ratio ≤0,45 con ≥40° y bajada); bottom turn
  cuenta subidas fuertes y ya no se descarta si la subida gasta la velocidad <3.
- Recepción: SurfTricks.landing_failure da el motivo (rotación, peso, trayectoria,
  espuma, fuera de pared, caída dura). Tolerancias iguales a antes.
- Tubo: puntos por segundo 30+70×(profundidad×control×velocidad) y pendiente de
  salida ×110; quedarse dentro sin control apenas suma. tricks_test actualizado.
- Puntuación: etiqueta «REPETIDO n %» al penalizar repetición; TOP TURN ×1,35.
- Academia (lecciones 8-12, índices 7-11, ACADEMY_FIRST=7): bombeo (2 válidos),
  bottom turn, top turn/cutback/snap, impulso y recepción, tubo (fuerza labio
  hueco y ola ≥2,1 m de práctica, avisado). Aprobación solo por señales reales;
  empiezan a 8 m del labio. `--qa --academy-test [--spot=N]`: pasa en 3 spots y
  pasivo (solo TRUCO) no aprueba. Capturas capturas/academia/.
- Todas las regresiones OK (features, controls, turns, wake, styles, tricks,
  school, tube-touch, camera-motion, custom, assist, paddle-zone, menu-scroll,
  score) y bot 3/3 (25.7/26.6/27.1 s).
- Pendiente real: prueba humana de comodidad/diversión, calibrar en POCO, FPS en
  móvil, mejoras de animación por maniobra, indicador visible de modo asistido.
  No se compiló ni publicó.
