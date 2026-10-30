# BARRELS: presentación de ola y tubo

29/10/2026. Proyecto existente, Godot 4.7.2, renderizador Compatibilidad. Cambios locales sin APK/AAB ni exportación web. Los paquetes anteriores no contienen esta intervención.

## Implementación
- scripts/barrel.gd: una sola malla indexada con normales/tangentes suaves, secciones muestreadas una vez por columna y tres densidades. Traslación por fotograma en el instante interpolado; reconstrucción a 20 Hz en baja y 30 Hz en media/alta. Se elimina la duplicación de capas interior/exterior y de vértices por triángulo.
- shaders/barrel.gdshader: transparencia de una capa, color coherente con el spot, luz transmitida aproximada, Fresnel, microondas y espuma fragmentada. El faldón del labio se desvanece hasta la superficie. Es una aproximación visual estilizada, no simulación volumétrica de fluidos ni refracción física.
- shaders/water.gdshader y scripts/water.gd: espuma en el impacto del labio, enlazada a tube_strength, y pequeñas cintas de espuma residual. La fórmula de altura del agua no se cambia.
- scripts/game.gd: salpicaduras más pequeñas, breves y menos numerosas en el rompimiento; origen adaptado al impacto del labio cuando hay tubo. Gancho de prueba adicional.
- tests/water_look_test.gd, LEEME.md y este informe: comparación de cámaras y validación.

La parte superior sólida se construye con la misma sección elíptica que usa WaveModel.tube_at para el techo. El faldón inferior representa espuma/agua cayendo y es decorativo: no se presenta como una nueva superficie rígida surfeable. No se cambia WaveModel, la flotación, los giros, los controles ni la puntuación.

## Pruebas ejecutadas
- Ejecución gráfica de las tres calidades en OpenGL 3.3/Compatibilidad, Windows, RTX 4060, ventana 1280×720. Shaders compilados y capturas inspeccionadas. Se corrigió una variable de shader antes de la pasada final.
- 18 comprobaciones de water_look_test: una superficie, normales unitarias/valores finitos, presupuesto de malla, conservación del estado físico, ajuste del arco al techo físico, seguimiento de traslación, parámetro de espuma y ocultación en spots sin tubo. Resultado OK.
- Error máximo entre vértices del arco y fórmula del techo en las tres calidades: 0,000001–0,000002 m en los puntos muestreados tras reconstruir la malla. Los valores no constituyen una medición continua de todos los píxeles entre actualizaciones.
- Prueba GPU del agua, calidad baja, La Rinconada: 31.752 puntos, error máximo 0,097 m, inferior a la tolerancia existente de 0,12 m. Esta prueba incluye el error de interpolación de la rejilla de agua.
- features_test: entrada real al tubo, 2,383 s dentro, salida con bonus y caída al tocar el labio, OK. También pasaron las comprobaciones existentes de pulsación anticipada, series, marea, audio y ropa.
- Piloto automático: Montañita/Local tropical, La Rinconada/Competidor técnico y La FAE/Retro costero; 3/3 olas completadas. Otra ola completada durante la medición de rendimiento.
- La pasada gráfica final no emitió errores ni advertencias. Algunas pruebas sin ventana conservan la advertencia anterior de 4–6 instancias ObjectDB al salir.

## Geometría y rendimiento disponible

| Calidad | Vértices | Triángulos |
|---|---:|---:|
| Baja | 361 | 648 |
| Media | 783 | 1456 |
| Alta | 1295 | 2448 |

Una ola en La Rinconada, Local tropical, RTX 4060, OpenGL 3.3, ventana 1280×720, VSync desactivado, muestreo de 4 s por calidad con los presets existentes:

[perf] Baja: 497 FPS (2.01 ms) | Media: 473 FPS (2.11 ms) | Alta: 428 FPS (2.34 ms)

Los presets usan escalas internas de 0,70/0,85/1,0. Son mediciones orientativas de este PC, sin comparación controlada contra la versión previa y sin valor predictivo para un teléfono concreto. La geometría alta tiene más triángulos que la anterior; la indexación reduce duplicación de vértices. Sigue pendiente medir transparencias, memoria, temperatura y batería en Android.

## Capturas reales
- capturas/ola_tubo/antes/interior_ingame.png y exterior_ingame.png.
- capturas/ola_tubo/despues/interior_ingame.png y exterior_ingame.png: misma cámara, tiempo de ola y postura; las partículas no son deterministas.
- capturas/ola_tubo/despues/calidad_0_ingame.png, calidad_1_ingame.png y calidad_2_ingame.png.

No son montajes ni imágenes generadas por IA. No se exportó ni se probó en navegador esta intervención, conforme a la preferencia del usuario. No hay validación en Android físico. La transparencia puede tener limitaciones de ordenación desde otros ángulos; se evita la doble capa para reducirlas, pero no se garantiza cualquier cámara posible.

Referencia técnica: [Spatial shaders de Godot 4.7](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html). ALPHA emplea la vía de transparencia; esta implementación no usa lectura de pantalla ni de profundidad. Los materiales son procedurales originales, sin texturas externas añadidas.

Copia previa: A:/CLAUDE/barrels-wave-look-backup. No se ejecutaron los generadores Android ni Web; APK/AAB/PCK anteriores conservan sus fechas anteriores a estos cambios.
