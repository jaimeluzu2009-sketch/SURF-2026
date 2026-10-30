# Pulido de agua y anatomía — 30 de octubre de 2026

Estado: mejoras incluidas en la entrega Android 1.4.0 autorizada por el usuario.
La validación siguiente corresponde al desarrollo en PC. Para la comprobación del
APK y su publicación consulta RELEASE_1.4.0.md. No se generó AAB ni paquete web.

## Causa y corrección

El surfista utilizaba un cuerpo procedural muy simplificado y volúmenes faciales
pequeños. Además, la simplificación automática reducía demasiado el rostro al
acercar la cámara. Se reemplazó la anatomía por una base de MakeHuman CC0 adaptada
al rig existente: rostro, párpados, nariz, labios, orejas, manos con dedos separados
y pies. Cabello ajustado al cráneo, iris/pupilas y cejas con geometría.

Los ocho modelos conservan 19 huesos y 17 clips. Se suavizó la transición de pesos
del cuello; los pies se plantan con la suela plana en el espacio de la tabla y se
evita heredar el giro del tobillo. La prueba evalúa vértices de suela deformados
contra los triángulos de la cubierta: separación medida aproximada de 2–3 mm en
ride, postura de tubo, agarre y floater. No se cambió la posición física de la tabla.

Se añadieron variaciones discretas por vértice y remates de prendas; se redujo
brillo plástico y ruido excesivo. La piel deja de recibir mapas de sombra de baja
resolución que producían bandas en rostro/dedos; el personaje sigue proyectando
su silueta. Los presets, prendas, tonos de piel y cabello siguen funcionando.

El agua utilizaba ruido de valor alineado a celdas y diferencias finitas para sus
normales, combinado con reflejos muy nítidos. Se sustituyó por dos NoiseTexture2D
simplex continuas de 256×256, repetibles y con mipmaps, combinadas con flujos cruzados.
El tubo reutiliza la textura de ruido. Menos contraste de manchas y más rugosidad
reducen los rectángulos y el aspecto aceitoso. Calidad Baja/Media/Alta usan una,
dos o tres muestras de normales, respectivamente, con desaparición progresiva a distancia.

La pared del tubo conserva una capa translúcida con iluminación/transmisión
aproximada y acotada para evitar caras negras. Se descartó la prueba opaca porque
tapaba al jugador. No se añadieron refracción de pantalla, SSR ni efectos exclusivos
de Forward+. La ordenación de transparencias sigue siendo una limitación a vigilar.
La fórmula de altura compartida entre shader y física no se modificó.

## Archivos

- `tools/human_anatomy.py`, `build_assets.py`, `build_styles.py`: integración,
  geometría, pesos, colores y poses; ocho `assets/models/surfer*.glb` regenerados.
- `assets/sources/makehuman/`: datos gráficos, licencias y procedencia fijada por hash.
- `scripts/surf_materials.gd`, `surfer.gd`: materiales y detalle automático del personaje.
- `shaders/water.gdshader`, `far_water.gdshader`, `barrel.gdshader`,
  `scripts/water.gd`, `barrel.gd`, `settings.gd`: aspecto y calidad del agua.
- `scripts/game.gd`, `scripts/ui/menus.gd`: conexiones, sesgo de sombra y créditos.
- `tests/anatomy_test.gd`, `visual_polish_test.gd`: validación y capturas reproducibles.

## Validación ejecutada

Windows, RTX 4060, Godot 4.7.2, Compatibilidad/OpenGL 3.3, ventana 1280×720.

- Importación de recursos y capturas gráficas: sin errores de shader o recursos.
- Anatomía: ocho combinaciones, colores de vértice, rig y apoyos reales aprobados.
- Personalización gráfica: clics, toque/arrastre simulado, prendas y persistencia: OK.
- Regresión de apariencias, cámara/animaciones, tubo/características, controles,
  estelas y 100 comprobaciones de trucos: OK.
- Agua/tubo con GPU: tres calidades y techo visible/físico aprobados.
- Paridad GPU/física: 31.752 puntos, error máximo 0,097 m, tolerancia 0,12 m: OK.
- Pilotos: una ola completada en cada spot (3/3), incluida La Rinconada con medición.
- Medición PC sin límite de FPS: Baja 411 FPS (2,43 ms), Media 390 (2,56 ms),
  Alta 373 (2,68 ms), escalas 0,70/0,85/1,0. No es una medición de Android.

Las pruebas headless conservan los avisos de salida ObjectDB ya conocidos; no
se describen como ejecuciones sin avisos. No se realizó prueba en teléfono físico
ni una nueva exportación web. No se garantiza 30 FPS en los dispositivos objetivo.

## Capturas y continuidad

Antes/después desde la misma cámara y escena:
`capturas/pulido_realista/antes/` y `capturas/pulido_realista/despues/`.
Incluyen menú/agua, personaje en menú, postura sobre ola, primer plano de rostro
y agua en tres calidades. Son imágenes del motor con los recursos 3D, no montajes.
El harness fija escena/pose para comparar; los pilotos físicos se ejecutan aparte.

Procedencia oficial de la base: MakeHuman Community, assets CC0.
https://github.com/makehumancommunity/makehuman/blob/a8bc2d54ff0ac92e78ff71431b1023eda42bf482/LICENSE.md

Para continuar: conservar los datos fuente y generar las ocho prendas, comprobar
las pruebas pertinentes y consultar al usuario antes de la siguiente exportación.
