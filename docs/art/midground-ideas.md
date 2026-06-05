# Midground Asset Ideas (Architectural Alignment)

These ideas are refined for the Floppy Duck `MidgroundProp` system. All props sit at `GK.groundHeight` by default, but can use `yOffset` for floating or hanging elements. They are designed to be spawned multiple times per level.

---

## 1. Arctic
1. **Sled Dog Team** (Ground): A generic silhouette of 3-4 dogs. Works well in repetition as "different teams" passing by.
2. **Ice Geodes** (Ground): Small clusters of translucent blue ice. Low height (40-60pt).
3. **Research Module** (Ground): A generic metallic box with a single window. Can repeat as a "base complex".
4. **Snow-Covered Rock** (Ground): Simple terrain variation to break up the ground line.
5. **Frozen Crate** (Ground): Abandoned supply crates with "FD" markings.

## 2. Cave
1. **Crystal Cluster** (Ground): Purple glowing crystals. Can vary in size via `scaleRange`.
2. **Mining Cart** (Ground): Wooden cart on a small segment of track.
3. **Mushroom Patch** (Ground): Small bioluminescent fungi. Very low height (30pt).
4. **Hanging Vines** (Floating): Use large `yOffset` (~450pt) to anchor to the "ceiling" of the cave.
5. **Dripping Stalactite** (Floating): High `yOffset`. Can use a simple 2-frame animation for a water drip.

## 3. Day
1. **Picket Fence Segment** (Ground): Short white fence. Repeatable to create a long boundary.
2. **Park Bench** (Ground): Generic wooden/iron bench.
3. **Flower Bed** (Ground): Low-profile strip of colorful pixel flowers.
4. **Hydrant** (Ground): Red fire hydrant. Small landmark for repetition.
5. **Trash Can** (Ground): Green park-style bin, perhaps with a "bread" crumb nearby.

## 4. Egypt
1. **Sand Mound** (Ground): Small drifts of sand with hieroglyphic stones poking out.
2. **Market Tent** (Ground): Simple cloth canopy. Repeats well as a "bazaar".
3. **Clay Pot Group** (Ground): Cluster of 3 different sized pots.
4. **Obelisk Fragment** (Ground): A broken top-half of an obelisk sitting in the sand.
5. **Palm Sprout** (Ground): Very young palm trees, shorter than the hero-layer ones.

## 5. Jungle
1. **Mossy Idol** (Ground): Small stone head. Rare weight to keep it special.
2. **Fern Cluster** (Ground): Broad-leafed jungle plants. Good for density.
3. **Termite Mound** (Ground): Tall, jagged dirt structures.
4. **Exotic Flower** (Ground): Single, large vibrant flower (e.g., Rafflesia style).
5. **Log with Fungi** (Ground): Horizontal fallen log with shelf mushrooms.

## 6. Lagoon
1. **Beach Umbrella** (Ground): Colorful striped umbrella.
2. **Driftwood Pile** (Ground): Grey, weathered wood.
3. **Sand Castle** (Ground): A small, repeatable "duck-shaped" sand castle.
4. **Life Ring Post** (Ground): A wooden post with a red/white lifebuoy.
5. **Crab Hole** (Ground): A small mound of sand with a tiny crab sprite.

## 7. London
1. **Wrought Iron Fence** (Ground): Black decorative fencing.
2. **Phone Box** (Ground): The iconic red box. Works in repetition as "city infrastructure".
3. **Street Lamp** (Ground): Tall black lamp post.
4. **Sandwich Board** (Ground): A-frame sign saying "FRESH BREAD".
5. **Cobblestone Pile** (Ground): Small heap of stones near a "repair" sign.

## 8. Los Angeles
1. **Traffic Cones** (Ground): Small orange cones. High repetition weight.
2. **Palm Tree (Vibe)** (Ground): Skinny, very tall palms with a distinct "retro" silhouette.
3. **Bus Stop Bench** (Ground): Metal bench with a "Visit Duck Island" ad.
4. **Newspaper Box** (Ground): Blue/white metal boxes found on street corners.
5. **Street Sign** (Ground): A green signpost (e.g., "Duck Blvd").

## 9. Mountain
1. **Boulder Group** (Ground): Clusters of grey rocks.
2. **Pine Sapling** (Ground): Small, dense evergreens.
3. **Cairn** (Ground): A stack of balanced stones.
4. **Hiking Sign** (Ground): Wooden post with trail markers.
5. **Campfire Ring** (Ground): Stone circle with charred logs.

## 10. Neon City
1. **Utility Drone** (Floating): Small bot with `yOffset` (~200pt).
2. **Neon Ad Pylon** (Ground): Vertical sign with glowing "Kanji" or symbols.
3. **Crate Stack** (Ground): High-tech crates with glowing blue strips.
4. **Terminal** (Ground): A standalone data kiosk.
5. **Cable Bundle** (Ground): Thick wires running along the ground line.

## 11. Night
1. **Glow-worm Bush** (Ground): Generic bush with "glowing dot" overlay.
2. **Owl on Post** (Ground): A wooden fence post with a small owl sprite.
3. **Old Lantern** (Ground): A low-standing lantern on a stone base.
4. **Tombstone** (Ground): Simple grey stone. Fits the "spooky night" vibe.
5. **Wisp** (Floating): Blue glowing orb with `yOffset` and 4-frame pulse animation.

## 12. Pixel Tokyo
1. **Vending Machine** (Ground): Glowing machine with "Drink" labels.
2. **Lantern Post** (Ground): Traditional wooden lantern.
3. **Bamboo Fence** (Ground): Light-colored woven wood.
4. **Stone Basin** (Ground): Traditional water basin (Tsukubai).
5. **Bonsai Pedestal** (Ground): A small table holding a miniature tree.

## 13. Rough Ocean
1. **Buoy** (Floating): Use `yOffset` (~10pt) to make it look like it's bobbing.
2. **Jagged Rock** (Ground): Dark rocks that "cut" through the waves.
3. **Shipwreck Ribs** (Ground): Wooden beams of a sunken hull.
4. **Floating Barrel** (Floating): Generic brown barrel with `yOffset`.
5. **Bird on Rock** (Ground): A seagull standing on a small rocky outcrop.

## 14. Space
1. **Asteroid Chunk** (Floating): Random grey rock with various `yOffset` ranges.
2. **Crystal Spire** (Ground): Alien-looking crystalline growths.
3. **Satellite Dish** (Ground): Small ground-based receiver.
4. **Solar Panel** (Ground): A lone panel tilted toward a distant star.
5. **Floating Debris** (Floating): Scrap metal with high `yOffset`.

## 15. Sunset
1. **Hay Bale** (Ground): Round or square yellow bundles.
2. **Fence Post** (Ground): Single wooden post, often with a wire.
3. **Tall Grass Patch** (Ground): Silhouetted blades of grass.
4. **Water Trough** (Ground): Wooden tub for farm animals.
5. **Sunflower** (Ground): Tall, dark silhouettes with a bright yellow center.

## 16. Underwater
1. **Coral Fan** (Ground): Wide, flat coral structures.
2. **Anemone** (Ground): Squishy-looking floor creatures.
3. **Sunken Anchor** (Ground): Heavy iron anchor partially buried.
4. **Seaweed Tuft** (Ground): Green/brown wavy plants.
5. **Bubble Vent** (Ground): Small rocky hole (animation: bubbles rising).

## 17. Volcano
1. **Lava Rock** (Ground): Black porous stone with orange "hot" cracks.
2. **Crystal Ember** (Ground): Glowing orange crystals.
3. **Charred Stump** (Ground): The remains of a burnt tree.
4. **Ash Mound** (Ground): Grey, dusty piles.
5. **Steam Fissure** (Ground): Small crack in the ground (animation: white steam).

## 18. Western
1. **Barrel** (Ground): Classic wooden barrel.
2. **Cactus (Saguaro)** (Ground): The iconic "arms up" cactus.
3. **Wagon Wheel** (Ground): Rusted iron or wooden wheel.
4. **Skull** (Ground): Animal skull in the sand.
5. **Tumbleweed** (Ground): A light-brown tangled ball of brush.

---

## Retro Diffusion API Prompts (Production)

The block below is the canonical source the generator script (`scripts/generate_midgrounds.py`) reads from. The format is intentionally simple to keep parsing dependency-free:

- A single `### universal_suffix` block whose body is appended to every prompt.
- One `### <biome> / <slug>` block per asset; the body is the prompt body. The script joins prompt + ", " + universal_suffix before sending.

Do not change these headings without updating the parser in `scripts/generate_midgrounds.py`.

### universal_suffix
single grounded midground game asset, side-view platformer perspective, sits naturally on flat ground, transparent background, no scene, no sky, no UI, no text, no characters, no floating object, no cast shadow blob, no background landscape, no cropped edges, clean silhouette, readable at small size, 16-bit pixel art, limited palette, crisp pixels

### arctic / snowy_ice_boulder_cluster
mounded cluster of pale blue arctic ice boulders and packed snow, small frost cracks, icy highlights, rounded base, grounded on snow

### arctic / half_buried_frozen_crate
half-buried wooden explorer supply crate frozen into snow, frosty planks, rope binding, small snow cap, grounded base

### arctic / low_arctic_shrub_and_drift
low wind-swept snowdrift with tiny dark tundra shrubs poking through, soft icy-blue shadows, clean grounded silhouette

### cave / stalagmite_cluster
cluster of short limestone stalagmites rising from rocky cave floor, wet highlights, dark crevices, broad grounded base

### cave / glowing_mushroom_patch
small patch of bioluminescent cave mushrooms on mossy rocks, cyan glow, damp stone base, grounded and readable

### cave / broken_mine_cart_debris
small broken wooden mine cart pieces and rusty rail fragments on cave ground, scattered stones, compact grounded asset

### day / grassy_bush_clump
sunny grassy clump with small rounded bushes and wildflowers, bright daytime palette, clean low grounded silhouette

### day / small_fence_segment
short wooden fence segment with two posts and a little grass at the base, sunlit brown planks, grounded side-view asset

### day / picnic_rock_cluster
smooth rounded field stones with tufts of grass and tiny yellow flowers, cheerful daylight shading, grounded base

### egypt / sandstone_ruin_blocks
small pile of ancient Egyptian sandstone blocks, chipped edges, warm gold and terracotta shading, half-buried in sand

### egypt / nile_reed_cluster
dense cluster of Nile river reeds and papyrus plants growing from sandy mud, green-gold palette, grounded riverbank base

### egypt / broken_column_base
short broken Egyptian stone column base with cracked sandstone rings, tiny sand piles around bottom, grounded asset

### jungle / mossy_ruin_chunk
vine-covered jungle temple stone block pile, mossy cracks, small ferns at base, warm green and terracotta pixel palette

### jungle / fallen_jungle_log
fallen tropical log with exposed roots, moss patches, small mushrooms and leaves around base, grounded side-view asset

### jungle / fern_and_red_plant_clump
dense jungle fern clump with broad green leaves and a few red tropical plants, low grounded silhouette, readable shape

### lagoon / coral_sand_mound
small sandy lagoon mound with shells, sea grass, and smooth beach stones, turquoise highlights, grounded beach asset

### lagoon / driftwood_and_palm_sprout
sun-bleached driftwood log with tiny palm sprout and beach grass at base, tropical lagoon palette, grounded

### lagoon / low_coral_rock
low coral-rock cluster on wet sand, pink beige coral textures, small shells, clean side-view grounded silhouette

### london / cobblestone_curb_chunk
small old London cobblestone curb section with wet stones, moss in cracks, muted gray-blue palette, grounded asset

### london / brick_wall_rubble
low pile of Victorian red brick rubble with soot-dark edges and tiny weeds, compact grounded side-view asset

### london / street_bollard_base
short black iron London street bollard with stone base and small puddle, grounded, readable silhouette, no text

### losAngeles / dry_roadside_plants
cluster of dry Los Angeles roadside grasses, succulents, and dusty rocks, warm tan and sage palette, grounded asset

### losAngeles / low_stucco_wall_chunk
small broken white stucco wall segment with terracotta cap tiles, dusty base, sunlit LA palette, grounded

### losAngeles / palm_debris_pile
fallen palm frond pile with cracked sidewalk chunks and dry leaves, golden California light, grounded side-view prop

### mountain / alpine_rock_cluster
gray alpine boulder cluster with pine needles and tiny mountain flowers, cool high-altitude palette, grounded base

### mountain / pine_stump
short pine tree stump with exposed roots, moss, and small stones, rugged mountain side-view asset, grounded

### mountain / snow_dusted_trail_marker
small wooden trail marker post with no readable text, snow dusting and grass tufts at base, grounded mountain prop

### neonCity / neon_street_crate
futuristic street crate with glowing cyan-magenta edge strips, dark metal panels, grounded cyberpunk midground asset

### neonCity / broken_holo_sign_base
low broken hologram sign pedestal, glowing wires and neon fragments, no readable text, grounded on dark pavement

### neonCity / vent_pipe_cluster
cluster of short industrial neon city vent pipes with steam grates and glowing accents, grounded side-view prop

### night / moonlit_rock_and_grass
small moonlit rock cluster with dark grass tufts, blue-purple night palette, soft rim lighting, grounded asset

### night / old_lantern_stump
short tree stump with a small unlit lantern resting beside it, nighttime blue shadows, grounded readable silhouette

### night / dark_bush_clump
low dark bush clump with tiny cool highlights and scattered leaves, night forest palette, grounded side-view asset

### pixelTokyo / vending_machine_base_prop
small pixel Tokyo vending machine side prop, compact rectangular silhouette, glowing panels with no readable text, grounded

### pixelTokyo / potted_street_plants
cluster of small urban potted plants beside a low concrete block, Tokyo street palette, grounded side-view asset

### pixelTokyo / mini_shrine_stone_base
small urban shrine stone base with red accent posts, no text, clean pixel art, grounded on pavement

### roughOcean / wet_rock_cluster
dark wet coastal rock cluster with sea foam at base, stormy blue-gray palette, grounded shoreline asset

### roughOcean / broken_dock_plank_pile
small pile of broken wooden dock planks and rope on wet sand, rough ocean theme, grounded side-view asset

### roughOcean / seaweed_mound
low mound of tangled seaweed, shells, and pebbles washed ashore, stormy ocean colors, grounded readable silhouette

### space / grounded_asteroid_rock
small cratered asteroid rock cluster sitting on alien ground, purple-gray stone, tiny glowing minerals, grounded base

### space / broken_satellite_debris
compact pile of broken satellite panels and metal fragments half-buried in moon dust, grounded sci-fi pixel asset

### space / alien_crystal_cluster
low cluster of glowing alien crystals growing from rocky lunar soil, cyan-purple highlights, grounded side-view prop

### sunset / warm_grass_and_rock
low sunlit grass clump with amber rocks and tiny flowers, orange sunset rim light, grounded side-view asset

### sunset / fence_post_silhouette
short weathered wooden fence post pair with tall grass at base, warm sunset colors, grounded clean silhouette

### sunset / golden_shrub_mound
rounded shrub mound with orange backlighting and dusty ground base, sunset palette, readable grounded midground asset

### underwater / coral_cluster
grounded underwater coral cluster with seaweed, small shells, and sandy base, blue-green palette, side-view pixel asset

### underwater / sunken_stone_block
single sunken mossy stone block covered in algae and barnacles, resting on sand, underwater grounded asset

### underwater / kelp_base_clump
short kelp and seagrass clump rooted in sand, bubbles optional, clean readable grounded silhouette

### volcano / lava_rock_cluster
black volcanic rock cluster with glowing orange cracks, ash at base, grounded side-view pixel art asset

### volcano / charred_stump
burnt tree stump with ember glow and ash-covered roots, volcano palette, compact grounded silhouette

### volcano / basalt_pillar_base
short broken basalt column cluster with red lava light from below, grounded volcanic midground prop

### western / cactus_cluster
grounded desert cactus cluster with small rocks and dry grass at base, western terracotta palette, side-view pixel art

### western / tumbleweed_and_rocks
low tumbleweed caught against two desert stones, dusty sand base, warm western colors, grounded readable asset

### western / broken_wagon_wheel
small broken wagon wheel half-buried in sand with dry grass and pebbles, western side-view grounded prop
