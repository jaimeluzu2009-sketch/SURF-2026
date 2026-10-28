# BARRELS

Juego de surf en tercera persona para móvil y web. Godot 4.7 con el renderizador **Compatibilidad**.
## Spots

Al arrancar sale un menú para elegir spot; desde la pausa se puede cambiar («Cambiar de spot»).

| Spot | Ola | Escenario | Luz | Dificultad |
|---|---|---|---|---|
| **Montañita · La Punta** | Derecha de punta, 2,1 m, series de 2 olas | Playa larga, cabo verde con rocas oscuras, pueblo de tejados rojos, cabañas y palmeras | Mañana nublada | Media |
| **La Rinconada · Manabí** | Derecha gruesa y empinada, 2,3 m | Playa estrecha bajo acantilados secos de color beige | Nublado | Difícil |
| **La FAE · Salinas** | Izquierda de punta, 1,6 m, series de 3 olas | Roca volcánica con algas, base aérea (hangares, torre, pista) y edificios de Salinas | Sol, agua azul | Media |

Las olas llegan en series: tras la ola que se surfea vienen otras líneas más pequeñas, separadas por un periodo de 14 s
como el mar de fondo del suroeste que dan Surfline y Surf-Forecast. Esas líneas no rompen y están en la misma fórmula
que la física.

Los tres se definen en `scripts/spots.gd`; cada entrada lleva la ola, el escenario, la luz y los colores del agua.
Para afinar uno (o añadir otro) basta con cambiar o copiar su entrada.

Lo que está contrastado con fuentes:
- **La FAE**: según Surf-Forecast es una izquierda de punta expuesta y muy consistente. Funciona mejor con mar de
  fondo del suroeste y viento del noreste, y sus peligros son el acceso privado (la base aérea) y las corrientes.
- **Condiciones**: Surfline da agua a 27–28 °C, olas de 0,9 a 1,8 m y mar de fondo del suroeste de unos 14 s.
- **La Rinconada**: una derecha (confirmado por el autor del juego y por el vídeo «La RINCONADA» de Greendot EC,
  que la describe como «una de las mejores derechas», surfeada por bodyboarders de Manta). En el vídeo es gruesa,
  tubular y está frente a acantilados secos.
- **Vídeos de referencia**: Montañita (Viaja Ecuador): derechas largas en la punta rocosa, pueblo en la ladera, cielo
  a menudo cubierto. La FAE (David Barrezueta, 2021): plataforma de roca oscura con algas, agua azul y varias líneas de olas.
- **Sin confirmar**: el tamaño exacto de cada spot.

## Cómo jugar

Abre el proyecto en Godot 4.7 y pulsa F5.

| Acción | Teclado | Móvil |
|---|---|---|
| Girar / inclinarse | A/D o ←/→ | joystick (mitad izquierda de la pantalla) |
| Peso adelante / atrás (de pie) | W/S o ↑/↓ | joystick arriba/abajo |
| Remar (tumbado) | Espacio o W | botón REMAR |
| Ponerse de pie | E o Shift | botón PARARSE (parpadea cuando se puede) |
| Reiniciar · Pausa/ajustes · FPS | R · Esc/P · F3 | botón II |

Objetivo: esperar tumbado, remar cuando la ola esté a unos 10 m, ponerse de pie cuando aparezca
**¡PÁRATE!**, girar hacia donde rompe la ola (derecha en Montañita y La Rinconada, izquierda en La FAE) y recorrer la ola por delante de la espuma hasta la orilla sin caerte.
La barra COLA–PUNTA es el equilibrio: en las bajadas echa el peso atrás y con poca velocidad, adelante.

## Cómo está hecho

| Parte | Archivo | Método |
|---|---|---|
| Surfista (3.290 triángulos, 19 huesos, sin texturas) y tabla con quillas, grip, larguero y tapón del leash (1.788 triángulos) | `assets/models/*.glb` | Generados por código en **Blender 5.2.2** con `tools/build_assets.py` (malla con modificador Skin, esqueleto, pesos por distancia a los huesos, IK para plantar los pies en la tabla) y exportados a GLB |
| Animaciones: `prone_idle`, `paddle`, `popup`, `ride`, `carve_left`, `carve_right`, `lean_fwd`, `lean_back`, `fall` | dentro de `surfer.glb` | Poses por código en el mismo script. No hay caminar ni correr: la escena empieza en el agua y no los necesita |
| Forma de la ola (una sola fórmula para la física y el dibujo) | `scripts/wave_model.gd` y `shaders/wave_common.gdshaderinc` | La ola avanza hacia la playa y rompe de lado |
| Agua, espuma, rizos | `shaders/water.gdshader`, `scripts/water.gd` | Rejilla más densa junto al surfista |
| Física: flotar, remar, coger la ola, planear, equilibrio, caídas | `scripts/surfer.gd` | Cinemática propia + `CharacterBody3D` (Jolt) para chocar con las rocas y la arena |
| Animación según la tabla | `scripts/surfer_animator.gd` | Árbol de estados con un BlendSpace2D (giro × peso) que sigue la inclinación de la tabla |
| Leash | `scripts/leash.gd` | Cuerda entre el tapón de la cola y el tobillo trasero |
| Spots (ola, escenario, luz) | `scripts/spots.gd` | Una entrada por spot |
| Escenario y colisiones | `scripts/beach.gd` | Tres tipos generados por código (punta, ensenada, base). En las izquierdas se reflejan en espejo |
| Cámara | `scripts/camera_rig.gd` | Tercera persona con suavizado |
| Controles | `scripts/controls.gd`, `scripts/touch_controls.gd` | Teclado, mando y táctil (joystick flotante) |
| Calidad / FPS | `scripts/settings.gd` | Baja / Media / Alta, límite de 30/60 FPS, resolución adaptativa |

Para regenerar los modelos:

    blender -b --factory-startup --python tools/build_assets.py -- assets/models [carpeta_para_previews]

## Interfaz

Estilo surf del Pacífico ecuatoriano: azul Pacífico, turquesa, arena, coral y atardecer, con franjas de motivos
artesanales dibujados con primitivas (greca manteño-huancavilca, tejido de paja toquilla, olas) y una ilustración
vectorial por spot. Tipografía Barlow / Barlow Condensed (SIL OFL, `fonts/OFL.txt`).

| Pantalla | Qué muestra (datos reales) |
|---|---|
| Menú principal | Escena 3D del spot con cámara cinematográfica; surfear, spots, surfista y tabla, carrera, ajustes; nivel y XP |
| Spots | Tarjeta por spot con su color, motivo e ilustración: dirección, tamaño, dificultad, récord y desafíos cumplidos |
| Surfista y tabla | Colores de neopreno, franja, cubierta y fondo, aplicados al modelo en vivo; los demás se desbloquean por nivel |
| Carrera | Progreso (nivel, XP, totales, próximos desbloqueos), récords por spot, logros y desafíos |
| Ajustes | Gráficos, audio (volumen general), controles (táctiles, tamaño, zurdo, remar mantener/alternar, teclas) y accesibilidad (tamaño de la interfaz, avisos, alto contraste, reducir movimiento) |
| Juego (HUD) | Puntuación, combo, avisos de maniobras, velocidad, desafíos en vivo, equilibrio, «¡PÁRATE!» y pausa |
| Pausa y resultados | Continuar, reiniciar, ajustes, cambiar de spot, menú; resultados con puntos, estadísticas, récord, XP, desafíos y logros |

Sistemas que hay detrás:
- `scripts/score.gd`: 4 puntos por metro; un giro cuenta al mantener el carve fuerte 0,35 s y soltarlo; los giros con
  menos de 2,5 s entre ellos suben el combo (hasta ×8); 40 puntos/s en el pocket; +1000 al completar la ola.
- `scripts/profile.gd` (autoload `Perfil`, `user://perfil.cfg`): XP (puntos ÷ 10, +150 por completar, +200 por
  desafío nuevo), nivel, récords, desafíos, 8 logros y personalización.
- El juego todavía no tiene sonidos; el volumen del menú ya controla el bus general.

Archivos: `scripts/ui/ui_kit.gd` (paleta, tema y componentes), `scripts/ui/pattern_band.gd`, `scripts/ui/spot_art.gd`,
`scripts/ui/menus.gd` (todas las pantallas), `scripts/hud.gd`. Capturas de todas las pantallas en `capturas/interfaz`
(se generan con `godot --path . -- --ui-shots=CARPETA`).

## Aspecto visual

Todo funciona en el renderizador Compatibilidad (GLES3 / WebGL 2) y está comprobado en la exportación web.

| Parte | Qué hace | Archivo |
|---|---|---|
| Océano | Color azul verdoso con manchas grandes de color; reflejo del cielo según el ángulo (Fresnel); normales animadas en 3 escalas que se desvanecen con la distancia; luz que atraviesa las crestas | `shaders/water.gdshader` |
| Espuma | Rotura, vetas detrás de la espuma, labio de las crestas empinadas, orilla, contacto de la tabla y estela en V que sigue el recorrido real de la tabla | `shaders/water.gdshader`, `scripts/surfer.gd` |
| Salpicaduras | Gotas pequeñas con mezcla aditiva (sin «humo» gris); la de la cola crece con la velocidad y el giro y sale hacia fuera de la curva | `scripts/fx.gd`, `scripts/surfer.gd` |
| Horizonte | Plano de mar lejano hasta el horizonte y cielo que toma el color del mar por debajo de la línea | `shaders/far_water.gdshader`, `scripts/game.gd` |
| Surfista y tabla | UV a escala real (1 UV = 1 m) generadas en Blender, sin estiramientos. Neopreno casi mate con tejido fino; piel con brillo sutil y borde de luz; pelo en mechones; cubierta de fibra con brillo y manchas de parafina; fondo más brillante; grip con surcos | `scripts/surf_materials.gd`, `tools/build_assets.py` |
| Arena, roca y vegetación | Detalle procedural en coordenadas del mundo (sin repetición ni costuras): grano y ondas en la arena, arena mojada más oscura y brillante cerca del agua, vetas y zona mojada en la roca, matas en la vegetación | `shaders/terrain.gdshader` |
| Luz | Tonemapper AgX, contraste y saturación suaves, sombras suaves según la calidad | `scripts/game.gd` |

**Recursos y licencias:** no hay texturas ni modelos de terceros. Todas las texturas son ruido generado en Godot
(`NoiseTexture2D`, 64-256 px, sin costuras, con mipmaps y filtrado anisótropo) o se calculan en los shaders.
Los modelos se generan con `tools/build_assets.py`.

**Calidades:**

| | Baja | Media | Alta |
|---|---|---|---|
| Rejilla del agua | 136 | 152 | 196 |
| Rizos del agua | 2 escalas | 3 escalas | 3 escalas |
| Puntos de la estela | 6 | 10 | 12 |
| Texturas de detalle (surfista, tabla, arena, roca) | No | Sí | Sí |
| Sombras | No | Suaves (bajas) | Suaves (medias) |
| Escala de render | 0,70 | 0,85 | 1,00 |
| Partículas | 35 % | 70 % | 100 % |

Capturas antes y después desde las mismas cámaras fijas: `capturas/antes`, `capturas/despues` y, lado a lado,
`capturas/comparacion`. Se generan con `godot --path . -- --bot --runs=1 --spot=N --quality=2 --shots=CARPETA`.

## Pruebas

- `godot --headless --path . --fixed-fps 60 -- --bot --runs=3 --spot=N`: un bot juega solo y recorre la ola (N = 0 Montañita, 1 La Rinconada, 2 La FAE). Resultado: todas las olas completadas en los tres spots (Montañita 17,1 s / 118 m · La Rinconada 18,8 s / 121 m · La FAE 16,7 s / 117 m).
- `godot --path . res://tests/wave_parity.tscn -- --quality=N --spot=N`: compara en la GPU la ola dibujada con la de la física, en 31.752 puntos (tolerancia 12 cm). Error máximo (Baja / Media / Alta): Montañita 6,4 / 5,3 / 4,0 cm · La Rinconada 11,8 / 8,2 / 5,8 cm · La FAE 4,2 / 3,5 / 2,5 cm. La Rinconada, con la cara más empinada, es la que más se acerca al límite.
- Rejilla del agua: Baja 136 · Media 152 · Alta 196 celdas por lado.
- `godot --path . -- --bot --perf`: mide los FPS de cada nivel de calidad.

## Rendimiento medido

Solo en este PC (Windows 11, NVIDIA RTX 4060, OpenGL 3.3, Compatibilidad, 1280×720, sin límite).
Antes de la mejora visual: Baja ≈ 1140 · Media ≈ 1140 · Alta ≈ 1020 FPS. Después: Baja ≈ 1070-1140 ·
Media ≈ 1060-1080 · Alta ≈ 945-950 FPS (Montañita y La FAE), con unas 50 llamadas de dibujo.
Esta GPU es muy superior a la de un móvil, así que estas cifras no sirven para predecir los 30 FPS en móvil.
**No se ha probado en ningún móvil.** Los 30 FPS en móvil están por verificar.

## Versión web

Exportación: `godot --headless --path . --export-release "Web" build/web/index.html` (preset «Web», sin hilos:
funciona en cualquier hosting estático, sin cabeceras COOP/COEP). Ocupa unos 40 MB (casi todo el motor, `index.wasm`).
Para probarla en local: `node tools/serve_web.js` y abrir http://localhost:8060.

Probada en el navegador integrado de la app de Claude (Chromium, WebGL 2, en este PC): carga sin errores
de consola, funcionan el menú y los ajustes, y en Alta va a 165 FPS (6,1 ms, el tope del monitor), con 51 draw calls.
Si la pestaña queda en segundo plano, el navegador la frena a unos 3 FPS; la resolución adaptativa ya ignora esas pausas.

## Android y Google Play

| Archivo | Para qué | Comprobado |
|---|---|---|
| `build/android/barrels.aab` (75 MB) | Subir a Google Play | Firmado con la clave de subida; bibliotecas de 64 bits alineadas a 16 KB |
| `build/android/barrels.apk` (216 MB, universal) | Instalar a mano en cualquier Android | Firma v2 válida, alineación de 16 KB (`zipalign -P 16`) |

- Identificador `ec.barrels.surf` · versión 1.0.0 (code 1) · categoría Juego · horizontal.
- API objetivo 36 (Android 16) · mínima 24 (Android 7.0) · arm64-v8a, armeabi-v7a y x86_64 · requiere OpenGL ES 3.0
  (Play no la ofrece a móviles sin ella). Sin permisos especiales.
- El APK pesa mucho porque lleva el motor tres veces (una por arquitectura). Con el AAB, Google Play
  entrega a cada móvil solo la suya.
- Icono propio y adaptativo en `assets/icon/` (se generan con `tools/make_icons.gd`).
- Clave de subida en `A:\PROYECTOS 3D GODOT\barrels-claves` (fuera del proyecto): **haz copia de seguridad**.
- Para volver a compilar: `.\tools\build_android.ps1`. Antes de cada versión nueva sube `version/code` en `export_presets.cfg`.
- Herramientas: JDK 17 (Temurin), Android SDK (build-tools 36.1.0, plataforma 36) y caché de Gradle en `A:\CLAUDE\Herramientas`.

Para publicar falta lo que solo puedes hacer tú en Play Console: la cuenta de desarrollador, la ficha (textos, capturas
e icono de 512 px de `assets/icon/icon.png`), la política de privacidad, la clasificación de contenido, el formulario de
seguridad de los datos y, en cuentas personales nuevas, la prueba cerrada con testers antes de producción.

## Pendiente

- Probar en móviles reales y en el navegador de un móvil.
- Sonido (mar, espuma, música).
- Bodyboard como segunda forma de jugar (muy popular en Manta).
- Corrientes en La FAE.
- Tubo, sobre todo para La Rinconada (el agua es un campo de alturas: todavía no hay labio que se cierre sobre el surfista).
