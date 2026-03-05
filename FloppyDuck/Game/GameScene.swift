import SpriteKit

// MARK: - Game Phase

enum GamePhase {
    case ready
    case countdown
    case playing
    case dead
    case gameOver
}

// MARK: - Delegate

protocol GameSceneDelegate: AnyObject {
    func gameDidStart()
    func gameDidScore(_ score: Int)
    func gameDidEnd(score: Int)
    func botDidScore(_ botScore: Int)
}

// MARK: - GameScene

final class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Properties

    weak var gameDelegate: GameSceneDelegate?

    private(set) var phase: GamePhase = .ready
    private(set) var score: Int = 0
    private(set) var botScore: Int = 0

    private var prng: SeededRandom
    private var gapPositions: [CGFloat] = []
    private var pipeIndex: Int = 0

    private let factory = TextureFactory.shared
    private let mode: GameMode

    // Layers
    private let worldNode = SKNode()
    private let backgroundLayer = SKNode()
    private let pipeLayer = SKNode()
    private let groundLayer = SKNode()
    private let hudLayer = SKNode()

    // Duck
    private var duck: SKSpriteNode!
    private var duckTextures: [SKTexture] = []

    // Bot ghost
    private var botDuck: SKSpriteNode?
    private var botTextures: [SKTexture] = []
    private var botY: CGFloat = GK.duckStartY
    private var botVelocity: CGFloat = 0
    private var botAlive: Bool = true
    private var botPipesPassed: Set<String> = []
    private var botScoreLabel: SKLabelNode?
    private var botScoreShadow: SKLabelNode?

    // Score
    private var scoreLabel: SKLabelNode!
    private var scoreShadow: SKLabelNode!
    private var scoreBacking: SKShapeNode!

    // Ground scrolling
    private var groundTiles: [SKSpriteNode] = []
    private let groundTileWidth: CGFloat = GK.worldWidth * 2

    // Pipe spawning
    private var pipeTimer: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0

    // Parallax layers
    private var clouds: [SKSpriteNode] = []
    private var hills: [SKSpriteNode] = []
    private var trees: [SKSpriteNode] = []

    // MARK: - Init

    init(seed: Int = Int.random(in: 1...999999), mode: GameMode = .classic) {
        self.prng = SeededRandom(seed: seed)
        self.mode = mode
        super.init(size: CGSize(width: GK.worldWidth, height: GK.worldHeight))
        self.scaleMode = .aspectFill
        self.gapPositions = prng.generateGapPositions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.35, green: 0.65, blue: 0.90, alpha: 1)
        physicsWorld.gravity = CGVector(dx: 0, dy: GK.gravity / 60)
        physicsWorld.contactDelegate = self

        addChild(worldNode)
        worldNode.addChild(backgroundLayer)
        worldNode.addChild(pipeLayer)
        worldNode.addChild(groundLayer)
        addChild(hudLayer)

        setupBackground()
        setupClouds()
        setupHills()
        setupTrees()
        setupGround()
        setupDuck()
        setupHUD()

        if mode == .vsBot {
            setupBotDuck()
        }

        // Duck floats gently before first tap
        let float = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 10, duration: 0.5),
            SKAction.moveBy(x: 0, y: -10, duration: 0.5)
        ])
        duck.run(SKAction.repeatForever(float), withKey: "float")
        duck.physicsBody?.isDynamic = false
    }

    // MARK: - Background

    private func setupBackground() {
        let skyTex = factory.skyTexture()
        let skyNode = SKSpriteNode(texture: skyTex,
                                    size: CGSize(width: GK.worldWidth, height: GK.worldHeight))
        skyNode.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight / 2)
        skyNode.zPosition = -100
        backgroundLayer.addChild(skyNode)
    }

    private func setupClouds() {
        let cloudTex = factory.cloudTexture()
        for _ in 0..<5 {
            let scale = CGFloat.random(in: 0.6...1.2)
            let cloud = SKSpriteNode(texture: cloudTex,
                                      size: CGSize(width: 80 * scale, height: 35 * scale))
            cloud.position = CGPoint(
                x: CGFloat.random(in: 0...GK.worldWidth),
                y: CGFloat.random(in: (GK.worldHeight * 0.55)...(GK.worldHeight - 40))
            )
            cloud.alpha = CGFloat.random(in: 0.5...0.8)
            cloud.zPosition = -90
            backgroundLayer.addChild(cloud)
            clouds.append(cloud)
        }
    }

    private func setupHills() {
        let hillTex = factory.hillsTexture()
        for i in 0..<2 {
            let hillNode = SKSpriteNode(texture: hillTex,
                                         size: CGSize(width: GK.worldWidth * 2, height: 120))
            hillNode.anchorPoint = CGPoint(x: 0, y: 0)
            hillNode.position = CGPoint(x: CGFloat(i) * GK.worldWidth * 2, y: GK.groundHeight + 10)
            hillNode.zPosition = -60
            hillNode.alpha = 0.8
            backgroundLayer.addChild(hillNode)
            hills.append(hillNode)
        }
    }

    private func setupTrees() {
        let treeTex = factory.treesTexture()
        for i in 0..<2 {
            let treeNode = SKSpriteNode(texture: treeTex,
                                         size: CGSize(width: GK.worldWidth * 2, height: 160))
            treeNode.anchorPoint = CGPoint(x: 0, y: 0)
            treeNode.position = CGPoint(x: CGFloat(i) * GK.worldWidth * 2, y: GK.groundHeight - 5)
            treeNode.zPosition = -50
            treeNode.alpha = 0.7
            backgroundLayer.addChild(treeNode)
            trees.append(treeNode)
        }
    }

    // MARK: - Ground

    private func setupGround() {
        let groundTex = factory.groundTexture()
        let tilesNeeded = 3
        for i in 0..<tilesNeeded {
            let tile = SKSpriteNode(texture: groundTex,
                                     size: CGSize(width: groundTileWidth, height: GK.groundHeight))
            tile.anchorPoint = CGPoint(x: 0, y: 0)
            tile.position = CGPoint(x: CGFloat(i) * groundTileWidth, y: 0)
            tile.zPosition = 50
            groundLayer.addChild(tile)
            groundTiles.append(tile)
        }

        // Ground physics
        let groundBody = SKNode()
        groundBody.position = CGPoint(x: GK.worldWidth / 2, y: GK.groundHeight)
        groundBody.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.worldWidth * 2, height: 2))
        groundBody.physicsBody?.isDynamic = false
        groundBody.physicsBody?.categoryBitMask = GK.groundCategory
        groundBody.physicsBody?.contactTestBitMask = GK.duckCategory
        worldNode.addChild(groundBody)

        // Ceiling
        let ceiling = SKNode()
        ceiling.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight + 20)
        ceiling.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.worldWidth * 2, height: 2))
        ceiling.physicsBody?.isDynamic = false
        worldNode.addChild(ceiling)
    }

    // MARK: - Duck

    private func setupDuck() {
        duckTextures = (0...2).map { factory.duckTexture(wingPhase: $0) }

        // 16:11 ratio from pixel grid
        duck = SKSpriteNode(texture: duckTextures[1],
                            size: CGSize(width: GK.duckRadius * 2.8, height: GK.duckRadius * 1.9))
        duck.position = CGPoint(x: GK.duckStartX, y: GK.duckStartY)
        duck.zPosition = 40

        duck.physicsBody = SKPhysicsBody(circleOfRadius: GK.duckRadius * 0.85)
        duck.physicsBody?.categoryBitMask = GK.duckCategory
        duck.physicsBody?.contactTestBitMask = GK.pipeCategory | GK.groundCategory
        duck.physicsBody?.collisionBitMask = GK.groundCategory | GK.pipeCategory
        duck.physicsBody?.allowsRotation = false
        duck.physicsBody?.restitution = 0
        duck.physicsBody?.linearDamping = 0
        duck.physicsBody?.usesPreciseCollisionDetection = true

        worldNode.addChild(duck)
        startWingAnimation()
    }

    private func startWingAnimation() {
        let wingAction = SKAction.animate(with: duckTextures, timePerFrame: 0.12)
        duck.run(SKAction.repeatForever(wingAction), withKey: "wings")
    }

    // MARK: - Bot Ghost Duck

    private func setupBotDuck() {
        botTextures = (0...2).map { factory.botDuckTexture(wingPhase: $0) }

        let bot = SKSpriteNode(texture: botTextures[1],
                               size: CGSize(width: GK.duckRadius * 2.8, height: GK.duckRadius * 1.9))
        bot.position = CGPoint(x: GK.duckStartX, y: GK.duckStartY)
        bot.zPosition = 35  // behind player duck

        // Wing animation for bot
        let wingAction = SKAction.animate(with: botTextures, timePerFrame: 0.12)
        bot.run(SKAction.repeatForever(wingAction), withKey: "botWings")

        // Gentle float before start
        let float = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 10, duration: 0.5),
            SKAction.moveBy(x: 0, y: -10, duration: 0.5)
        ])
        bot.run(SKAction.repeatForever(float), withKey: "botFloat")

        worldNode.addChild(bot)
        botDuck = bot
        botY = GK.duckStartY
        botVelocity = 0
        botAlive = true
    }

    // MARK: - HUD

    private func setupHUD() {
        // Semi-transparent backing for score
        scoreBacking = SKShapeNode(circleOfRadius: 26)
        scoreBacking.fillColor = UIColor(white: 0, alpha: 0.25)
        scoreBacking.strokeColor = .clear
        scoreBacking.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight - 76)
        scoreBacking.zPosition = 198
        hudLayer.addChild(scoreBacking)

        // Thick outline (multiple offset layers)
        let outlineOffsets: [(CGFloat, CGFloat)] = [
            (-2, -2), (-2, 0), (-2, 2),
            (0, -2),           (0, 2),
            (2, -2),  (2, 0),  (2, 2),
            (0, -3), (0, 3), (-3, 0), (3, 0)
        ]
        for offset in outlineOffsets {
            let outline = SKLabelNode(fontNamed: GK.pixelFontName)
            outline.fontSize = 36
            outline.fontColor = UIColor(red: 0.20, green: 0.33, blue: 0.10, alpha: 0.9)
            outline.position = CGPoint(x: GK.worldWidth / 2 + offset.0, y: GK.worldHeight - 76 + offset.1)
            outline.zPosition = 199
            outline.text = "0"
            outline.verticalAlignmentMode = .center
            outline.horizontalAlignmentMode = .center
            outline.name = "scoreOutline"
            hudLayer.addChild(outline)
        }

        // Shadow
        scoreShadow = SKLabelNode(fontNamed: GK.pixelFontName)
        scoreShadow.fontSize = 36
        scoreShadow.fontColor = UIColor(red: 0.15, green: 0.25, blue: 0.08, alpha: 0.8)
        scoreShadow.position = CGPoint(x: GK.worldWidth / 2 + 3, y: GK.worldHeight - 79)
        scoreShadow.zPosition = 200
        scoreShadow.text = "0"
        scoreShadow.verticalAlignmentMode = .center
        scoreShadow.horizontalAlignmentMode = .center
        hudLayer.addChild(scoreShadow)

        // White score
        scoreLabel = SKLabelNode(fontNamed: GK.pixelFontName)
        scoreLabel.fontSize = 36
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight - 76)
        scoreLabel.zPosition = 201
        scoreLabel.text = "0"
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.horizontalAlignmentMode = .center
        hudLayer.addChild(scoreLabel)

        // Bot score (VS Bot mode only)
        if mode == .vsBot {
            setupBotScoreHUD()
        }
    }

    private func setupBotScoreHUD() {
        botScoreShadow = SKLabelNode(fontNamed: GK.pixelFontName)
        botScoreShadow!.fontSize = 14
        botScoreShadow!.fontColor = UIColor(red: 0.42, green: 0.12, blue: 0.12, alpha: 0.7)
        botScoreShadow!.position = CGPoint(x: GK.worldWidth / 2 + 1, y: GK.worldHeight - 108)
        botScoreShadow!.zPosition = 200
        botScoreShadow!.text = "BOT: 0"
        botScoreShadow!.verticalAlignmentMode = .center
        botScoreShadow!.horizontalAlignmentMode = .center
        hudLayer.addChild(botScoreShadow!)

        botScoreLabel = SKLabelNode(fontNamed: GK.pixelFontName)
        botScoreLabel!.fontSize = 14
        botScoreLabel!.fontColor = UIColor(red: 0.95, green: 0.60, blue: 0.60, alpha: 0.9)
        botScoreLabel!.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight - 107)
        botScoreLabel!.zPosition = 201
        botScoreLabel!.text = "BOT: 0"
        botScoreLabel!.verticalAlignmentMode = .center
        botScoreLabel!.horizontalAlignmentMode = .center
        hudLayer.addChild(botScoreLabel!)
    }

    private func updateScore() {
        let text = "\(score)"
        scoreLabel.text = text
        scoreShadow.text = text
        hudLayer.enumerateChildNodes(withName: "scoreOutline") { node, _ in
            (node as? SKLabelNode)?.text = text
        }

        let pop = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.08),
            SKAction.scale(to: 1.0, duration: 0.08)
        ])
        scoreLabel.run(pop)
        scoreShadow.run(pop)
    }

    private func updateBotScoreHUD() {
        let text = "BOT: \(botScore)"
        botScoreLabel?.text = text
        botScoreShadow?.text = text
    }

    // MARK: - Pipes

    private func spawnPipe() {
        guard pipeIndex < gapPositions.count else { return }
        let gapY = gapPositions[pipeIndex]
        let currentPipeIndex = pipeIndex
        pipeIndex += 1

        let pipeNode = SKNode()
        pipeNode.position = CGPoint(x: GK.worldWidth + GK.pipeWidth, y: 0)
        pipeNode.zPosition = 20
        pipeNode.name = "pipe_\(currentPipeIndex)"

        // Bottom pipe
        let bottomH = gapY - GK.pipeGap / 2 - GK.groundHeight
        if bottomH > 0 {
            let bottomBody = SKSpriteNode(
                texture: factory.pipeTexture(height: bottomH),
                size: CGSize(width: GK.pipeWidth, height: bottomH)
            )
            bottomBody.anchorPoint = CGPoint(x: 0.5, y: 0)
            bottomBody.position = CGPoint(x: 0, y: GK.groundHeight)
            pipeNode.addChild(bottomBody)

            let bottomCap = SKSpriteNode(
                texture: factory.pipeCapTexture(),
                size: CGSize(width: GK.pipeWidth + 10, height: 30)
            )
            bottomCap.anchorPoint = CGPoint(x: 0.5, y: 0)
            bottomCap.position = CGPoint(x: 0, y: GK.groundHeight + bottomH - 4)
            pipeNode.addChild(bottomCap)
        }

        // Top pipe
        let topY = gapY + GK.pipeGap / 2
        let topH = GK.worldHeight - topY
        if topH > 0 {
            let topBody = SKSpriteNode(
                texture: factory.pipeTexture(height: topH),
                size: CGSize(width: GK.pipeWidth, height: topH)
            )
            topBody.anchorPoint = CGPoint(x: 0.5, y: 1)
            topBody.position = CGPoint(x: 0, y: GK.worldHeight)
            pipeNode.addChild(topBody)

            let topCap = SKSpriteNode(
                texture: factory.pipeCapTexture(),
                size: CGSize(width: GK.pipeWidth + 10, height: 30)
            )
            topCap.anchorPoint = CGPoint(x: 0.5, y: 1)
            topCap.position = CGPoint(x: 0, y: topY + 4)
            pipeNode.addChild(topCap)
        }

        // Collision bodies
        if bottomH > 0 {
            let bCollider = SKNode()
            bCollider.position = CGPoint(x: 0, y: GK.groundHeight + bottomH / 2)
            bCollider.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.pipeWidth, height: bottomH))
            bCollider.physicsBody?.isDynamic = false
            bCollider.physicsBody?.categoryBitMask = GK.pipeCategory
            bCollider.physicsBody?.contactTestBitMask = GK.duckCategory
            pipeNode.addChild(bCollider)

            let bCapCollider = SKNode()
            bCapCollider.position = CGPoint(x: 0, y: GK.groundHeight + bottomH - 2)
            bCapCollider.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.pipeWidth + 10, height: 30))
            bCapCollider.physicsBody?.isDynamic = false
            bCapCollider.physicsBody?.categoryBitMask = GK.pipeCategory
            bCapCollider.physicsBody?.contactTestBitMask = GK.duckCategory
            pipeNode.addChild(bCapCollider)
        }

        let topH2 = GK.worldHeight - topY
        if topH2 > 0 {
            let tCollider = SKNode()
            tCollider.position = CGPoint(x: 0, y: topY + topH2 / 2)
            tCollider.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.pipeWidth, height: topH2))
            tCollider.physicsBody?.isDynamic = false
            tCollider.physicsBody?.categoryBitMask = GK.pipeCategory
            tCollider.physicsBody?.contactTestBitMask = GK.duckCategory
            pipeNode.addChild(tCollider)

            let tCapCollider = SKNode()
            tCapCollider.position = CGPoint(x: 0, y: topY + 2)
            tCapCollider.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.pipeWidth + 10, height: 30))
            tCapCollider.physicsBody?.isDynamic = false
            tCapCollider.physicsBody?.categoryBitMask = GK.pipeCategory
            tCapCollider.physicsBody?.contactTestBitMask = GK.duckCategory
            pipeNode.addChild(tCapCollider)
        }

        // Score trigger
        let scoreTrigger = SKNode()
        scoreTrigger.position = CGPoint(x: GK.pipeWidth / 2 + 10, y: gapY)
        scoreTrigger.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 2, height: GK.pipeGap))
        scoreTrigger.physicsBody?.isDynamic = false
        scoreTrigger.physicsBody?.categoryBitMask = GK.scoreCategory
        scoreTrigger.physicsBody?.contactTestBitMask = GK.duckCategory
        scoreTrigger.name = "scoreTrigger"
        pipeNode.addChild(scoreTrigger)

        // Movement
        let moveDistance = GK.worldWidth + GK.pipeWidth * 3
        let moveDuration = TimeInterval(moveDistance / GK.pipeSpeed)
        pipeNode.run(SKAction.sequence([
            SKAction.moveBy(x: -moveDistance, y: 0, duration: moveDuration),
            SKAction.removeFromParent()
        ]))

        pipeLayer.addChild(pipeNode)
    }

    // MARK: - Touch / Flap

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch phase {
        case .ready:
            startPlaying()
            flap()
        case .playing:
            flap()
        default:
            break
        }
    }

    func flap() {
        guard phase == .playing else { return }
        duck.physicsBody?.velocity = CGVector(dx: 0, dy: GK.flapImpulse)
        Haptic.flap()

        duck.removeAction(forKey: "wings")
        let flutter = SKAction.sequence([
            SKAction.setTexture(duckTextures[2]),
            SKAction.wait(forDuration: 0.06),
            SKAction.setTexture(duckTextures[0]),
            SKAction.wait(forDuration: 0.06),
            SKAction.setTexture(duckTextures[1]),
        ])
        duck.run(SKAction.sequence([flutter, SKAction.run { [weak self] in
            self?.startWingAnimation()
        }]), withKey: "wings")
    }

    private func startPlaying() {
        phase = .playing
        duck.removeAction(forKey: "float")
        duck.physicsBody?.isDynamic = true

        // Start bot
        if mode == .vsBot {
            botDuck?.removeAction(forKey: "botFloat")
        }

        gameDelegate?.gameDidStart()
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        // Duck nose-dive rotation during death
        if phase == .dead, let vy = duck.physicsBody?.velocity.dy {
            let target = max(vy / 400, -CGFloat.pi / 2)
            duck.zRotation += (target - duck.zRotation) * 0.15
        }

        guard phase == .playing else {
            lastUpdate = currentTime
            return
        }

        let dt = lastUpdate == 0 ? 0 : currentTime - lastUpdate
        lastUpdate = currentTime

        // Spawn pipes
        pipeTimer += dt
        if pipeTimer >= GK.pipeSpawnInterval {
            pipeTimer -= GK.pipeSpawnInterval
            spawnPipe()
        }

        // Scroll ground
        for tile in groundTiles {
            tile.position.x -= GK.groundSpeed * CGFloat(dt)
            if tile.position.x <= -groundTileWidth {
                tile.position.x += groundTileWidth * CGFloat(groundTiles.count)
            }
        }

        // Parallax clouds
        for cloud in clouds {
            cloud.position.x -= GK.cloudSpeed * CGFloat(dt)
            if cloud.position.x < -80 {
                cloud.position.x = GK.worldWidth + 80
                cloud.position.y = CGFloat.random(in: (GK.worldHeight * 0.55)...(GK.worldHeight - 40))
            }
        }

        // Parallax hills (slowest)
        for hill in hills {
            hill.position.x -= GK.hillSpeed * CGFloat(dt)
            if hill.position.x < -(GK.worldWidth * 2) {
                hill.position.x += GK.worldWidth * 4
            }
        }

        // Parallax trees (medium)
        for tree in trees {
            tree.position.x -= GK.treeSpeed * CGFloat(dt)
            if tree.position.x < -(GK.worldWidth * 2) {
                tree.position.x += GK.worldWidth * 4
            }
        }

        // Duck rotation
        if let vy = duck.physicsBody?.velocity.dy {
            let target = vy > 0
                ? min(vy / GK.flapImpulse * 0.4, 0.4)
                : max(vy / 400, -CGFloat.pi / 2)
            duck.zRotation += (target - duck.zRotation) * 0.15
        }

        // Bot AI update
        if mode == .vsBot {
            updateBot(dt: dt)
        }
    }

    // MARK: - Bot AI

    private func updateBot(dt: TimeInterval) {
        guard botAlive, let bot = botDuck else { return }

        // Apply gravity
        botVelocity += GK.gravity / 60 * CGFloat(dt) * 60  // convert per-frame to per-second
        botY += botVelocity * CGFloat(dt)

        // Ground collision
        let botR = GK.duckRadius * 0.85
        if botY <= GK.groundHeight + botR {
            botY = GK.groundHeight + botR
            botDied()
            return
        }

        // Ceiling clamp
        if botY >= GK.worldHeight - botR {
            botY = GK.worldHeight - botR
            botVelocity = 0
        }

        // Find nearest pipe ahead of bot
        var targetGapY: CGFloat = GK.duckStartY
        var nearestDist: CGFloat = CGFloat.greatestFiniteMagnitude

        for child in pipeLayer.children {
            let pipeX = child.position.x
            let dist = pipeX - GK.duckStartX
            // Only consider pipes ahead (or currently at) the bot
            if dist > -(GK.pipeWidth / 2) && dist < nearestDist {
                if let trigger = child.childNode(withName: "scoreTrigger") {
                    targetGapY = trigger.position.y
                    nearestDist = dist
                }
            }
        }

        // Bot AI: aim for gap center with slight noise
        let noise = CGFloat.random(in: -12...12)
        let adjustedTarget = targetGapY + noise

        // Flap when below target
        if botY < adjustedTarget - 8 && botVelocity < GK.flapImpulse * 0.5 {
            botVelocity = GK.flapImpulse * 0.88  // slightly weaker flap
        }

        // Check pipe collision
        for child in pipeLayer.children {
            let pipeX = child.position.x
            if abs(pipeX - GK.duckStartX) < GK.pipeWidth / 2 + botR * 0.6 {
                if let trigger = child.childNode(withName: "scoreTrigger") {
                    let gapY = trigger.position.y
                    let gapTop = gapY + GK.pipeGap / 2 - 5
                    let gapBottom = gapY - GK.pipeGap / 2 + 5
                    if botY + botR > gapTop || botY - botR < gapBottom {
                        botDied()
                        return
                    }
                }
            }

            // Bot scoring: did it pass this pipe?
            if let pipeName = child.name, pipeX < GK.duckStartX - GK.pipeWidth / 2 {
                if !botPipesPassed.contains(pipeName) {
                    botPipesPassed.insert(pipeName)
                    botScore += 1
                    updateBotScoreHUD()
                    gameDelegate?.botDidScore(botScore)
                }
            }
        }

        // Update visual position
        bot.position.y = botY

        // Bot rotation
        let target = botVelocity > 0
            ? min(botVelocity / GK.flapImpulse * 0.4, 0.4)
            : max(botVelocity / 400, -CGFloat.pi / 2)
        bot.zRotation += (target - bot.zRotation) * 0.15
    }

    private func botDied() {
        botAlive = false
        guard let bot = botDuck else { return }
        bot.removeAction(forKey: "botWings")
        bot.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 30, duration: 0.3),
                SKAction.rotate(byAngle: -CGFloat.pi / 2, duration: 0.3),
            ]),
            SKAction.group([
                SKAction.moveTo(y: GK.groundHeight, duration: 0.5),
                SKAction.rotate(byAngle: -CGFloat.pi, duration: 0.5),
            ]),
            SKAction.fadeOut(withDuration: 0.3),
        ]))
    }

    // MARK: - Collision

    func didBegin(_ contact: SKPhysicsContact) {
        let bodies = [contact.bodyA, contact.bodyB]
        let masks = bodies.map { $0.categoryBitMask }

        // Score
        if masks.contains(GK.scoreCategory) && masks.contains(GK.duckCategory) {
            bodies.first { $0.categoryBitMask == GK.scoreCategory }?.node?.removeFromParent()
            score += 1
            updateScore()
            Haptic.score()
            gameDelegate?.gameDidScore(score)
            return
        }

        // Death
        if phase == .playing {
            die()
        }
    }

    private func die() {
        phase = .dead
        Haptic.death()

        pipeLayer.isPaused = true
        groundLayer.isPaused = true

        // White flash
        let flash = SKSpriteNode(color: .white, size: self.size)
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = 500
        flash.alpha = 0.8
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))

        // Camera shake
        worldNode.run(SKAction.sequence([
            SKAction.moveBy(x: 5, y: 3, duration: 0.03),
            SKAction.moveBy(x: -10, y: -6, duration: 0.03),
            SKAction.moveBy(x: 8, y: 4, duration: 0.03),
            SKAction.moveBy(x: -3, y: -1, duration: 0.03),
            SKAction.move(to: .zero, duration: 0.03),
        ]))

        // Duck falls — stop wings, tumble nose-down
        duck.removeAction(forKey: "wings")
        duck.texture = duckTextures[0]  // wings tucked
        duck.physicsBody?.collisionBitMask = GK.groundCategory
        duck.physicsBody?.velocity = CGVector(dx: 0, dy: 200)

        // Fade duck after landing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.duck.run(SKAction.fadeAlpha(to: 0.3, duration: 0.3))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }
            self.phase = .gameOver
            self.gameDelegate?.gameDidEnd(score: self.score)
        }
    }

    // MARK: - Reset

    func resetGame() {
        pipeLayer.removeAllChildren()
        pipeLayer.isPaused = false
        groundLayer.isPaused = false

        pipeIndex = 0
        pipeTimer = 0
        lastUpdate = 0
        score = 0
        botScore = 0
        botPipesPassed.removeAll()
        phase = .ready

        let newSeed = Int.random(in: 1...999999)
        prng = SeededRandom(seed: newSeed)
        gapPositions = prng.generateGapPositions()

        duck.position = CGPoint(x: GK.duckStartX, y: GK.duckStartY)
        duck.zRotation = 0
        duck.alpha = 1.0
        duck.physicsBody?.isDynamic = false
        duck.physicsBody?.velocity = .zero
        duck.physicsBody?.collisionBitMask = GK.groundCategory | GK.pipeCategory

        let float = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 10, duration: 0.5),
            SKAction.moveBy(x: 0, y: -10, duration: 0.5)
        ])
        duck.run(SKAction.repeatForever(float), withKey: "float")
        startWingAnimation()
        updateScore()

        // Reset bot
        if mode == .vsBot {
            botDuck?.removeFromParent()
            setupBotDuck()
            updateBotScoreHUD()
        }
    }
}
