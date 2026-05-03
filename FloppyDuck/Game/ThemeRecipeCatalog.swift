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
        case .roughOcean:  return roughOcean
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
                MidgroundProp(assetName: "day_sprite_oak_tree",  heightPoints: 130, weight: 3, scaleRange: 0.7...1.2),
                MidgroundProp(assetName: "day_sprite_bush",      heightPoints: 50,  weight: 3, scaleRange: 0.6...1.0),
                MidgroundProp(assetName: "day_sprite_flowers",   heightPoints: 35,  weight: 2, scaleRange: 0.5...0.9),
                MidgroundProp(assetName: "day_sprite_rock",      heightPoints: 40,  weight: 2, scaleRange: 0.7...1.0),
            ]
        ),
        ground: ground("day_foreground2"),
        groundBase: groundBase("day_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let sunset = ThemeRecipe(
        hero: hero("sunset_hero"),
        clouds: clouds("sunset_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "sunset_sprite_palm_silhouette", heightPoints: 150, weight: 3, scaleRange: 0.6...1.2),
                MidgroundProp(assetName: "sunset_sprite_tall_grass",     heightPoints: 60,  weight: 3, scaleRange: 0.5...0.9),
                MidgroundProp(assetName: "sunset_sprite_fence_post",     heightPoints: 70,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "sunset_sprite_hay_bale",       heightPoints: 50,  weight: 2, scaleRange: 0.7...1.0),
            ]
        ),
        ground: ground("sunset_foreground2"),
        groundBase: groundBase("sunset_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let night = ThemeRecipe(
        hero: hero("night_hero"),
        clouds: clouds("night_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "night_sprite_lamp_post", heightPoints: 140, weight: 3, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "night_sprite_bench",     heightPoints: 40,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "night_sprite_tree_dark", heightPoints: 130, weight: 2, scaleRange: 0.6...1.1),
                MidgroundProp(assetName: "night_sprite_mailbox",   heightPoints: 50,  weight: 1, scaleRange: 0.8...1.0),
            ]
        ),
        ground: ground("night_foreground2"),
        groundBase: groundBase("night_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    // MARK: - Normal Themes (Bread Currency)

    static let neonCity = ThemeRecipe(
        hero: hero("neonCity_hero"),
        clouds: clouds("neonCity_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "neonCity_sprite_neon_sign",       heightPoints: 70,  weight: 3, scaleRange: 0.7...1.1, yOffset: 20),
                MidgroundProp(assetName: "neonCity_sprite_trash_can",       heightPoints: 50,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "neonCity_sprite_street_lamp_neon", heightPoints: 140, weight: 3, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "neonCity_sprite_vending_machine", heightPoints: 80,  weight: 2, scaleRange: 0.8...1.0),
            ]
        ),
        ground: ground("neonCity_foreground2"),
        groundBase: groundBase("neonCity_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let underwater = ThemeRecipe(
        hero: hero("underwater_hero"),
        clouds: nil,
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "underwater_sprite_coral",   heightPoints: 80,  weight: 3, scaleRange: 0.6...1.1),
                MidgroundProp(assetName: "underwater_sprite_seaweed", heightPoints: 100, weight: 3, scaleRange: 0.5...1.0),
                MidgroundProp(assetName: "underwater_sprite_anemone", heightPoints: 50,  weight: 2, scaleRange: 0.6...1.0),
                MidgroundProp(assetName: "underwater_sprite_treasure", heightPoints: 40, weight: 1, scaleRange: 0.8...1.0),
            ]
        ),
        ground: ground("underwater_foreground2"),
        groundBase: groundBase("underwater_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let volcano = ThemeRecipe(
        hero: hero("volcano_hero"),
        clouds: clouds("volcano_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "volcano_sprite_lava_rock",        heightPoints: 70,  weight: 3, scaleRange: 0.7...1.1),
                MidgroundProp(assetName: "volcano_sprite_dead_tree_charred", heightPoints: 110, weight: 2, scaleRange: 0.6...1.0),
                MidgroundProp(assetName: "volcano_sprite_crystal_ember",    heightPoints: 65,  weight: 2, scaleRange: 0.6...1.0),
                MidgroundProp(assetName: "volcano_sprite_hot_spring",       heightPoints: 35,  weight: 1, scaleRange: 0.7...1.0),
            ]
        ),
        ground: ground("volcano_foreground2"),
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
                MidgroundProp(assetName: "arctic_sprite_pine_snow",   heightPoints: 130, weight: 3, scaleRange: 0.6...1.2),
                MidgroundProp(assetName: "arctic_sprite_ice_crystal", heightPoints: 75,  weight: 2, scaleRange: 0.6...1.0),
                MidgroundProp(assetName: "arctic_sprite_snowman",     heightPoints: 75,  weight: 1, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "arctic_sprite_snow_rock",   heightPoints: 50,  weight: 2, scaleRange: 0.7...1.0),
            ]
        ),
        ground: ground("arctic_foreground2"),
        groundBase: groundBase("arctic_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let western = ThemeRecipe(
        hero: hero("western_hero"),
        clouds: clouds("western_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "western_sprite_cactus",     heightPoints: 120, weight: 3, scaleRange: 0.6...1.0),
                MidgroundProp(assetName: "western_sprite_mesa",       heightPoints: 160, weight: 1, scaleRange: 0.8...1.2),
                MidgroundProp(assetName: "western_sprite_dead_tree",  heightPoints: 100, weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "western_sprite_tumbleweed", heightPoints: 40,  weight: 2, scaleRange: 0.5...0.9),
                MidgroundProp(assetName: "western_sprite_skull",      heightPoints: 30,  weight: 1, scaleRange: 0.8...1.1),
                MidgroundProp(assetName: "western_sprite_barrel",     heightPoints: 50,  weight: 1, scaleRange: 0.7...1.0),
            ]
        ),
        ground: ground("western_foreground2"),
        groundBase: groundBase("western_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let jungle = ThemeRecipe(
        hero: hero("jungle_hero"),
        clouds: clouds("jungle_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "jungle_sprite_palm_tree",    heightPoints: 160, weight: 3, scaleRange: 0.6...1.2),
                MidgroundProp(assetName: "jungle_sprite_fern",         heightPoints: 60,  weight: 3, scaleRange: 0.5...1.0),
                MidgroundProp(assetName: "jungle_sprite_mushroom_big", heightPoints: 65,  weight: 2, scaleRange: 0.6...1.0),
            ]
        ),
        ground: ground("jungle_foreground2"),
        groundBase: groundBase("jungle_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let cave = ThemeRecipe(
        hero: hero("cave_hero"),
        clouds: nil,
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "cave_sprite_stalagmite",    heightPoints: 100, weight: 3, scaleRange: 0.6...1.1),
                MidgroundProp(assetName: "cave_sprite_crystal_blue",  heightPoints: 75,  weight: 3, scaleRange: 0.5...1.0),
                MidgroundProp(assetName: "cave_sprite_mushroom_glow", heightPoints: 50,  weight: 2, scaleRange: 0.6...1.0),
            ]
        ),
        ground: ground("cave_foreground2"),
        groundBase: groundBase("cave_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let mountain = ThemeRecipe(
        hero: hero("mountain_hero"),
        clouds: clouds("mountain_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "mountain_sprite_pine_tree",  heightPoints: 140, weight: 3, scaleRange: 0.6...1.2),
                MidgroundProp(assetName: "mountain_sprite_boulder",    heightPoints: 55,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "mountain_sprite_log",        heightPoints: 30,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "mountain_sprite_snow_bush",  heightPoints: 50,  weight: 2, scaleRange: 0.6...1.0),
            ]
        ),
        ground: ground("mountain_foreground2"),
        groundBase: groundBase("mountain_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let lagoon = ThemeRecipe(
        hero: hero("lagoon_hero"),
        clouds: clouds("lagoon_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "lagoon_sprite_palm_tropical", heightPoints: 140, weight: 3, scaleRange: 0.6...1.2),
                MidgroundProp(assetName: "lagoon_sprite_beach_rock",    heightPoints: 35,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "lagoon_sprite_seashell",      heightPoints: 30,  weight: 2, scaleRange: 0.6...0.9),
                MidgroundProp(assetName: "lagoon_sprite_tropical_bush", heightPoints: 60,  weight: 2, scaleRange: 0.6...1.0),
            ]
        ),
        ground: ground("lagoon_foreground2"),
        groundBase: groundBase("lagoon_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let losAngeles = ThemeRecipe(
        hero: hero("losAngeles_hero"),
        clouds: clouds("losAngeles_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "losAngeles_sprite_palm_la",      heightPoints: 160, weight: 3, scaleRange: 0.6...1.1),
                MidgroundProp(assetName: "losAngeles_sprite_fire_hydrant", heightPoints: 35,  weight: 2, scaleRange: 0.8...1.0),
                MidgroundProp(assetName: "losAngeles_sprite_bush_trimmed", heightPoints: 50,  weight: 2, scaleRange: 0.6...1.0),
            ]
        ),
        ground: ground("losAngeles_foreground2"),
        groundBase: groundBase("losAngeles_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let london = ThemeRecipe(
        hero: hero("london_hero"),
        clouds: clouds("london_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "london_sprite_phone_booth", heightPoints: 80,  weight: 2, scaleRange: 0.8...1.0),
                MidgroundProp(assetName: "london_sprite_mailbox_red", heightPoints: 50,  weight: 2, scaleRange: 0.8...1.0),
                MidgroundProp(assetName: "london_sprite_bench_park",  heightPoints: 40,  weight: 2, scaleRange: 0.7...1.0),
            ]
        ),
        ground: ground("london_foreground2"),
        groundBase: groundBase("london_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let roughOcean = ThemeRecipe(
        hero: hero("roughOcean_hero"),
        clouds: clouds("roughOcean_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "roughOcean_sprite_buoy",      heightPoints: 60,  weight: 3, scaleRange: 0.7...1.0, yOffset: 10),
                MidgroundProp(assetName: "roughOcean_sprite_rock_sea",  heightPoints: 55,  weight: 3, scaleRange: 0.7...1.1),
                MidgroundProp(assetName: "roughOcean_sprite_driftwood", heightPoints: 25,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "roughOcean_sprite_seagull",   heightPoints: 35,  weight: 1, scaleRange: 0.7...1.0, yOffset: 15),
            ]
        ),
        ground: nil,
        groundBase: nil,
        overlays: [],
        contrastBudget: darkBudget
    )

    // MARK: - Premium Themes (IAP)

    static let space = ThemeRecipe(
        hero: hero("space_hero"),
        clouds: nil,
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "space_sprite_asteroid",       heightPoints: 65,  weight: 3, scaleRange: 0.5...1.2, yOffset: 20),
                MidgroundProp(assetName: "space_sprite_crystal_alien",  heightPoints: 75,  weight: 2, scaleRange: 0.5...1.0),
                MidgroundProp(assetName: "space_sprite_satellite_dish", heightPoints: 65,  weight: 1, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "space_sprite_alien_plant",    heightPoints: 75,  weight: 2, scaleRange: 0.5...0.9),
            ]
        ),
        ground: ground("space_foreground2"),
        groundBase: groundBase("space_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let pixelTokyo = ThemeRecipe(
        hero: hero("pixelTokyo_hero"),
        clouds: clouds("pixelTokyo_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "pixelTokyo_sprite_vending_machine_jp", heightPoints: 80,  weight: 3, scaleRange: 0.8...1.0),
                MidgroundProp(assetName: "pixelTokyo_sprite_lantern",            heightPoints: 65,  weight: 3, scaleRange: 0.6...1.0, yOffset: 15),
                MidgroundProp(assetName: "pixelTokyo_sprite_cherry_blossom",     heightPoints: 140, weight: 2, scaleRange: 0.6...1.1),
                MidgroundProp(assetName: "pixelTokyo_sprite_torii_gate",         heightPoints: 110, weight: 1, scaleRange: 0.8...1.0),
            ]
        ),
        ground: ground("pixelTokyo_foreground2"),
        groundBase: groundBase("pixelTokyo_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let egypt = ThemeRecipe(
        hero: hero("egypt_hero"),
        clouds: clouds("egypt_clouds"),
        midgroundSprites: MidgroundSpawnConfig(
            props: [
                MidgroundProp(assetName: "egypt_sprite_palm_desert",  heightPoints: 140, weight: 3, scaleRange: 0.6...1.2),
                MidgroundProp(assetName: "egypt_sprite_clay_pot",     heightPoints: 45,  weight: 2, scaleRange: 0.7...1.0),
                MidgroundProp(assetName: "egypt_sprite_obelisk",      heightPoints: 100, weight: 2, scaleRange: 0.8...1.0),
                MidgroundProp(assetName: "egypt_sprite_sphinx_small", heightPoints: 55,  weight: 1, scaleRange: 0.8...1.0),
            ]
        ),
        ground: ground("egypt_foreground2"),
        groundBase: groundBase("egypt_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )
}
