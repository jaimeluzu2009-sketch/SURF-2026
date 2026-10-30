# Apariencias anatómicas de BARRELS

Actualización local posterior al APK 1.3.0, 30 de octubre de 2026.

La anatomía utiliza datos gráficos CC0 de MakeHuman Community. Procedencia, licencia
y hashes en `assets/sources/makehuman/PROCEDENCIA.md` y `SOURCE.json`. Cabello,
ojos, cejas, ropa y detalles de superficie se adaptan con el generador de BARRELS.
No son imágenes 2D ni recursos de un generador de imágenes.

Se conservan cuatro estilos, dos prendas por estilo, 19 huesos y 17 clips.
Las tres tablas de estilo y la tabla original no se modificaron en esta entrega.

| Archivo | Triángulos completos | Bytes GLB |
| --- | ---: | ---: |
| surfer.glb | 31,232 | 1,782,140 |
| surfer_beach.glb | 31,232 | 1,786,756 |
| surfer_local_wetsuit.glb | 32,848 | 1,898,660 |
| surfer_local.glb | 32,848 | 1,888,704 |
| surfer_pro.glb | 32,352 | 1,863,044 |
| surfer_pro_beach.glb | 32,352 | 1,851,316 |
| surfer_retro_wetsuit.glb | 33,024 | 1,911,116 |
| surfer_retro.glb | 33,024 | 1,904,528 |

La importación conserva generación de LOD. Se aumenta el detalle de cerca y en
personalización para que no desaparezcan rasgos faciales; a distancia se mantiene
simplificación automática, con un sesgo menor en calidad Baja. Los colores elegidos
se combinan con variaciones de color por vértice, y los materiales usan texturas
procedurales compactas con mipmaps. Los dedos tienen geometría separada; se
mantiene la animación existente de manos, sin añadir otro esqueleto.

Regeneración (Blender 5.2.2, desde la raíz del proyecto):
```text
blender -b --factory-startup --python tools/build_assets.py -- assets/models
blender -b --factory-startup --python tools/build_summer.py -- assets/models
blender -b --factory-startup --python tools/build_styles.py -- assets/models
blender -b --factory-startup --python tools/build_styles.py -- assets/models --outfit-variants
```
La generación necesita los datos fuente CC0 incluidos. Revisa cualquier cambio
en las tablas que puedan volver a exportar los generadores, y conserva trabajo
del usuario. No ejecutar helpers antiguos de A:\CLAUDE sin revisar su código.

Esta versión todavía no está incluida en el APK 1.3.0 publicado. Pruebas y límites
en `VALIDACION_AGUA_ANATOMIA.md`.
