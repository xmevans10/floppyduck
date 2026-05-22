import SpriteKit

// MARK: - Theme Recipe Catalog

/// Static catalog of theme recipes. Each theme is a constant — no switch
/// statements, no runtime conditionals. Adding a theme is additive;
/// modifying a theme is a diff on one constant.
enum ThemeRecipeCatalog {

    /// Look up the recipe for a given `BackgroundTheme`.
    static func recipe(for theme: BackgroundTheme) -> ThemeRecipe {
        switch theme {
        case .day:         return day
        case .sunset:      return sunset
        case .night:       return night
        case .neonCity:    return neonCity
        case .underwater:  return underwater
        case .volcano:     return volcano
        case .arctic:      return arctic
        case .western:     return western
        case .jungle:      return jungle
        case .cave:        return cave
        case .mountain:    return mountain
        case .space:       return space
        case .pixelTokyo:  return pixelTokyo
        case .egypt:       return egypt
        case .lagoon:      return lagoon
        case .losAngeles:  return losAngeles
        case .london:      return london
        }
    }

    // MARK: - Default Budgets

    private static let defaultBudget = ContrastBudget(
        maxLuminanceVariance: 0.15,
        maxOpaquePixelDensity: 0.30,
        corridorHeightFraction: 0.50
    )

    private static let darkBudget = ContrastBudget(
        maxLuminanceVariance: 0.10,
        maxOpaquePixelDensity: 0.25,
        corridorHeightFraction: 0.55
    )

    // MARK: - Layer Factories

    private static func hero(_ name: String) -> LayerRecipe {
        LayerRecipe(assetName: name, scrollSpeed: 0, heightPoints: 620, yAnchor: .top)
    }

    private static func clouds(_ name: String) -> LayerRecipe {
        LayerRecipe(assetName: name, scrollSpeed: 0.15, heightPoints: 150, yAnchor: .horizon(offset: 350))
    }

    private static func ground(_ name: String) -> LayerRecipe {
        LayerRecipe(assetName: name, scrollSpeed: 1.0, heightPoints: GK.groundHeight, yAnchor: .ground)
    }

    private static func groundBase(_ name: String) -> LayerRecipe {
        LayerRecipe(assetName: name, scrollSpeed: 1.0, heightPoints: 100, yAnchor: .ground)
    }

    // MARK: - Free Themes

    static let day = ThemeRecipe(
        hero: hero("day_hero"),
        clouds: clouds("day_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "day_sprite_oak_tree",          heightPoints: 163, weight: 3, scaleRange: 0.7...1.2, isTree: true),
                MidgroundProp(assetName: "day_sprite_bush",              heightPoints: 63,  weight: 3, scaleRange: 0.6...1.0),
                MidgroundProp(assetName: "day_sprite_flowers",           heightPoints: 44,  weight: 2, scaleRange: 0.5...0.9),
                MidgroundProp(assetName: "day_sprite_rock",              heightPoints: 50,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "day_sprite_grassy_bush_clump",   heightPoints: 70, weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "day_sprite_picnic_rock_cluster", heightPoints: 60, weight: 2, scaleRange: 0.7...1.0),
            ]
        ),
        ground: ground("day_ground"),
        groundBase: groundBase("day_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let sunset = ThemeRecipe(
        hero: hero("sunset_hero"),
        clouds: clouds("sunset_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "day_sprite_oak_tree",               heightPoints: 163, weight: 3, scaleRange: 0.7...1.2, isTree: true),
                MidgroundProp(assetName: "sunset_sprite_golden_shrub_mound",  heightPoints: 70,  weight: 3, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "sunset_sprite_hay_bale",            heightPoints: 55,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "sunset_sprite_tall_grass",          heightPoints: 80,  weight: 3, scaleRange: 0.6...1.0),
                MidgroundProp(assetName: "sunset_sprite_warm_grass_and_rock", heightPoints: 60,  weight: 2, scaleRange: 0.7...1.0),
            ]
        ),
        ground: ground("sunset_ground"),
        groundBase: groundBase("sunset_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let night = ThemeRecipe(
        hero: hero("night_hero"),
        clouds: clouds("night_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "night_sprite_silhouette_tree",        heightPoints: 180, weight: 4, scaleRange: 0.7...1.2, isTree: true),
                MidgroundProp(assetName: "night_sprite_moonlit_rock_and_grass", heightPoints: 65,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "night_sprite_old_lantern_stump",      heightPoints: 80,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "night_sprite_dark_bush_clump",        heightPoints: 70,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "night_sprite_mailbox",                heightPoints: 50,  weight: 1, scaleRange: 0.7...1.0),
            ]
        ),
        ground: ground("night_ground"),
        groundBase: groundBase("night_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    // MARK: - Normal Themes (Bread Currency)

    static let neonCity = ThemeRecipe(
        hero: hero("neonCity_hero"),
        clouds: clouds("neonCity_clouds"),
        ground: ground("neonCity_ground"),
        groundBase: groundBase("neonCity_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let underwater = ThemeRecipe(
        hero: hero("underwater_hero"),
        clouds: nil,
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "underwater_sprite_coral",   heightPoints: 100, weight: 3, scaleRange: 0.6...1.1, isTree: true),
                MidgroundProp(assetName: "underwater_sprite_seaweed", heightPoints: 125, weight: 3, scaleRange: 0.5...1.0, isTree: true),
                MidgroundProp(assetName: "underwater_sprite_coral_cluster",      heightPoints: 80, weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "underwater_sprite_sunken_stone_block", heightPoints: 65, weight: 2, scaleRange: 0.7...1.0),
            ]
        ),
        ground: ground("underwater_ground"),
        groundBase: groundBase("underwater_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let volcano = ThemeRecipe(
        hero: hero("volcano_hero"),
        clouds: clouds("volcano_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "volcano_sprite_lava_rock",         heightPoints: 88,  weight: 3, scaleRange: 0.7...1.1),
                MidgroundProp(assetName: "volcano_sprite_dead_tree_charred", heightPoints: 138, weight: 2, scaleRange: 0.6...1.0, isTree: true),
                MidgroundProp(assetName: "volcano_sprite_crystal_ember",     heightPoints: 81,  weight: 2, scaleRange: 0.6...1.0),
                MidgroundProp(assetName: "volcano_sprite_hot_spring",        heightPoints: 44,  weight: 1, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "volcano_sprite_lava_rock_cluster",  heightPoints: 80, weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "volcano_sprite_charred_stump",      heightPoints: 75, weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "volcano_sprite_basalt_pillar_base", heightPoints: 85, weight: 2, scaleRange: 0.7...1.0),
            ]
        ),
        ground: ground("volcano_ground"),
        groundBase: groundBase("volcano_foreground3"),
        overlays: [],
        contrastBudget: ContrastBudget(
            maxLuminanceVariance: 0.20,
            maxOpaquePixelDensity: 0.30,
            corridorHeightFraction: 0.50
        )
    )

    static let arctic = ThemeRecipe(
        hero: hero("arctic_hero"),
        clouds: clouds("arctic_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "arctic_sprite_pine_snow",   heightPoints: 163, weight: 3, scaleRange: 0.6...1.2, isTree: true),
                MidgroundProp(assetName: "arctic_sprite_ice_crystal", heightPoints: 94,  weight: 2, scaleRange: 0.6...1.0),
                MidgroundProp(assetName: "arctic_sprite_snowman",     heightPoints: 94,  weight: 1, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "arctic_sprite_snow_rock",   heightPoints: 63,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "arctic_sprite_snowy_ice_boulder_cluster",  heightPoints: 80, weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "arctic_sprite_half_buried_frozen_crate",   heightPoints: 80, weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "arctic_sprite_low_arctic_shrub_and_drift", heightPoints: 60, weight: 2, scaleRange: 0.7...1.0),
            ]
        ),
        ground: ground("arctic_ground"),
        groundBase: groundBase("arctic_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let western = ThemeRecipe(
        hero: hero("western_hero"),
        clouds: clouds("western_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "western_sprite_cactus",     heightPoints: 150, weight: 3, scaleRange: 0.6...1.0, isTree: true),
                MidgroundProp(assetName: "western_sprite_mesa",       heightPoints: 200, weight: 1, scaleRange: 0.8...1.2),
                MidgroundProp(assetName: "western_sprite_dead_tree",  heightPoints: 125, weight: 2, scaleRange: 0.7...1.0, isTree: true),
                MidgroundProp(assetName: "western_sprite_tumbleweed", heightPoints: 50,  weight: 2, scaleRange: 0.5...0.9),
                MidgroundProp(assetName: "western_sprite_skull",      heightPoints: 38,  weight: 1, scaleRange: 0.8...1.1),
                MidgroundProp(assetName: "western_sprite_barrel",     heightPoints: 63,  weight: 1, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "western_sprite_cactus_cluster",       heightPoints: 90, weight: 2, scaleRange: 0.7...1.0, isTree: true),
                MidgroundProp(assetName: "western_sprite_tumbleweed_and_rocks", heightPoints: 60, weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "western_sprite_broken_wagon_wheel",   heightPoints: 65, weight: 2, scaleRange: 0.7...1.0),
            ]
        ),
        ground: ground("western_ground"),
        groundBase: groundBase("western_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let jungle = ThemeRecipe(
        hero: hero("jungle_hero"),
        clouds: clouds("jungle_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "jungle_sprite_palm_tree",               heightPoints: 155, weight: 3, scaleRange: 0.7...1.1, isTree: true),
                MidgroundProp(assetName: "jungle_sprite_mushroom_big",            heightPoints: 65,  weight: 2, scaleRange: 0.6...1.0),
                MidgroundProp(assetName: "jungle_sprite_fern_and_red_plant_clump", heightPoints: 85, weight: 3, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "jungle_sprite_mossy_ruin_chunk",         heightPoints: 68, weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "jungle_sprite_fallen_jungle_log",        heightPoints: 50, weight: 2, scaleRange: 0.7...1.1),
            ],
            scrollSpeed: 0.35,
            spacingRange: 80...180
        ),
        ground: ground("jungle_ground"),
        groundBase: groundBase("jungle_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let cave = ThemeRecipe(
        hero: hero("cave_hero"),
        clouds: nil,
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "cave_sprite_stalagmite",           heightPoints: 125, weight: 6, scaleRange: 0.6...1.1, isTree: true),
                MidgroundProp(assetName: "cave_sprite_mushroom_glow",        heightPoints: 63,  weight: 2, scaleRange: 0.6...1.0),
                MidgroundProp(assetName: "cave_sprite_stalagmite_cluster",   heightPoints: 90,  weight: 2, scaleRange: 0.7...1.0, isTree: true),
                MidgroundProp(assetName: "cave_sprite_glowing_mushroom_patch", heightPoints: 60, weight: 2, scaleRange: 0.7...1.0),
            ]
        ),
        ground: ground("cave_ground"),
        groundBase: groundBase("cave_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let mountain = ThemeRecipe(
        hero: hero("mountain_hero"),
        clouds: clouds("mountain_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "mountain_sprite_boulder",  heightPoints: 50,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "mountain_sprite_log",      heightPoints: 35,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "mountain_sprite_alpine_rock_cluster",      heightPoints: 80, weight: 1, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "mountain_sprite_pine_tree",                 heightPoints: 155, weight: 3, scaleRange: 0.7...1.15, isTree: true),
                MidgroundProp(assetName: "mountain_sprite_pine_stump",                heightPoints: 75, weight: 1, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "mountain_sprite_snow_dusted_trail_marker",  heightPoints: 90, weight: 1, scaleRange: 0.7...1.0),
            ],
            scrollSpeed: 0.35,
            spacingRange: 100...180
        ),
        ground: ground("mountain_ground"),
        groundBase: groundBase("mountain_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let lagoon = ThemeRecipe(
        hero: hero("lagoon_hero"),
        clouds: clouds("lagoon_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "lagoon_sprite_palm_tropical",          heightPoints: 175, weight: 3, scaleRange: 0.6...1.2, isTree: true),
                MidgroundProp(assetName: "lagoon_sprite_beach_rock",             heightPoints: 44,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "lagoon_sprite_tropical_bush",          heightPoints: 75,  weight: 2, scaleRange: 0.6...1.0),
                MidgroundProp(assetName: "lagoon_sprite_coral_sand_mound",       heightPoints: 65,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "lagoon_sprite_driftwood_and_palm_sprout", heightPoints: 80, weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "lagoon_sprite_low_coral_rock",         heightPoints: 55,  weight: 2, scaleRange: 0.7...1.0),
            ]
        ),
        ground: ground("lagoon_ground"),
        groundBase: groundBase("lagoon_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let losAngeles = ThemeRecipe(
        hero: hero("losAngeles_hero"),
        clouds: clouds("losAngeles_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "losAngeles_sprite_palm_vibe",         heightPoints: 180, weight: 3, scaleRange: 0.7...1.15, isTree: true),
                MidgroundProp(assetName: "losAngeles_sprite_bush_trimmed",      heightPoints: 63,  weight: 2, scaleRange: 0.6...1.0),
                MidgroundProp(assetName: "losAngeles_sprite_dry_roadside_plants", heightPoints: 70, weight: 2, scaleRange: 0.7...1.0),
            ]
        ),
        ground: ground("losAngeles_ground"),
        groundBase: groundBase("losAngeles_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let london = ThemeRecipe(
        hero: hero("london_hero"),
        clouds: clouds("london_clouds"),
        ground: ground("london_ground"),
        groundBase: groundBase("london_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    // MARK: - Premium Themes (IAP)

    static let space = ThemeRecipe(
        hero: hero("space_hero"),
        clouds: nil,
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "space_sprite_alien_plant",           heightPoints: 120, weight: 3, scaleRange: 0.6...1.1, isTree: true),
                MidgroundProp(assetName: "space_sprite_alien_crystal_cluster",  heightPoints: 85,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "space_sprite_crystal_alien",         heightPoints: 90,  weight: 2, scaleRange: 0.6...1.0),
                MidgroundProp(assetName: "space_sprite_grounded_asteroid_rock", heightPoints: 70, weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "space_sprite_broken_satellite_debris", heightPoints: 65, weight: 1, scaleRange: 0.7...1.0),
            ],
            spacingRange: 120...250
        ),
        ground: ground("space_ground"),
        groundBase: groundBase("space_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let pixelTokyo = ThemeRecipe(
        hero: hero("pixelTokyo_hero"),
        clouds: clouds("pixelTokyo_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "pixelTokyo_sprite_cherry_blossom", heightPoints: 175, weight: 4, scaleRange: 0.5...1.4, yOffset: -15, isTree: true),
                MidgroundProp(assetName: "pixelTokyo_sprite_cherry_blossom", heightPoints: 175, weight: 4, scaleRange: 0.5...1.4, yOffset: 10,  isTree: true),
                MidgroundProp(assetName: "pixelTokyo_sprite_cherry_blossom", heightPoints: 175, weight: 4, scaleRange: 0.5...1.4, yOffset: 30,  isTree: true),
            ],
            scrollSpeed: 0.35,
            spacingRange: 50...110
        ),
        ground: ground("pixelTokyo_ground"),
        groundBase: groundBase("pixelTokyo_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let egypt = ThemeRecipe(
        hero: hero("egypt_hero"),
        clouds: clouds("egypt_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "egypt_sprite_palms_cluster",        heightPoints: 210, weight: 3, scaleRange: 0.8...1.1, isTree: true),
                MidgroundProp(assetName: "egypt_sprite_palm_desert",          heightPoints: 175, weight: 2, scaleRange: 0.7...1.1, isTree: true),
                MidgroundProp(assetName: "egypt_sprite_obelisk_tall",         heightPoints: 220, weight: 3, scaleRange: 0.8...1.0),
                MidgroundProp(assetName: "egypt_sprite_obelisk",              heightPoints: 210, weight: 2, scaleRange: 0.8...1.0),
                MidgroundProp(assetName: "egypt_sprite_pillar",               heightPoints: 200, weight: 2, scaleRange: 0.8...1.0),
                MidgroundProp(assetName: "egypt_sprite_sphinx_small",         heightPoints: 140, weight: 1, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "egypt_sprite_clay_pot",             heightPoints: 60,  weight: 1, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "egypt_sprite_broken_column_base",   heightPoints: 70,  weight: 1, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "egypt_sprite_nile_reed_cluster",    heightPoints: 100, weight: 2, scaleRange: 0.6...1.0),
                MidgroundProp(assetName: "egypt_sprite_sand_mound",           heightPoints: 55,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "egypt_sprite_sandstone_ruin_blocks", heightPoints: 75, weight: 1, scaleRange: 0.7...1.0),
            ],
            spacingRange: 150...300
        ),
        ground: ground("egypt_ground"),
        groundBase: groundBase("egypt_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )
}
