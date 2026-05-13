import os
import requests
import json
import base64
from pathlib import Path

# Load API key from .env
def get_api_key():
    env_path = Path(__file__).parent.parent.parent / ".env"
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            if line.startswith("RETRO_DIFFUSION_KEY="):
                return line.split("=", 1)[1].strip()
    return os.environ.get("RETRO_DIFFUSION_KEY")

API_KEY = get_api_key()
API_URL = "https://api.retrodiffusion.ai/v1/inferences"

BASE_OUT = Path("../../artifacts/rd_midground_candidates")
NEGATIVE_SUFFIX = ", single grounded midground game asset, side-view platformer perspective, sits naturally on flat ground, transparent background, no scene, no sky, no UI, no text, no characters, no floating object, no cast shadow blob, no background landscape, no cropped edges, clean silhouette, readable at small size, 16-bit pixel art, limited palette, crisp pixels"

THEMES = {
    "arctic": [
        "mounded cluster of pale blue arctic ice boulders and packed snow, small frost cracks, icy highlights, rounded base, grounded on snow",
        "half-buried wooden explorer supply crate frozen into snow, frosty planks, rope binding, small snow cap, grounded base",
        "low wind-swept snowdrift with tiny dark tundra shrubs poking through, soft icy-blue shadows, clean grounded silhouette"
    ],
    "cave": [
        "cluster of short limestone stalagmites rising from rocky cave floor, wet highlights, dark crevices, broad grounded base",
        "small patch of bioluminescent cave mushrooms on mossy rocks, cyan glow, damp stone base, grounded and readable",
        "small broken wooden mine cart pieces and rusty rail fragments on cave ground, scattered stones, compact grounded asset"
    ],
    "day": [
        "sunny grassy clump with small rounded bushes and wildflowers, bright daytime palette, clean low grounded silhouette",
        "short wooden fence segment with two posts and a little grass at the base, sunlit brown planks, grounded side-view asset",
        "smooth rounded field stones with tufts of grass and tiny yellow flowers, cheerful daylight shading, grounded base"
    ],
    "egypt": [
        "small pile of ancient Egyptian sandstone blocks, chipped edges, warm gold and terracotta shading, half-buried in sand",
        "dense cluster of Nile river reeds and papyrus plants growing from sandy mud, green-gold palette, grounded riverbank base",
        "short broken Egyptian stone column base with cracked sandstone rings, tiny sand piles around bottom, grounded asset"
    ],
    "jungle": [
        "vine-covered jungle temple stone block pile, mossy cracks, small ferns at base, warm green and terracotta pixel palette",
        "fallen tropical log with exposed roots, moss patches, small mushrooms and leaves around base, grounded side-view asset",
        "dense jungle fern clump with broad green leaves and a few red tropical plants, low grounded silhouette, readable shape"
    ],
    "lagoon": [
        "small sandy lagoon mound with shells, sea grass, and smooth beach stones, turquoise highlights, grounded beach asset",
        "sun-bleached driftwood log with tiny palm sprout and beach grass at base, tropical lagoon palette, grounded",
        "low coral-rock cluster on wet sand, pink beige coral textures, small shells, clean side-view grounded silhouette"
    ],
    "london": [
        "small old London cobblestone curb section with wet stones, moss in cracks, muted gray-blue palette, grounded asset",
        "low pile of Victorian red brick rubble with soot-dark edges and tiny weeds, compact grounded side-view asset",
        "short black iron London street bollard with stone base and small puddle, grounded, readable silhouette, no text"
    ],
    "losAngeles": [
        "cluster of dry Los Angeles roadside grasses, succulents, and dusty rocks, warm tan and sage palette, grounded asset",
        "small broken white stucco wall segment with terracotta cap tiles, dusty base, sunlit LA palette, grounded",
        "fallen palm frond pile with cracked sidewalk chunks and dry leaves, golden California light, grounded side-view prop"
    ],
    "mountain": [
        "gray alpine boulder cluster with pine needles and tiny mountain flowers, cool high-altitude palette, grounded base",
        "short pine tree stump with exposed roots, moss, and small stones, rugged mountain side-view asset, grounded",
        "small wooden trail marker post with no readable text, snow dusting and grass tufts at base, grounded mountain prop"
    ],
    "neonCity": [
        "futuristic street crate with glowing cyan-magenta edge strips, dark metal panels, grounded cyberpunk midground asset",
        "low broken hologram sign pedestal, glowing wires and neon fragments, no readable text, grounded on dark pavement",
        "cluster of short industrial neon city vent pipes with steam grates and glowing accents, grounded side-view prop"
    ],
    "night": [
        "small moonlit rock cluster with dark grass tufts, blue-purple night palette, soft rim lighting, grounded asset",
        "short tree stump with a small unlit lantern resting beside it, nighttime blue shadows, grounded readable silhouette",
        "low dark bush clump with tiny cool highlights and scattered leaves, night forest palette, grounded side-view asset"
    ],
    "pixelTokyo": [
        "small pixel Tokyo vending machine side prop, compact rectangular silhouette, glowing panels with no readable text, grounded",
        "cluster of small urban potted plants beside a low concrete block, Tokyo street palette, grounded side-view asset",
        "small urban shrine stone base with red accent posts, no text, clean pixel art, grounded on pavement"
    ],
    "roughOcean": [
        "dark wet coastal rock cluster with sea foam at base, stormy blue-gray palette, grounded shoreline asset",
        "small pile of broken wooden dock planks and rope on wet sand, rough ocean theme, grounded side-view asset",
        "low mound of tangled seaweed, shells, and pebbles washed ashore, stormy ocean colors, grounded readable silhouette"
    ],
    "space": [
        "small cratered asteroid rock cluster sitting on alien ground, purple-gray stone, tiny glowing minerals, grounded base",
        "compact pile of broken satellite panels and metal fragments half-buried in moon dust, grounded sci-fi pixel asset",
        "low cluster of glowing alien crystals growing from rocky lunar soil, cyan-purple highlights, grounded side-view prop"
    ],
    "sunset": [
        "low sunlit grass clump with amber rocks and tiny flowers, orange sunset rim light, grounded side-view asset",
        "short weathered wooden fence post pair with tall grass at base, warm sunset colors, grounded clean silhouette",
        "rounded shrub mound with orange backlighting and dusty ground base, sunset palette, readable grounded midground asset"
    ],
    "underwater": [
        "grounded underwater coral cluster with seaweed, small shells, and sandy base, blue-green palette, side-view pixel asset",
        "single sunken mossy stone block covered in algae and barnacles, resting on sand, underwater grounded asset",
        "short kelp and seagrass clump rooted in sand, bubbles optional, clean readable grounded silhouette"
    ],
    "volcano": [
        "black volcanic rock cluster with glowing orange cracks, ash at base, grounded side-view pixel art asset",
        "burnt tree stump with ember glow and ash-covered roots, volcano palette, compact grounded silhouette",
        "short broken basalt column cluster with red lava light from below, grounded volcanic midground prop"
    ],
    "western": [
        "grounded desert cactus cluster with small rocks and dry grass at base, western terracotta palette, side-view pixel art",
        "low tumbleweed caught against two desert stones, dusty sand base, warm western colors, grounded readable asset",
        "small broken wagon wheel half-buried in sand with dry grass and pebbles, western side-view grounded prop"
    ]
}

def generate_asset(theme, index, prompt):
    print(f"🎨 Generating {theme} #{index+1}: {prompt[:50]}...")
    
    payload = {
        "prompt": prompt + NEGATIVE_SUFFIX,
        "prompt_style": "rd_pro__platformer",
        "width": 192,
        "height": 128,
        "num_images": 4,
        "remove_bg": True,
        "tile_x": False,
        "tile_y": False,
        "upscale_output_factor": 1
    }
    
    headers = {
        "X-RD-Token": API_KEY,
        "Content-Type": "application/json"
    }
    
    try:
        response = requests.post(API_URL, headers=headers, json=payload)
        
        if response.status_code != 200:
            print(f"  ❌ Error: {response.status_code} - {response.text}")
            return
        
        data = response.json()
        images = data.get("images", [])
        
        out_dir = BASE_OUT / theme / str(index + 1)
        out_dir.mkdir(parents=True, exist_ok=True)
        
        for i, img_data in enumerate(images):
            if img_data.startswith("data:image"):
                header, encoded = img_data.split(",", 1)
                img_bytes = base64.b64decode(encoded)
            else:
                try:
                    img_bytes = base64.b64decode(img_data)
                except:
                    # If it's a URL
                    r = requests.get(img_data)
                    img_bytes = r.content
            
            file_path = out_dir / f"variant_{i+1}.png"
            file_path.write_bytes(img_bytes)
            print(f"  ✅ Saved {file_path}")
    except Exception as e:
        print(f"  ❌ Exception: {e}")

def main():
    if not API_KEY:
        print("❌ Error: RETRO_DIFFUSION_KEY not found.")
        return

    print("🚀 Starting RD Midground Generation...")
    
    # Generate in batches
    for theme, prompts in THEMES.items():
        for i, prompt in enumerate(prompts):
            generate_asset(theme, i, prompt)

if __name__ == "__main__":
    main()
