import os, shutil, json

SRC_THEMES = '/Users/xanderevans/Documents/floppyduck/artifacts/theme_candidates'
SRC_MIDGROUND = '/Users/xanderevans/Documents/floppyduck/artifacts/midground_assets'
DEST_ASSETS = '/Users/xanderevans/Documents/floppyduck/FloppyDuck/Assets.xcassets'

def create_imageset(path, filename):
    os.makedirs(path, exist_ok=True)
    contents = {
        "images": [
            {
                "idiom": "universal",
                "filename": filename,
                "scale": "1x"
            },
            {
                "idiom": "universal",
                "scale": "2x"
            },
            {
                "idiom": "universal",
                "scale": "3x"
            }
        ],
        "info": {
            "version": 1,
            "author": "xcode"
        }
    }
    with open(os.path.join(path, 'Contents.json'), 'w') as f:
        json.dump(contents, f, indent=2)

def migrate_themes():
    for theme in os.listdir(SRC_THEMES):
        theme_path = os.path.join(SRC_THEMES, theme)
        if not os.path.isdir(theme_path): continue
        
        print(f"Migrating theme: {theme}")
        for layer in os.listdir(theme_path):
            if layer.endswith('.png') and '_composite' not in layer:
                layer_name = layer.replace('.png', '')
                imageset_name = f"{theme}_{layer_name}.imageset"
                dest_path = os.path.join(DEST_ASSETS, imageset_name)
                
                # Copy file
                shutil.copy2(os.path.join(theme_path, layer), os.path.join(theme_path, 'temp_copy.png'))
                os.makedirs(dest_path, exist_ok=True)
                shutil.move(os.path.join(theme_path, 'temp_copy.png'), os.path.join(dest_path, f"{theme}_{layer}"))
                
                # Create/Update Contents.json
                create_imageset(dest_path, f"{theme}_{layer}")

def migrate_midground():
    for asset in os.listdir(SRC_MIDGROUND):
        asset_path = os.path.join(SRC_MIDGROUND, asset)
        if not os.path.isdir(asset_path): continue
        
        img_file = f"{asset}.png"
        src_img = os.path.join(asset_path, img_file)
        if not os.path.exists(src_img): continue
        
        print(f"Migrating midground asset: {asset}")
        imageset_name = f"mg_{asset}.imageset"
        dest_path = os.path.join(DEST_ASSETS, imageset_name)
        
        os.makedirs(dest_path, exist_ok=True)
        shutil.copy2(src_img, os.path.join(dest_path, img_file))
        create_imageset(dest_path, img_file)

if __name__ == "__main__":
    migrate_themes()
    migrate_midground()
