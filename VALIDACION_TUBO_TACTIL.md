# Pulido interior del tubo y controles táctiles

Estado: cambios locales posteriores al APK público 1.4.0. Sin exportar ni publicar.

## Cambios
- Perfil interior asimétrico: WaveModel.tube_roof es la función común para malla
  y techo/colisión. Hombro más amplio y labio más cerrado; muestreo angular refinado
  sin aumentar el número de vértices. No se separó una ola decorativa de la física.
- Pared interior menos transparente, variación de transmisión por grosor y espuma
  menos filamentosa. Usa signo normal/cámara para distinguir interior/exterior.
  Conserva una sola superficie translúcida, sin refracción/SSR/pasos de render nuevos.
- Dos botones contextuales con contorno estable, estado pulsado, textos de contexto
  para remada/tubo/aire y anillo de impulso con marcas, porcentaje y aviso SUELTA.
  launch_available centraliza cooldown y requisitos del despegue; el umbral de
  carga MIN_AIR_CHARGE sigue siendo 0.18 (estrictamente mayor), sin cambiar gameplay.
- Ajustes > Controles > Opacidad táctil, 35–100 %, persistente. No cambia áreas
  de toque ni posiciones. Alto contraste impone mínimo visual de 85 %.
- Tutorial: diseño propuesto en docs/TUTORIAL_DISENO.md. No se creó modo jugable
  ni botón de menú que prometa una funcionalidad todavía no implementada.

## Archivos
scripts/wave_model.gd, barrel.gd, surf_tricks.gd, game.gd, touch_controls.gd,
settings.gd, controls.gd, ui/menus.gd; shaders/barrel.gdshader;
tests/tube_touch_test.gd y tests/camera_motion_test.gd;
docs/TUTORIAL_DISENO.md, CLAUDE.md y AGENTS.md.

## Pruebas realizadas
Windows, Godot 4.7.2 Compatibilidad, OpenGL 3.3, RTX 4060, 1280×720.
- tube-touch-test gráfico: perfil asimétrico, umbral, disponibilidad y cooldown,
  opacidad, guardado/recarga aislados, dedos simultáneos y liberación independiente
  en modo normal y zurdo: OK.
- water-look-test gráfico en tres calidades: arco y techo físico coinciden con
  error inferior a 5 mm; presupuesto máximo 1295 vértices/2448 triángulos: OK.
- Regresiones controls, tricks, features, polish y camera-motion: OK.
- Piloto con física real: una ola completada en cada spot, 3/3.
- La prueba de cámara anterior asumía que no había mando conectado. Se detectó
  un mando en el sistema; se corrigió la prueba para no simular su desconexión
  sin retirarlo de la lista. Verifica mantener PLAY si aún queda un mando y verifica
  pausa por señal sintética gamepad_lost. No se afirma prueba manual de mando.
- Algunas pruebas headless conservan avisos ObjectDB al salir.

Capturas reales de Godot: capturas/tubo_controles/interior_primera.png,
interior_tercera.png, botones_carga.png, opacidad_35.png, botones_remada.png.
Son estados controlados de QA, no una sesión humana ni una demostración de salto.

## Límites y pendientes
No se probó este cambio en Android físico ni navegador, ni se midieron FPS móviles.
La pared del tubo sigue siendo una aproximación de una capa, sin volumen de fluidos
real; quedan transparencia y unión del labio por evaluar desde más trayectorias.
El tutorial es diseño, no implementación; completar su integración y pruebas cuando
se decida avanzar con el modo. APK público 1.4.0 conserva recursos anteriores.
