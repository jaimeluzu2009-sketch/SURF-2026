# Cámaras, tubo, posturas y mando — cambios locales posteriores a 1.4.0

## Implementado
- Tres vistas persistentes: tercera persona, primera persona y frontal. Selección
  en Ajustes > Controles, tecla C reasignable, pulsación del stick derecho y botón
  CÁMARA táctil. La primera persona sigue la cabeza animada; oculta la malla del
  cuerpo para evitar atravesarla. No incorpora brazos exclusivos de primera persona.
- Se restaura el cuerpo en personalización y durante la caída. Suavizado sin roll
  artificial y conservación de protección frente al agua/techo del tubo.
- Tubo con variación suave de sección en longitud y tiempo en WaveModel.tube_section;
  render y detección usan esa misma sección. Labio decorativo con irregularidad,
  filamentos de espuma, transmisión por grosor y transición hacia la cara de agua.
  No es simulación de fluidos: permanece una envolvente translúcida aproximada.
- Postura de tubo con compresión según espacio al techo, mezcla suave y correcciones
  de torso, mirada y brazos en estados de maniobra. Se conservan los 17 clips y el
  apoyo de pies de las poses existentes; no se crearon nuevas animaciones mocap/IK.
- Mando: stick y cruceta para surfear; stick/cruceta para menús, A aceptar, B volver,
  X/RB remar/impulso, A pararse/truco, Y reiniciar, Start pausa y R3 cámara.
  Estado de conexión en ajustes y pausa al desconectar el último mando.
  Se reutiliza la entrada Godot, disponible también en exportación web; el usuario
  debe enfocar el juego y pulsar un botón para que el navegador detecte el mando.

## Archivos
scripts/camera_rig.gd, controls.gd, settings.gd, game.gd, touch_controls.gd;
scripts/surfer.gd, surfer_animator.gd, wave_model.gd, barrel.gd;
scripts/ui/menus.gd, control_bindings.gd; shaders/barrel.gdshader;
tests/camera_motion_test.gd, tests/surfer_polish_test.gd; CLAUDE.md y AGENTS.md.

## Pruebas ejecutadas
Windows, Godot 4.7.2 Compatibilidad/OpenGL 3.3, RTX 4060.
- camera-motion-test gráfico: compresión alta/baja, tres cámaras, visibilidad del
  cuerpo y restauración, ciclo y botón táctil, mapeo de botones, pausa/desconexión
  y reanudar: OK. Se usan eventos de mando sintéticos; no un mando físico.
- controls-test, tricks-test, features-test y polish-test: OK. La prueba antigua
  de compresión máxima ahora especifica techo bajo, pues la compresión es adaptativa.
- water-look-test gráfico en tres calidades: techo de malla/física coincide con
  error menor de 5 mm; una superficie; máximo 1295 vértices/2448 triángulos: OK.
- Piloto con física real: 1/1 ola en Montañita, Rinconada y FAE (3/3).
- Importación y comprobación de diff: sin errores de código detectados.
- Persisten avisos conocidos de objetos ObjectDB al cerrar algunas pruebas headless.

Capturas reales del motor: capturas/camaras_movimiento/tercera.png, primera.png,
frontal.png y postura_giro.png. Son escenas/poses controladas para QA, no una
sesión humana en teléfono.

## Pendiente / límites
No se ejecutó exportación ni navegador con mando real, ni prueba móvil de estos
cambios. Los mapeos pueden variar por navegador/modelo de mando. Se requiere
validar también foco y reconexión reales. Primera persona en remada/caída requiere
valoración del usuario; no se afirma ausencia de clipping para todos los ángulos.
La transparencia del tubo y el acabado de espuma siguen admitiendo pulido.
No se generó APK/AAB/web ni se subieron estos cambios. El APK público 1.4.0 no los incluye.

## Ideas táctiles propuestas (no implementadas)
1. Pulir diseño actual: dos botones contextuales grandes, barra de carga de impulso
   con marcas y aviso de soltar, botón cámara compacto; ajustar opacidad y separación.
   Mantiene gestos conocidos. Recomendación inicial.
2. Modo práctica: mismos dos botones, indicaciones cortas según la maniobra y ayudas
   opcionales de timing; despejar desafíos mientras se aprende.
3. Distribución personalizable: mover botones/joystick, guardar tamaño y opacidad
   por orientación y restaurar diseño. No está implementado un editor de posiciones.
No añadir botones por cada truco hasta validar legibilidad y uso con dos pulgares.

Documentación primaria consultada:
https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_web.html
https://docs.godotengine.org/en/latest/classes/class_input.html
