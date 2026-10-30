# Personalización corregida — 29 de octubre de 2026

> Actualización del 30 de octubre: estos cambios están incluidos en el APK 1.3.0.
> Ver `VALIDACION_1_3.md`. El resto describe las pruebas de la implementación original.

## Cambios

El selector de ropa borraba `style_id` y regresaba a Personalizado. Además, el
selector solo aparecía con ese estilo y no existían las mallas de ropa alternativa
para las otras identidades. Ahora la ropa conserva la apariencia y su tabla.

Se reemplazaron los desplegables de esta pantalla por selecciones embebidas:
APARIENCIA, ROPA y TABLA. Cabecera y pie permanecen visibles; el contenido central
se desplaza y las muestras de color se ajustan al ancho. No depende de popups del
sistema operativo para elegir ropa o apariencia.

- Cuatro estilos, incluidos Personalizado y los tres estilos existentes.
- Neopreno completo o licra y bermuda en cualquiera de ellos: ocho combinaciones.
- Cuatro tonos de piel y cuatro colores de cabello, disponibles desde el inicio.
- Colores de ropa, detalles, cubierta y fondo, aplicados al modelo real.
- Los colores con requisitos de carrera mantienen sus bloqueos y muestran NV.
- Vista del fondo de la tabla: invierte solo la tabla durante la personalización;
  al salir se restauran surfista y leash. No altera las físicas de gameplay.
- Guardado automático de estilo, ropa y todos los colores. Los perfiles antiguos
  conservan su selección y usan valores predeterminados para piel/cabello.

Las variantes de ropa se generaron con el código procedural existente en Blender
5.2.2. Se conservan el rig de 19 huesos y las animaciones, incluidos los trucos.

## Archivos principales

- `scripts/ui/surf_customizer.gd`: componente del menú, pestañas, muestras y vistas.
- `scripts/ui/menus.gd`: integración y navegación.
- `scripts/profile.gd`: ropa sin perder estilo; tonos de piel/cabello y persistencia.
- `scripts/surfer.gd`: selección de malla por estilo/ropa y materiales de aspecto.
- `scripts/camera_rig.gd`, `scripts/game.gd`: vista 3D del fondo y conexión del menú.
- `tools/build_styles.py`: genera también las variantes con `--outfit-variants`.
- `assets/models/surfer_local_wetsuit.glb`, `surfer_pro_beach.glb`,
  `surfer_retro_wetsuit.glb`: nuevas prendas para identidades existentes.
- `tests/custom_test.gd`: entradas reales, mallas, materiales, guardado y salida.
- `tests/styles_test.gd`: se elige Personalizado explícitamente para comprobar la
  vuelta al modelo original; cambiar ropa ya no debe borrar una identidad.

## Pruebas ejecutadas

Godot 4.7.2, Compatibilidad/OpenGL, Windows, NVIDIA RTX 4060.

`--qa --custom-test` con ventana 1280×720 y 1280×576: aprobadas sin errores de
scripts, shaders ni advertencias en las ejecuciones gráficas finales.

Se inyectaron clics de ratón, toques y arrastre de pantalla en los controles reales
del menú. En PC se habilitó la emulación táctil para comprobar ScrollContainer;
las coordenadas se transformaron al tamaño real de cada ventana. El arrastre
recorrió los 24 píxeles de desbordamiento del panel de ropa en ambos formatos.

Se comprobaron los cuatro estilos y dos prendas por estilo, cambio efectivo de
malla, piel/cabello en los materiales, bloqueo por nivel, vista del fondo, guardado
y recarga en `user://custom-test.cfg`, restauración al salir y vuelta a gameplay.
El archivo de prueba se elimina al terminar; no se modifica el perfil del usuario.

Regresión: apariencias, controles, características/tubo y 100 comprobaciones de
trucos aprobadas. Las ejecuciones headless conservan los avisos de 4–6 objetos
ObjectDB al salir ya documentados; las gráficas finales no los registraron.

Capturas reales en `capturas/personalizacion/`, incluidas las de formato panorámico.

## Límites de esta entrega

No se ejecutó una prueba en un Android físico ni una nueva exportación web.
No se generó APK, AAB ni paquete web. Los cambios son locales y todavía no están
incluidos en el APK publicado anteriormente.
