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

    /// Hero layer — always full-height, anchored top. scrollSpeed is handled by
    /// `spriteLayers()` via `ThemeRecipe.heroScrollFraction`, so we pass 0 here.
    private static func hero(_ name: String) -> LayerRecipe {
        LayerRecipe(assetName: name, scrollSpeed: 0, heightPoints: 620, yAnchor: .top)
    }

    /// Standard cloud layer — 150pt tall, 15% ground speed, sits above midground.
    private static func clouds(_ name: String) -> LayerRecipe {
        LayerRecipe(assetName: name, scrollSpeed: 0.15, heightPoints: 150, yAnchor: .horizon(offset: 350))
    }

    /// Ground surface tile (grass, road, etc.) — 80pt, full speed, anchored to ground.
    private static func ground(_ name: String) -> LayerRecipe {
        LayerRecipe(assetName: name, scrollSpeed: 1.0, heightPoints: GK.groundHeight, yAnchor: .ground)
    }

    /// Ground base layer (dirt, rocks) — 100pt, full speed, anchored to ground.
    private static func groundBase(_ name: String) -> LayerRecipe {
        LayerRecipe(assetName: name, scrollSpeed: 1.0, heightPoints: 100, yAnchor: .ground)
    }

    // MARK: - Free Themes

    static let day = ThemeRecipe(
        hero: hero("day_hero"),
        clouds: clouds("day_clouds"),
        midground: LayerRecipe(
            assetName: "day_midground_trees",
            scrollSpeed: 0.35,
            heightPoints: 350,
            yAnchor: .top
        ),
        horizon: nil,
        ground: ground("day_foreground2"),
        groundBase: groundBase("day_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let sunset = ThemeRecipe(
        hero: hero("sunset_hero"),
        clouds: clouds("sunset_clouds"),
        midground: LayerRecipe(
            assetName: "sunset_midground_trees",
            scrollSpeed: 0.35,
            heightPoints: 200,
            yAnchor: .top
        ),
        horizon: nil,
        ground: ground("sunset_foreground2"),
        groundBase: groundBase("sunset_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let night = ThemeRecipe(
        hero: hero("night_hero"),
        clouds: clouds("night_clouds"),
        midground: LayerRecipe(
            assetName: "night_midground_buildings",
            scrollSpeed: 0.35,
            heightPoints: 293,
            yAnchor: .ground
        ),
        horizon: nil,
        ground: ground("night_foreground2"),
        groundBase: groundBase("night_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    // MARK: - Normal Themes (Bread Currency)

    static let neonCity = ThemeRecipe(
        hero: hero("neonCity_hero"),
        clouds: clouds("neonCity_clouds"),
        midground: LayerRecipe(
            assetName: "neonCity_midground_buildings",
            scrollSpeed: 0.35,
            heightPoints: 400,
            yAnchor: .ground
        ),
        horizon: nil,
        ground: ground("neonCity_foreground2"),
        groundBase: groundBase("neonCity_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let underwater = ThemeRecipe(
        hero: hero("underwater_hero"),
        clouds: nil,
        midground: LayerRecipe(
            assetName: "underwater_midground_coral",
            scrollSpeed: 0.35,
            heightPoints: 426,
            yAnchor: .ground
        ),
        horizon: nil,
        ground: ground("underwater_foreground2"),
        groundBase: groundBase("underwater_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let volcano = ThemeRecipe(
        hero: hero("volcano_hero"),
        clouds: clouds("volcano_clouds"),
        midground: LayerRecipe(
            assetName: "volcano_midground_rocks",
            scrollSpeed: 0.35,
            heightPoints: 267,
            yAnchor: .top
        ),
        horizon: nil,
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
        midground: LayerRecipe(
            assetName: "arctic_midground_trees",
            scrollSpeed: 0.35,
            heightPoints: 300,
            yAnchor: .top
        ),
        horizon: nil,
        ground: ground("arctic_foreground2"),
        groundBase: groundBase("arctic_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let western = ThemeRecipe(
        hero: hero("western_hero"),
        clouds: clouds("western_clouds"),
        midground: LayerRecipe(
            assetName: "western_midground_rocks",
            scrollSpeed: 0.35,
            heightPoints: 250,
            yAnchor: .top
        ),
        horizon: nil,
        ground: ground("western_foreground2"),
        groundBase: groundBase("western_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let jungle = ThemeRecipe(
        hero: hero("jungle_hero"),
        clouds: clouds("jungle_clouds"),
        midground: LayerRecipe(
            assetName: "jungle_midground_trees",
            scrollSpeed: 0.35,
            heightPoints: 300,
            yAnchor: .top
        ),
        horizon: nil,
        ground: ground("jungle_foreground2"),
        groundBase: groundBase("jungle_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let cave = ThemeRecipe(
        hero: hero("cave_hero"),
        clouds: nil,
        midground: LayerRecipe(
            assetName: "cave_midground_rocks",
            scrollSpeed: 0.35,
            heightPoints: 400,
            yAnchor: .ground
        ),
        horizon: nil,
        ground: ground("cave_foreground2"),
        groundBase: groundBase("cave_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let mountain = ThemeRecipe(
        hero: hero("mountain_hero"),
        clouds: clouds("mountain_clouds"),
        midground: LayerRecipe(
            assetName: "mountain_midground_trees",
            scrollSpeed: 0.35,
            heightPoints: 200,
            yAnchor: .top
        ),
        horizon: nil,
        ground: ground("mountain_foreground2"),
        groundBase: groundBase("mountain_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let lagoon = ThemeRecipe(
        hero: hero("lagoon_hero"),
        clouds: clouds("lagoon_clouds"),
        midground: LayerRecipe(
            assetName: "lagoon_midground_palms",
            scrollSpeed: 0.35,
            heightPoints: 300,
            yAnchor: .top
        ),
        horizon: nil,
        ground: ground("lagoon_foreground2"),
        groundBase: groundBase("lagoon_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let losAngeles = ThemeRecipe(
        hero: hero("losAngeles_hero"),
        clouds: clouds("losAngeles_clouds"),
        midground: LayerRecipe(
            assetName: "losAngeles_midground_palms",
            scrollSpeed: 0.35,
            heightPoints: 300,
            yAnchor: .top
        ),
        horizon: nil,
        ground: ground("losAngeles_foreground2"),
        groundBase: groundBase("losAngeles_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let london = ThemeRecipe(
        hero: hero("london_hero"),
        clouds: clouds("london_clouds"),
        midground: LayerRecipe(
            assetName: "london_midground_buildings",
            scrollSpeed: 0.35,
            heightPoints: 350,
            yAnchor: .ground
        ),
        horizon: nil,
        ground: ground("london_foreground2"),
        groundBase: groundBase("london_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let roughOcean = ThemeRecipe(
        hero: hero("roughOcean_hero"),
        clouds: clouds("roughOcean_clouds"),
        midground: LayerRecipe(
            assetName: "roughOcean_midground_shore",
            scrollSpeed: 0.35,
            heightPoints: 300,
            yAnchor: .top
        ),
        horizon: nil,
        ground: nil,
        groundBase: nil,
        overlays: [],
        contrastBudget: darkBudget
    )

    // MARK: - Premium Themes (IAP)

    static let space = ThemeRecipe(
        hero: hero("space_hero"),
        clouds: nil,
        midground: LayerRecipe(
            assetName: "space_midground_rocks",
            scrollSpeed: 0.35,
            heightPoints: 250,
            yAnchor: .top
        ),
        horizon: nil,
        ground: ground("space_foreground2"),
        groundBase: groundBase("space_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let pixelTokyo = ThemeRecipe(
        hero: hero("pixelTokyo_hero"),
        clouds: clouds("pixelTokyo_clouds"),
        midground: LayerRecipe(
            assetName: "pixelTokyo_midground_buildings",
            scrollSpeed: 0.35,
            heightPoints: 350,
            yAnchor: .ground
        ),
        horizon: nil,
        ground: ground("pixelTokyo_foreground2"),
        groundBase: groundBase("pixelTokyo_foreground3"),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let egypt = ThemeRecipe(
        hero: hero("egypt_hero"),
        clouds: clouds("egypt_clouds"),
        midground: LayerRecipe(
            assetName: "egypt_midground_ruins",
            scrollSpeed: 0.35,
            heightPoints: 350,
            yAnchor: .top
        ),
        horizon: nil,
        ground: ground("egypt_foreground2"),
        groundBase: groundBase("egypt_foreground3"),
        overlays: [],
        contrastBudget: defaultBudget
    )
}
