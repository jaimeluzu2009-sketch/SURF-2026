# Trucos de BARRELS — validación local, 29 de octubre de 2026

> Actualización del 30 de octubre: estos cambios están incluidos en el APK 1.3.0.
> Ver `VALIDACION_1_3.md`. El resto describe las pruebas de la implementación original.

Implementado en el proyecto Godot 4.7.2, renderizador Compatibilidad. Estos cambios
son locales: no se ha generado otro APK/AAB/Web ni modificado la publicación 1.2.0.

## Jugabilidad

- Bombeo: alternar peso atrás/adelante cada 0,18–0,90 s, con desplazamiento real,
  velocidad y cara limpia. Mantener una dirección no produce impulsos repetidos.
- Snap: TRUCO + giro junto al labio. Solo puntúa si cambia la trayectoria real.
  Bloquea temporalmente el detector de carving para evitar doble puntuación.
- Floater: TRUCO sin giro, velocidad lateral y cresta junto a la rotura. Mantener
  prolonga el recorrido hasta 1,15 s; soltar inicia el regreso físico a la cara.
  No concede puntos hasta la recepción y no permite inmunidad indefinida.
- Aéreos: cargar IMPULSO y soltar junto al labio con al menos 5 m/s. La tabla se
  separa de la altura de WaveModel, sigue gravedad y conserva inercia horizontal.
  Durante el vuelo, giro lateral y TRUCO mantenido permiten 180° y agarre.
- Recepciones: requieren alineación 0°/180°, peso centrado y superficie limpia.
  Perfecta, limpia o ajustada modifican el premio y la velocidad conservada.
  El 180° permite continuar en switch sin invertir artificialmente la inercia.
  Las caídas descartan el truco pendiente, cortan combo y reducen Flujo.
- Tubo: TRUCO agarra el canto y estabiliza. TRUCO + peso atrás arrastra la mano,
  frena y permite retrasar la línea. Recuperar velocidad bombeando ayuda a salir.
  El premio por la acción y por profundidad se confirma al salir por el hombro.
- Flujo: crece con variedad, decae con el tiempo, amplía la ventana de combo y
  bonifica puntos. Repetir familia reduce el valor hasta un mínimo del 30%.
  Las variantes de aéreo comparten familia a efectos de repetición.

## Controles e interfaz

Las acciones existentes se conservan: REMAR/IMPULSO y PARARSE/TRUCO, con las
reasignaciones guardadas, mando, modo zurdo, zona muerta e inversión del peso.
La opción de remar alternable no enclava la carga del salto.

Valores predeterminados: Espacio = remar o cargar/soltar; E/Shift = pararse o
truco; WASD/flechas = giro y reparto de peso. Mando: X/RB y A. En móvil se usan
el joystick y los mismos dos botones, con nombres según el estado.

HUD: Flujo, carga de impulso, giro y guía de alineación en vuelo; estado de las
acciones; avisos escalonados de premios; mensajes que dejan libres los controles
táctiles. Pausar cancela la carga y libera los botones. Nuevos desafíos reales:
Montañita (aéreo), La Rinconada (mano + salida) y La FAE (floater); se conservan
los desafíos anteriores y su progreso.

## Recursos y archivos

- `scripts/surf_tricks.gd`: carga, bombeo, snap, vuelo, floater y acciones del tubo.
- `scripts/surfer.gd`: estados, colisiones, switch, contacto, espuma y poses.
- `scripts/score.gd`, `game.gd`, `profile.gd`, `spots.gd`: Flujo, validación,
  integración con puntuación/progresión y desafíos.
- `scripts/controls.gd`, `touch_controls.gd`, `hud.gd`, `ui/control_bindings.gd`:
  entradas, configuración, ayudas y controles contextuales.
- `scripts/surfer_animator.gd`, `camera_rig.gd`, `surf_audio.gd`: transiciones,
  seguimiento durante vuelo y sonidos de contacto/recepción.
- `tools/build_assets.py`, `tools/build_styles.py`: clips originales generados
  mediante Blender 5.2.2 y exportados a GLB. Se conservan el rig de 19 huesos y
  la geometría; siete clips nuevos (17 en total), cinco modelos de surfista.
  Los archivos de las tablas se conservan sin cambios. No hay nuevas dependencias.
- `tests/tricks_test.gd`: piloto físico, negativas, entradas y apoyos del rig.
- `capturas/trucos/`: imágenes del juego real, ignoradas por Git.

## Ejecuciones realizadas

PC Windows, NVIDIA RTX 4060, Godot 4.7.2, OpenGL 3.3 Compatibilidad, 1280×720.

El piloto usa los estados/entradas del juego: prepara una salida de pie controlada
y deja actuar la física. No inyecta premios, trayectorias ni etiquetas para las
capturas. Los casos de puntuación aislados usan ScoreKeeper aparte.

1. `--qa --tricks-test --tricks-shots`: 100 comprobaciones aprobadas en la
   ejecución gráfica. Incluyen apoyos de pies, contacto de mano/canto/agua,
   aéreo básico, agarre, 180° + switch mantenido, fallo por inclinación y por
   sobrerrotación, ausencia de estela en vuelo, snap, floater con recepción y
   duración máxima, bombeo, tubo con salida real, penalización de repetición,
   profundidad pendiente, reasignación de tecla y botones táctiles.
2. Regresión: `--turns-test`, `--features-test`, `--controls-test`, `--wake-test`,
   `--styles-test`, `--polish-test` y `tests/score_test.gd`: aprobadas.
3. Piloto `--bot --runs=1`: una ola completa aprobada en cada uno de los tres
   spots (3/3), con física real.
4. `--qa --water-look-test --spot=1`, con GPU: aprobada; los tres presupuestos
   de calidad y el techo visible/físico coinciden con error máximo < 0,005 m.
   Su comprobación de parámetros de shader requiere GPU: una ejecución headless
   anterior devolvió null en ese parámetro y no se cuenta como aprobación.

La ejecución gráfica de trucos y la del agua no registraron errores de scripts,
shaders ni recursos faltantes. Algunas ejecuciones headless mantienen avisos de
4–6 objetos ObjectDB al cerrar; no se presentan como ejecuciones sin avisos.

## Pendiente

No se han probado estos cambios en Android físico ni en una nueva exportación web.
No se afirma un rendimiento de 30 FPS en teléfonos. Falta ajustar dificultad y
sensibilidad con juego humano en móvil. Esta entrega no incluye APK, AAB ni Web;
se requiere consultarlo antes de generar paquetes.
