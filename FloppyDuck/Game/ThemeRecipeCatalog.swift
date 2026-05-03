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

    // MARK: - Free Themes

    static let day = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "day_hero",
            scrollSpeed: 0.0,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: LayerRecipe(
            assetName: "day_clouds",
            scrollSpeed: 0.15,
            heightPoints: 150,
            yAnchor: .horizon(offset: 350),
            tiles: true
        ),
        midground: LayerRecipe(
            assetName: "day_midground_trees",
            scrollSpeed: 0.35,
            heightPoints: 183,
            yAnchor: .top,
            tiles: true
        ),
        horizon: nil,
        ground: LayerRecipe(
            assetName: "day_foreground2",
            scrollSpeed: 1.0,
            heightPoints: GK.groundHeight,
            yAnchor: .ground,
            tiles: true
        ),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let sunset = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "sunset_hero",
            scrollSpeed: 0.0,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: nil,
        midground: nil,
        horizon: nil,
        ground: LayerRecipe(
            assetName: "sunset_foreground2",
            scrollSpeed: 1.0,
            heightPoints: GK.groundHeight,
            yAnchor: .ground,
            tiles: true
        ),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let night = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "night_hero",
            scrollSpeed: 0.0,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: nil,
        midground: nil,
        horizon: nil,
        ground: LayerRecipe(
            assetName: "night_foreground2",
            scrollSpeed: 1.0,
            heightPoints: GK.groundHeight,
            yAnchor: .ground,
            tiles: true
        ),
        overlays: [],
        contrastBudget: darkBudget
    )

    // MARK: - Normal Themes (Bread Currency)

    static let neonCity = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "neonCity_hero",
            scrollSpeed: 0.0,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: nil,
        midground: nil,
        horizon: nil,
        ground: LayerRecipe(
            assetName: "neonCity_foreground2",
            scrollSpeed: 1.0,
            heightPoints: GK.groundHeight,
            yAnchor: .ground,
            tiles: true
        ),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let underwater = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "underwater_hero",
            scrollSpeed: 0.0,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: nil,
        midground: nil,
        horizon: nil,
        ground: LayerRecipe(
            assetName: "underwater_foreground2",
            scrollSpeed: 1.0,
            heightPoints: GK.groundHeight,
            yAnchor: .ground,
            tiles: true
        ),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let volcano = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "volcano_hero",
            scrollSpeed: 0.0,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: nil,
        midground: nil,
        horizon: nil,
        ground: LayerRecipe(
            assetName: "volcano_foreground2",
            scrollSpeed: 1.0,
            heightPoints: GK.groundHeight,
            yAnchor: .ground,
            tiles: true
        ),
        overlays: [],
        contrastBudget: ContrastBudget(
            maxLuminanceVariance: 0.20,
            maxOpaquePixelDensity: 0.30,
            corridorHeightFraction: 0.50
        )
    )

    static let arctic = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "arctic_hero",
            scrollSpeed: 0.0,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: nil,
        midground: nil,
        horizon: nil,
        ground: LayerRecipe(
            assetName: "arctic_foreground2",
            scrollSpeed: 1.0,
            heightPoints: GK.groundHeight,
            yAnchor: .ground,
            tiles: true
        ),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let western = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "western_hero",
            scrollSpeed: 0.0,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: nil,
        midground: nil,
        horizon: nil,
        ground: LayerRecipe(
            assetName: "western_foreground2",
            scrollSpeed: 1.0,
            heightPoints: GK.groundHeight,
            yAnchor: .ground,
            tiles: true
        ),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let jungle = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "jungle_hero",
            scrollSpeed: 0.0,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: nil,
        midground: nil,
        horizon: nil,
        ground: LayerRecipe(
            assetName: "jungle_foreground2",
            scrollSpeed: 1.0,
            heightPoints: GK.groundHeight,
            yAnchor: .ground,
            tiles: true
        ),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let cave = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "cave_hero",
            scrollSpeed: 0.0,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: nil,
        midground: nil,
        horizon: nil,
        ground: LayerRecipe(
            assetName: "cave_foreground2",
            scrollSpeed: 1.0,
            heightPoints: GK.groundHeight,
            yAnchor: .ground,
            tiles: true
        ),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let mountain = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "mountain_hero",
            scrollSpeed: 0.0,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: nil,
        midground: nil,
        horizon: nil,
        ground: LayerRecipe(
            assetName: "mountain_foreground2",
            scrollSpeed: 1.0,
            heightPoints: GK.groundHeight,
            yAnchor: .ground,
            tiles: true
        ),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let lagoon = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "lagoon_hero",
            scrollSpeed: 0.0,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: nil,
        midground: nil,
        horizon: nil,
        ground: LayerRecipe(
            assetName: "lagoon_foreground2",
            scrollSpeed: 1.0,
            heightPoints: GK.groundHeight,
            yAnchor: .ground,
            tiles: true
        ),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let losAngeles = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "losAngeles_hero",
            scrollSpeed: 0.0,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: nil,
        midground: nil,
        horizon: nil,
        ground: LayerRecipe(
            assetName: "losAngeles_foreground2",
            scrollSpeed: 1.0,
            heightPoints: GK.groundHeight,
            yAnchor: .ground,
            tiles: true
        ),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let london = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "london_hero",
            scrollSpeed: 0.0,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: nil,
        midground: nil,
        horizon: nil,
        ground: LayerRecipe(
            assetName: "london_foreground2",
            scrollSpeed: 1.0,
            heightPoints: GK.groundHeight,
            yAnchor: .ground,
            tiles: true
        ),
        overlays: [],
        contrastBudget: defaultBudget
    )

    static let roughOcean = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "roughOcean_hero",
            scrollSpeed: 0.01,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: nil,
        midground: nil,
        horizon: nil,
        ground: nil,
        overlays: [],
        contrastBudget: darkBudget
    )

    // MARK: - Premium Themes (IAP)

    static let space = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "space_hero",
            scrollSpeed: 0.0,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: nil,
        midground: nil,
        horizon: nil,
        ground: LayerRecipe(
            assetName: "space_foreground2",
            scrollSpeed: 1.0,
            heightPoints: GK.groundHeight,
            yAnchor: .ground,
            tiles: true
        ),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let pixelTokyo = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "pixelTokyo_hero",
            scrollSpeed: 0.0,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: nil,
        midground: nil,
        horizon: nil,
        ground: LayerRecipe(
            assetName: "pixelTokyo_foreground2",
            scrollSpeed: 1.0,
            heightPoints: GK.groundHeight,
            yAnchor: .ground,
            tiles: true
        ),
        overlays: [],
        contrastBudget: darkBudget
    )

    static let egypt = ThemeRecipe(
        hero: LayerRecipe(
            assetName: "egypt_hero",
            scrollSpeed: 0.0,
            heightPoints: 620,
            yAnchor: .top,
            tiles: true
        ),
        clouds: nil,
        midground: nil,
        horizon: nil,
        ground: LayerRecipe(
            assetName: "egypt_foreground2",
            scrollSpeed: 1.0,
            heightPoints: GK.groundHeight,
            yAnchor: .ground,
            tiles: true
        ),
        overlays: [],
        contrastBudget: defaultBudget
    )
}
