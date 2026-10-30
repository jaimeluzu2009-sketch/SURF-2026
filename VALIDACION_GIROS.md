# Validación de giros y maniobras

29/10/2026. BARRELS, Godot 4.7.2, Compatibilidad. Cambios directamente en el proyecto. No se generó APK, AAB ni exportación web.

## Implementación y archivos
- scripts/surf_turns.gd (nuevo): reconoce arcos en la velocidad real, no solo orientación de tabla o pulsación. Usa ángulo acumulado, distancia, duración, velocidad, desplazamiento hacia la parte alta de la cara y retorno hacia la rotura. Reinicio por ola, pausa entre detecciones y descarte de giros prolongados o círculos completos.
- scripts/surfer.gd: carga de canto suavizada, radio dependiente de velocidad y peso, agarre lateral y pérdida de velocidad moderada al girar. Emite maneuver_completed después de reconocer un arco válido. Misma superficie de flotación, controles y estados de juego existentes.
- scripts/surfer_animator.gd: responde a la carga de canto con las poses existentes y compresión adicional moderada. No se generaron modelos ni nuevos clips.
- scripts/camera_rig.gd: anticipa la carga real de canto suavizada.
- scripts/score.gd y scripts/game.gd: reconocimiento conectado a los puntos y combos reales; aviso con nombre de maniobra. Detector antiguo desactivado durante gameplay para no duplicar puntos; API anterior conservada para pruebas independientes.
- scripts/hud.gd: limpia los avisos al reiniciar. tests/turns_test.gd (nuevo): clasificador y piloto de maniobras con captura. LEEME.md actualizado.

## Criterios iniciales
Arco válido: al menos 0,28 s, 2,4 m, 24 grados y 3 m/s, cara con soporte y sin espuma fuerte. El ángulo neto debe ser coherente con el recorrido angular; más de 280 grados o más de 4 s de giro mantenido no cuenta.

Bottom turn: empieza por debajo de 0,95 anchos de cara desde la cresta, sube al menos 0,22 anchos y gira al menos 32 grados. Cutback: empieza a más de 3,5 m por delante de la rotura y avanzando por la línea; vuelve hacia ella, recorre más de 4 m y gira al menos 105 grados. El resto de arcos válidos se identifica como carving. Es un primer clasificador de estas tres maniobras, no un sistema completo de competición.

Puntos: base 60 + 25 × velocidad máxima del arco, por combo existente; factor 1 para carving, 1,15 bottom turn y 1,55 cutback. La maniobra se valida al soltar o invertir el giro.

## Pruebas ejecutadas
- Importación sin errores. 27 comprobaciones satisfactorias en el test final sin ventana: tres tipos, rechazo de movimientos inválidos, una emisión al soltar, ausencia de duplicación, combos, dirección opuesta y clasificación estable entre 30 y 120 muestras/s.
- Piloto de maniobras: estado inicial de pie y posición controlada, después física normal con ola en movimiento e inputs de los controles existentes. Se verificaron carving (~24,5 grados), bottom turn (~41 grados) y cutback (~144 grados) sin asignar etiquetas o puntos por el nombre del caso. Los nombres salen del detector y los puntos de ScoreKeeper.
- La ejecución gráfica volvió a completar las tres maniobras, una sola puntuación por caso, con capturas reales de la inclinación y de los avisos CARVING / BOTTOM TURN / CUTBACK. Sin errores ni advertencias en barrels-turns-visual.log.
- Tres olas completas con piloto general: Montañita/Local tropical, La Rinconada/Competidor técnico y La FAE/Retro costero; 3/3 completadas.
- features_test: entrada/salida del tubo, bonus, colisión, marea, series y controles anticipados, OK. score_test anterior: OK.
- Algunas ejecuciones sin ventana mantienen la advertencia anterior de 4–8 instancias ObjectDB pendientes al salir. No aparece en la ejecución gráfica final.

## Capturas y límites
capturas/giros/carving_ingame.png, bottom_turn_ingame.png y cutback_ingame.png muestran el movimiento. Los archivos *_resultado.png muestran la puntuación real después de la maniobra. Se limpian los avisos al iniciar cada nueva ola.

Se probaron en Windows/RTX 4060/OpenGL 3.3, ventana 1280×720. No se ejecutó una nueva medición de rendimiento, no se exportó ni se probó en navegador y no se verificó en Android físico. Se conserva el renderizador Compatibilidad y no se añadieron dependencias externas.

Los radios y umbrales son ajustes iniciales que conviene valorar jugando con teclado y táctil. El fondo, la ola y el tubo conservan sus fórmulas anteriores. Los paquetes existentes no contienen estos cambios.

Copia previa de scripts: A:/CLAUDE/barrels-turns-backup.
