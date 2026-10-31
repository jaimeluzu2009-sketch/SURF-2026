# Escuela inicial, pantalla completa, caída y primera persona

Estado: implementación local posterior al APK público 1.4.0. No se generó APK,
AAB, exportación web ni ejecutable de PC; no se publicó ni hizo commit/push.

## Ruta tutorial implementada

Menú principal > ESCUELA > MI PRIMERA OLA: siete lecciones seleccionables y
repetibles (cámara, remada, tomar ola, incorporación, equilibrio, giro y ola completa).
Hay consigna única, ayuda contextual, barra de progreso, resultado, siguiente,
reintento y salida. El overlay y sus botones procesan eventos incluso con el mundo
pausado. Se comprobaron clics reales de siguiente/reintentar y Escape para salir.

Las lecciones usan las físicas y el spot seleccionado con condición limpia.
Tomar/pararse arrancan más cerca de la ola; equilibrio y giro empiezan desde un
checkpoint de pie. La ola completa se hace desde remada. No se otorga finalización
por pulsar un botón fuera de contexto; se observan estados y movimiento reales.
La pausa no suma segundos de equilibrio. Caer abre un reintento escolar.

SurfSchool guarda versión 1 y lista de lecciones completadas en user://surf_school.cfg,
independiente del perfil de carrera. Game intercepta resultados escolares ANTES de
Perfil.record_ride; no modifica XP, récords ni logros. Al salir restaura el HUD y la
sesión normal. Academia avanzada, tubo y talleres del diseño original siguen pendientes.

## Pantalla completa y 1080p

Se añadieron F11 y Alt+Enter, un ajuste de pantalla completa y tamaños de ventana
1280×720, 1600×900 y 1920×1080. La ventana se limita al espacio utilizable del
escritorio; pantalla completa usa el modo del monitor, sin forzar otra frecuencia.
F11 se reserva para evitar que una reasignación cree una acción doble.
No se muestra el interruptor de escritorio en móvil nativo.

La base lógica de interfaz permanece 1280×720 con canvas_items y adaptación de
aspecto. Esto no equivale a fijar la salida 3D en 720p: dependen del tamaño real,
DPI, calidad y resolución adaptativa. Se muestran ventana, tamaño del framebuffer
y escala 3D en ajustes. Alta usa escala 1; Media .85 y Baja .70 antes de adaptación.

Prueba en este PC: F11 produjo Window.MODE_FULLSCREEN, tamaño de ventana informado
1920×1080 y textura de viewport 2880×1620, con escala 3D 1.0. La diferencia de
ventana/salida se registra tal como la entrega el entorno, sin afirmar que todo
dispositivo renderiza exactamente a 1080p. Alt+Enter devolvió modo ventana.
Fullscreen en navegador aún no se ejecutó; depende también del navegador y gesto de usuario.

## Caída

El fallo acumulaba tumble sobre la rotación del fotograma anterior. Ahora la pose
se calcula desde la orientación capturada al caer y tiempo absoluto, con giro
acotado. Se evita reentrar a WIPEOUT/DONE y el reinicio limpia velocidad, giro y
estados de remada/compresión. La tabla aún puede volcar controladamente; no es ragdoll.

Prueba del cuerpo durante 2 s a 30/60/120 Hz: recorrido angular aproximado
1.099/1.098/1.096 rad, sin vueltas completas, orientación final coincidente (<.01 rad).

## Primera persona

Ya no se oculta todo el modelo sin alternativa. FirstPersonBody crea y cachea una
malla filtrada de brazos del modelo elegido, unida al MISMO skin/esqueleto y con
materiales activos. Se excluyen cabeza, torso y piernas para evitar ver el interior
del cuerpo. La malla original y sus animaciones permanecen intactas.

La cámara usa dirección de tabla y una inclinación hacia la cubierta. Cerca de .04 m;
FOV 88° tumbado y 82° de pie. La tabla original sigue visible, y los brazos ejecutan
el ciclo de remada real; se comprobaron dos fases. Los desafíos se ocultan en primera
persona para despejar manos/agua y se restauran en otras vistas.
Las ocho combinaciones de estilo/ropa generaron brazos de 9438 triángulos cada una.
No se añadieron nuevas animaciones ni assets de manos independientes.

## Archivos principales

- Nuevos: scripts/surf_school.gd, first_person_body.gd, ui/display_info.gd;
  tests/school_test.gd y sus .uid.
- Integración: scripts/game.gd, ui/menus.gd, hud.gd, settings.gd, controls.gd,
  camera_rig.gd, surfer.gd.
- Continuidad: CLAUDE.md, AGENTS.md, docs/TUTORIAL_DISENO.md y este informe.

## Validación ejecutada

Windows, RTX 4060, Godot 4.7.2 Compatibilidad/OpenGL 3.3.
- --qa --school-test: siete lecciones con piloto y física real; selector, progreso
  aislado, ausencia de cambios en carrera, pausa, caída/reintento y restauración: OK.
- Cuerpo de primera persona, skin común, ocho combinaciones, dos fases de remada,
  caída a distintas frecuencias y F11/Alt+Enter con cambios reales de ventana: OK.
- --qa --school-test --school-layout a 1280×576: consigna/lista, resultados,
  clics GUI de siguiente/reintento con mundo pausado y Escape: OK.
- Regresiones controls, tricks, features, polish, camera-motion y anatomy: OK.
- Algunas regresiones headless conservan avisos ObjectDB al salir.
- Importación sin errores de script; diff comprobado sin errores de whitespace.

Capturas reales: capturas/escuela_pc/ (lecciones, resultado y remada en primera
persona) y capturas/escuela_pc_576/ (menú/escuela/resultado/ajustes en formato bajo).
Las capturas de remada son poses controladas en escena, no sesiones humanas.

No probado aún en teléfono físico ni nueva exportación web/PC. La ruta escolar
se completó con piloto en Montañita; calibrar con personas y validar también los
checkpoints en los otros spots. No se garantiza ausencia de clipping en todas las
maniobras/cámaras ni 30 FPS en móviles. No publicar otra entrega sin autorización.
