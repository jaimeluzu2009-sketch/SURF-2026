# blender -b --python tools/build_summer.py -- assets/models
from pathlib import Path
src = Path(__file__).with_name("build_assets.py").read_text(encoding="utf-8")
start = src.index('\tarm = build_armature()')
src = src[:start] + src[start:].replace('\tbody = build_body(mats)', '\tbody = build_body(mats)\n\t# Face materials use rest-pose anatomical height. Same mesh, weights and UVs.\n\tshorts = make_mat("Bermuda", srgb(0.1, 0.45, 0.5), 0.85)\n\tjersey = make_mat("Licra", srgb(0.06, 0.2, 0.33), 0.8)\n\tbody.data.materials.append(shorts)\n\tbody.data.materials.append(jersey)\n\tfor poly in body.data.polygons:\n\t\tc = poly.center\n\t\tif 0.62 < c.z < 1.01 and abs(c.x) < 0.26:\n\t\t\tpoly.material_index = 4\n\t\telif c.z < 0.62 or (abs(c.x) > 0.40 and c.z < 1.45):\n\t\t\tpoly.material_index = 1\n\t\telif poly.material_index == 0:\n\t\t\tpoly.material_index = 5', 1)
src = src.replace('"surfer.glb"', '"surfer_beach.glb"')
# Do not overwrite the existing board.
src = src.replace('export_glb([board], os.path.join(OUT_DIR, "board.glb"), False)', 'pass')
exec(compile(src, str(Path(__file__).with_name("build_assets.py")), "exec"))
