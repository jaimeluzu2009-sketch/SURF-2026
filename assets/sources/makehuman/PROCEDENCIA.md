# Base anatómica del surfista

Datos gráficos de MakeHuman Community, fijados al commit
`a8bc2d54ff0ac92e78ff71431b1023eda42bf482` del repositorio oficial:
https://github.com/makehumancommunity/makehuman

Se utilizan `base.obj` y cinco targets de morfología adulta masculina:
dos de constitución física y tres bases de rasgos combinadas. La adaptación,
ropa, materiales de detalle, rig y animaciones de BARRELS se realizan mediante
`tools/human_anatomy.py`, `build_assets.py` y `build_styles.py`.

La licencia oficial distingue el programa de los datos gráficos. La malla base
y los targets utilizados están publicados bajo CC0 1.0 Universal. Se conservan
`LICENSE.ASSETS.md` y `LICENSE.md` oficiales; `SOURCE.json` registra las URL
inmutables y SHA-256 de cada archivo descargado. No se incorporó código del
programa MakeHuman.

Referencia oficial de licencia:
https://github.com/makehumancommunity/makehuman/blob/a8bc2d54ff0ac92e78ff71431b1023eda42bf482/LICENSE.md

Se excluyen las geometrías auxiliares del OBJ; se utiliza únicamente el grupo
body. El adaptador normaliza escala, ajusta articulaciones al rig existente,
genera cabello/ojos/cejas, asigna pesos y crea variación de color y remates de ropa.
La carpeta tiene `.gdignore`: los datos fuente no se importan como recursos del
juego. Los GLB derivados se guardan en `assets/models`.
