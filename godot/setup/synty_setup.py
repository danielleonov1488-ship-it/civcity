"""Подготовка купленного набора Synty POLYGON Ancient Empire для Godot (сами модели в git не хранятся).

1. Распаковывает POLYGON_AncientEmpire_SourceFiles_*.zip в assets/incoming/synty/ae
   и копирует FBX, текстуры и список материалов в godot/assets/synty.
2. Включает перенос движений (retarget) для персонажей: прописывает BoneMap в .import файлах.
   Сначала один раз запустить импорт Godot (чтобы появились .import), потом этот скрипт ещё раз.

Запуск: python godot/setup/synty_setup.py путь/к/POLYGON_AncientEmpire_SourceFiles_v4.zip
"""
import sys, os, re, glob, shutil, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DST = os.path.join(ROOT, 'godot', 'assets', 'synty')

SUB = '''_subresources={{
"nodes": {{
"PATH:{path}": {{
"retarget/bone_map": Resource("res://assets/rig/{bm}"),
"retarget/bone_renamer/rename_bones": true,
"retarget/bone_renamer/unique_node/make_unique": true,
"retarget/bone_renamer/unique_node/skeleton_name": "GeneralSkeleton",
"retarget/remove_tracks/except_bone_transform": false,
"retarget/remove_tracks/unimportant_positions": true,
"retarget/remove_tracks/unmapped_bones": true,
"retarget/rest_fixer/apply_node_transforms": true,
"retarget/rest_fixer/normalize_position_tracks": true,
"retarget/rest_fixer/overwrite_axis": true,
"retarget/rest_fixer/reset_all_bone_poses_after_import": true,
"retarget/rest_fixer/fix_silhouette/enable": false
}}
}}
}}'''


def patch(imp, path, bm):
    s = open(imp, encoding='utf-8').read()
    s = re.sub(r'_subresources=\{.*?\n\}\n', '', s, flags=re.S) if '_subresources={\n' in s else re.sub(r'_subresources=\{\}\n', '', s)
    s = s.rstrip('\n') + '\n' + SUB.format(path=path, bm=bm) + '\n'
    open(imp, 'w', encoding='utf-8').write(s)


def main():
    if len(sys.argv) > 1 and sys.argv[1].endswith('.zip'):
        src = os.path.join(ROOT, 'assets', 'incoming', 'synty', 'ae')
        os.makedirs(src, exist_ok=True)
        zipfile.ZipFile(sys.argv[1]).extractall(src)
        for part in ('FBX', 'Textures'):
            shutil.copytree(os.path.join(src, part), os.path.join(DST, part), dirs_exist_ok=True)
        shutil.copy(os.path.join(src, 'MaterialList_PolygonAncientEmpire.txt'), DST)
        print('скопировано в', DST)
    n = 0
    for imp in glob.glob(os.path.join(DST, 'FBX', 'Characters', 'Unreal_Characters', 'SK_Chr_*.fbx.import')):
        patch(imp, 'Skeleton3D', 'bonemap_synty.tres')
        n += 1
    ual = os.path.join(ROOT, 'godot', 'assets', 'people', 'UAL1_Standard.glb.import')
    if os.path.exists(ual):
        patch(ual, 'Armature/Skeleton3D', 'bonemap_ual.tres')
    print('перенос движений включён для', n, 'персонажей; теперь снова запустите импорт Godot')


main()
