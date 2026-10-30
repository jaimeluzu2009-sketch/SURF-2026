# BARRELS 1.3.0 — APK y código

Entrega del 30 de octubre de 2026. Incluye trucos, menú de personalización corregido
y guía de continuidad para Claude. Versión Android 1.3.0, código 6.

## Artefacto verificado

- Archivo: `build/android/barrels-1.3.0.apk`.
- Tamaño: 229,857,962 bytes.
- SHA-256: `5f249d99a4487aa9924693a66bfcb091ec6490b15db1a3c6c07b95b58fc8bb55`.
- Paquete: `ec.barrels.surf`.
- Android mínimo: API 24 (Android 7.0), GLES 3.0; targetSdk 36.
- Arquitecturas: arm64-v8a, armeabi-v7a y x86_64.
- apksigner: firma válida, esquema v2 y certificado igual al de 1.2.0.
- zipalign: verificación con páginas de 16 KB aprobada.
- ELF: todos los segmentos PT_LOAD comprobados en arm64 y x86_64 con alineación
  16384. Recursos de trucos, menú y tres variantes nuevas de ropa presentes en APK.
- Se comprobó exclusión de rutas de tests/capturas del paquete.

## Pruebas ejecutadas para esta entrega

- Importación de Godot 4.7.2 sin errores de scripts.
- Menú con renderizador Compatibilidad, ventana 1280×576, entradas de ratón y
  táctiles simuladas, arrastre, ocho combinaciones de ropa/estilo y persistencia: OK.
- Pruebas de trucos con física real y casos negativos: OK.
- En la entrega anterior de implementación también pasaron apariencias, controles,
  tubo/características, agua GPU y pilotos completos en los tres spots. Ver informes.

No se instaló este APK en un Android físico ni se ejecutó una nueva exportación
web. La firma y las comprobaciones del paquete no equivalen a una prueba en teléfono
ni a una aprobación de Google Play. Algunos tests headless conservan los avisos
ObjectDB de salida documentados; no se presentan como ejecuciones sin avisos.

## Distribución y continuidad

Destino de la entrega: [release v1.3.0](https://github.com/jaimeluzu2009-sketch/SURF-2026/releases/tag/v1.3.0).
APK y checksum se distribuyen como assets, fuera del historial Git. Código y guía
`CLAUDE.md` quedan en el repositorio. No se reemplaza el APK anterior ni su tag.

La autorización para generar y publicar esta entrega fue explícita. Después de
ella se mantiene la preferencia del usuario: consultar antes de otra exportación.

## Publicación confirmada

Release v1.3.0 publicada el 30 de octubre de 2026. El enlace público del APK
respondió HTTP 200 sin autenticación, con 229857962 bytes. El digest SHA-256 de
GitHub coincide con el archivo local. El tag apunta al código 5d1502dee85508f4b8d6856d6dd3a9ae91193f3d.
Los cambios posteriores a ese commit son documentación de la entrega.
