# BARRELS 1.1.0 — seis mejoras (28 octubre 2026)

## Implementado

1. **Control:** reserva de pulsación de PARARSE durante 220 ms y margen de 140 ms al abandonar la ventana válida; no permite incorporarse en espuma. Transición de cantos exponencial, equilibrio sensible al viento y avisos de caída.
2. **Tubo en La Rinconada:** labio de dos caras con grosor, salida abierta, sección elíptica compartida por geometría y detección del techo. Entrada, golpe contra el labio, salida, tiempo dentro, bonus y logro BARRELS. Cámara interior opcional (se omite con Reducir movimiento). Es una aproximación jugable, no una simulación de fluidos; su unión visual con la ola admite más refinamiento.
3. **Sonido:** mar, remada, espuma, deslizamiento y caída. Sonidos originales sintetizados, WAV mono 22,05 kHz. Bus SurfSea con filtro pasa-bajos al entrar al tubo y volumen general existente. No incluye música.
4. **Surfista:** respiración, compensación de torso/brazos y flexión secundaria de piernas; variación de dirección en las caídas. Se conserva el esqueleto y sus nueve animaciones. Ropa seleccionable: neopreno o licra/bermuda, con piernas y antebrazos descubiertos, colores y elección guardados en Perfil.
5. **Sesiones:** Limpio / Marea media / Mar de fondo desde SPOTS; modifican tamaño, agitación y nivel del agua. Tres tamaños sucesivos por serie, espera mayor al comenzar otra serie y separación de 13,5–15 s. Las condiciones son presets del juego, no previsiones meteorológicas reales. Las líneas secundarias siguen siendo mar de fondo visual; la siguiente ola principal se prepara al terminar o perder la anterior.
6. **Android:** calidad Baja/30 FPS por defecto, partículas limitadas y labio de menor resolución/20 Hz en Baja. Se corrigió la resolución adaptativa para actuar también por debajo de 10 FPS cuando la ventana tiene foco. Radio de malla próxima 210 m; el océano lejano cubre el horizonte. Nuevos APK y AAB con versionCode 2 / 1.1.0 y misma clave.

## Ejecutado

- Bot: matriz de 3 playas × 3 condiciones × 3 olas (27 olas); tras corregir la formación temprana del tubo, todas completables. Regresión final adicional de La Rinconada: 9/9.
- `tests/features_test.gd`: entrada y salida del tubo con movimiento real (2,38 s dentro), bonus, caída al golpear el techo, condiciones/serie, reproducción de audio y bus de filtro, ambas prendas, pausa/reanudar. No se ha evaluado la calidad sonora mediante una escucha humana.
- Paridad GPU, calidad Baja: 31.752 puntos por caso × 9 casos; errores máximos de 4,1 a 10,4 cm, tolerancia 12 cm. Esta prueba mide la superficie de apoyo, no una simulación de impacto de fluidos.
- Recorrido UI completo con capturas: menús, spots/condiciones, personalización, carrera, logros, ajustes, HUD, pausa y resultados. Carpeta `capturas/seis_mejoras/ui`.
- Capturas exterior/interior del tubo: `capturas/seis_mejoras/tubo_exterior.png` y `tubo_interior.png`.
- Web: exportada; abrió el menú, el selector de condiciones y La Rinconada en el navegador integrado, sin errores/advertencias de consola durante esa comprobación. No se completó una ola con teclado en el navegador.
- PC: Windows, NVIDIA RTX 4060, OpenGL 3.3 / Compatibilidad, 1280×720, sin límite en el tramo de medición. No comparar estos valores con antiguas pruebas ejecutadas con otra carga del PC.

| Spot | Baja | Media | Alta |
|---|---:|---:|---:|
| Montañita |454 FPS|411 FPS|390 FPS|
| La Rinconada |365 FPS|306 FPS|338 FPS|
| La FAE |370 FPS|382 FPS|361 FPS|

## Pendiente por falta de dispositivo

`adb devices -l` no encontró teléfonos ni emuladores conectados. No se comprobó ejecución nativa en Android, tacto, temperatura, batería ni estabilidad a 30 FPS en móvil. No se promete compatibilidad con todos los Android ni aprobación de Play Store.

Para validar: instalar el APK 1.1.0, jugar 15 minutos en Baja con contador de FPS, repetir en Media si es estable, probar REMAR/PARARSE simultáneamente con joystick, pausa/reanudación y segundo plano. Probar al menos un equipo de gama baja y uno intermedio; registrar modelo, Android, FPS y temperatura percibida.

## Reproducir

```
godot --headless --path . --fixed-fps 60 -- --features-test --qa --spot=1
godot --headless --path . --fixed-fps 60 -- --bot --runs=3 --spot=1 --condition=2
godot --path . res://tests/wave_parity.tscn -- --quality=0 --spot=1 --condition=2 --qa
godot --path . -- --features-test --qa --spot=1 --capture
godot --path . -- --bot --perf --runs=1 --spot=1
```

`--qa` y `--bot` aíslan el perfil y no guardan progreso ni ajustes. Scripts auxiliares y copia de seguridad: `A:/CLAUDE/barrels-*`.

## Paquetes Android verificados

APK: firma v2 válida (apksigner); AAB: firma válida (jarsigner, certificado autofirmado de subida). Identidad `ec.barrels.surf`, versión 1.1.0, código 2, minSdk 24, targetSdk 36, GLES 3.0, ARM32/ARM64/x86_64. zipalign -P 16 superado; todos los segmentos PT_LOAD de bibliotecas ARM64/x86_64 alinean como mínimo a 16 KB. No hay keystores en los archivos. Sumas en `build/android/SHA256SUMS-1.1.0.txt`.

En ejecución headless, Godot puede avisar de recursos de audio pendientes al cerrar; la prueba gráfica terminó sin ese aviso. Estos resultados no sustituyen la instalación y las pruebas en un móvil ni la revisión de Google Play.
