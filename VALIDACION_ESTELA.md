# Validación: estela y salpicaduras

29/10/2026. BARRELS, Godot 4.7.2, renderizador Compatibilidad. Solo cambios y pruebas en el proyecto, sin APK/AAB ni exportación web.

## Archivos y comportamiento
- scripts/surfer.gd: rastro desde la cola real; velocidad y carga del canto por muestra; historial de 6/10/12 puntos según calidad; antigüedad y retirada de puntos; no estampa segmentos repetidos al detenerse. Emisión de gotas desde el canto exterior, dirección/tamaño/velocidad según giro y avance, parada de emisión al caer.
- scripts/fx.gd: recurso reutilizable específico para gotas de tabla, quad alargado 0,10×0,28 m antes de la escala de partícula, textura procedural 32×64, mezcla aditiva y duración 0,4 s. Máximo 32 partículas, sin sombras. Se reutiliza el nodo existente.
- shaders/water.gdshader: espuma de contacto en cantos, dos cintas estrechas, apertura lateral según carga, núcleo reducido y atenuación por edad/extremo. Los segmentos tienen longitud finita; se corrigió una prolongación no deseada detectada durante la revisión visual. Cálculo limitado al rectángulo que engloba la tabla y su historial.
- scripts/water.gd: parámetros de dirección, carga firmada e historial y límites del área. Parámetros nuevos opcionales para conservar llamadas anteriores.
- scripts/game.gd: configuración del recurso de gotas, envío de parámetros y gancho de prueba.
- tests/wake_test.gd (nuevo), tests/turns_test.gd (cámara de captura opcional), LEEME.md y este informe.

No se cambia la fuerza de giro, las maniobras, las colisiones, las animaciones, los controles ni las fórmulas de altura del agua. La espuma superficial está en el material del agua existente; las gotas son un efecto visual, no una simulación de partículas de fluido con colisiones individuales.

## Pruebas ejecutadas
- 19 comprobaciones de wake_test: no emite casi parado, respuesta mayor al cargar el canto, ambos sentidos de giro, gotas alargadas, duración/localización mundial, presupuestos de tres calidades, límites y sincronización de historial/carga, edades, nacimiento en la cola, ausencia de acumulación estacionaria, persistencia tras perder contacto, límites de shader, parada al caer, desaparición a 2,2 s y limpieza al reiniciar. Resultado OK.
- Ejecución gráfica final en OpenGL 3.3: shaders compilados, tres maniobras reales reconocidas y capturas inspeccionadas desde dos cámaras. Carving, bottom turn y cutback conservan puntos y combos, sin duplicación. Resultado OK, sin errores ni advertencias en barrels-wake-visual.log.
- Tres olas completas con piloto: Montañita/Local tropical, La Rinconada/Competidor técnico y La FAE/Retro costero; 3/3 completadas. Otra ola completada durante el muestreo de rendimiento.
- Algunas ejecuciones sin ventana mantienen la advertencia previa de 4–6 instancias ObjectDB al salir; no aparece en la pasada gráfica final.

## Medición disponible
Windows, RTX 4060, OpenGL 3.3, ventana 1280×720, Montañita, Local tropical, VSync desactivado, muestreo del piloto de 4 s por calidad:

[perf] Baja: 524 FPS (1.91 ms) | Media: 527 FPS (1.90 ms) | Alta: 504 FPS (1.98 ms)

Presets con escalas internas 0,70/0,85/1,0. Es una medición orientativa de este PC, no una comparación controlada antes/después ni una predicción de FPS en Android. Máximo 12 muestras de rastro y 32 partículas de tabla, sin nuevos emisores ni capas transparentes grandes de espuma.

## Capturas y límites
- capturas/estela/antes: capturas de las maniobras de la intervención anterior.
- capturas/estela/despues: carving_ingame.png, bottom_turn_ingame.png, cutback_ingame.png y cutback_resultado.png con el efecto nuevo. Cámaras y piloto equivalentes, con pequeñas diferencias de tiempo y partículas no deterministas.
- Archivos *_estela.png en la misma carpeta: cámara elevada para ver el recorrido. Son capturas reales del motor, no montajes.

No se exportó ni se probó en navegador, y no se verificó un Android físico. Sigue pendiente comprobar legibilidad de gotas a resolución móvil, coste de transparencias, consumo y temperatura. La textura es original y generada mediante código; no hay recursos externos ni dependencias nuevas.

Copia anterior de scripts: A:/CLAUDE/barrels-wake-backup. Los APK/AAB/PCK anteriores no incluyen estos cambios.
