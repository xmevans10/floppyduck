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
}

// MARK: - GameScene

final class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Properties

    weak var gameDelegate: GameSceneDelegate?

    private(set) var phase: GamePhase = .ready
    private(set) var score: Int = 0

    private var prng: SeededRandom
    private var gapPositions: [CGFloat] = []
    private var pipeIndex: Int = 0

    private let factory = TextureFactory.shared

    // Layers
    private let worldNode = SKNode()
    private let backgroundLayer = SKNode()
    private let pipeLayer = SKNode()
    private let groundLayer = SKNode()
    private let hudLayer = SKNode()

    // Duck
    private var duck: SKSpriteNode!
    private var duckTextures: [SKTexture] = []

    // Score
    private var scoreLabel: SKLabelNode!
    private var scoreShadow: SKLabelNode!

    // Ground scrolling
    private var groundTiles: [SKSpriteNode] = []
    private let groundTileWidth: CGFloat = GK.worldWidth * 2

    // Pipe spawning
    private var pipeTimer: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0

    // Parallax
    private var clouds: [SKSpriteNode] = []
    private var buildings: [SKSpriteNode] = []

    // MARK: - Init

    init(seed: Int = Int.random(in: 1...999999)) {
        self.prng = SeededRandom(seed: seed)
        super.init(size: CGSize(width: GK.worldWidth, height: GK.worldHeight))
        self.scaleMode = .aspectFill
        self.gapPositions = prng.generateGapPositions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.31, green: 0.75, blue: 0.79, alpha: 1)
        physicsWorld.gravity = CGVector(dx: 0, dy: GK.gravity / 60)
        physicsWorld.contactDelegate = self

        addChild(worldNode)
        worldNode.addChild(backgroundLayer)
        worldNode.addChild(pipeLayer)
        worldNode.addChild(groundLayer)
        addChild(hudLayer)

        setupBackground()
        setupClouds()
        setupBuildings()
        setupGround()
        setupDuck()
        setupHUD()

        // Duck floats gently before first tap
        let float = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 10, duration: 0.5),
            SKAction.moveBy(x: 0, y: -10, duration: 0.5)
        ])
        duck.run(SKAction.repeatForever(float), withKey: "float")
        duck.physicsBody?.isDynamic = false
    }

    // MARK: - Background (bright cyan sky)

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
                                      size: CGSize(width: 80 * scale, height: 30 * scale))
            cloud.position = CGPoint(
                x: CGFloat.random(in: 0...GK.worldWidth),
                y: CGFloat.random(in: (GK.worldHeight * 0.5)...(GK.worldHeight - 40))
            )
            cloud.alpha = CGFloat.random(in: 0.5...0.8)
            cloud.zPosition = -90
            backgroundLayer.addChild(cloud)
            clouds.append(cloud)
        }
    }

    private func setupBuildings() {
        let buildingTex = factory.buildingTexture()
        let buildingNode = SKSpriteNode(texture: buildingTex,
                                         size: CGSize(width: GK.worldWidth * 2, height: 140))
        buildingNode.anchorPoint = CGPoint(x: 0, y: 0)
        buildingNode.position = CGPoint(x: 0, y: GK.groundHeight - 10)
        buildingNode.zPosition = -50
        buildingNode.alpha = 0.6
        backgroundLayer.addChild(buildingNode)
        buildings.append(buildingNode)

        // Duplicate for seamless scroll
        let buildingNode2 = SKSpriteNode(texture: buildingTex,
                                          size: CGSize(width: GK.worldWidth * 2, height: 140))
        buildingNode2.anchorPoint = CGPoint(x: 0, y: 0)
        buildingNode2.position = CGPoint(x: GK.worldWidth * 2, y: GK.groundHeight - 10)
        buildingNode2.zPosition = -50
        buildingNode2.alpha = 0.6
        backgroundLayer.addChild(buildingNode2)
        buildings.append(buildingNode2)
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

        duck = SKSpriteNode(texture: duckTextures[1],
                            size: CGSize(width: GK.duckRadius * 2.8, height: GK.duckRadius * 2.4))
        duck.position = CGPoint(x: GK.duckStartX, y: GK.duckStartY)
        duck.zPosition = 40

        duck.physicsBody = SKPhysicsBody(circleOfRadius: GK.duckRadius * 0.85)
        duck.physicsBody?.categoryBitMask = GK.duckCategory
        duck.physicsBody?.contactTestBitMask = GK.pipeCategory | GK.groundCategory
        duck.physicsBody?.collisionBitMask = GK.groundCategory
        duck.physicsBody?.allowsRotation = false
        duck.physicsBody?.restitution = 0
        duck.physicsBody?.linearDamping = 0

        worldNode.addChild(duck)
        startWingAnimation()
    }

    private func startWingAnimation() {
        let wingAction = SKAction.animate(with: duckTextures, timePerFrame: 0.12)
        duck.run(SKAction.repeatForever(wingAction), withKey: "wings")
    }

    // MARK: - HUD (score with dark outline like Flappy Bird)

    private func setupHUD() {
        // Dark outline behind score
        scoreShadow = SKLabelNode(fontNamed: "Futura-Bold")
        scoreShadow.fontSize = 52
        scoreShadow.fontColor = UIColor(red: 0.20, green: 0.33, blue: 0.10, alpha: 0.7)
        scoreShadow.position = CGPoint(x: GK.worldWidth / 2 + 2, y: GK.worldHeight - 78)
        scoreShadow.zPosition = 200
        scoreShadow.text = "0"
        scoreShadow.verticalAlignmentMode = .center
        scoreShadow.horizontalAlignmentMode = .center
        hudLayer.addChild(scoreShadow)

        // White score number
        scoreLabel = SKLabelNode(fontNamed: "Futura-Bold")
        scoreLabel.fontSize = 52
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight - 76)
        scoreLabel.zPosition = 201
        scoreLabel.text = "0"
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.horizontalAlignmentMode = .center
        hudLayer.addChild(scoreLabel)
    }

    private func updateScore() {
        scoreLabel.text = "\(score)"
        scoreShadow.text = "\(score)"

        let pop = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.08),
            SKAction.scale(to: 1.0, duration: 0.08)
        ])
        scoreLabel.run(pop)
        scoreShadow.run(pop)
    }

    // MARK: - Pipes

    private func spawnPipe() {
        guard pipeIndex < gapPositions.count else { return }
        let gapY = gapPositions[pipeIndex]
        pipeIndex += 1

        let pipeNode = SKNode()
        pipeNode.position = CGPoint(x: GK.worldWidth + GK.pipeWidth, y: 0)
        pipeNode.zPosition = 20

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
            bCollider.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.pipeWidth - 4, height: bottomH))
            bCollider.physicsBody?.isDynamic = false
            bCollider.physicsBody?.categoryBitMask = GK.pipeCategory
            bCollider.physicsBody?.contactTestBitMask = GK.duckCategory
            pipeNode.addChild(bCollider)
        }

        let topH2 = GK.worldHeight - topY
        if topH2 > 0 {
            let tCollider = SKNode()
            tCollider.position = CGPoint(x: 0, y: topY + topH2 / 2)
            tCollider.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.pipeWidth - 4, height: topH2))
            tCollider.physicsBody?.isDynamic = false
            tCollider.physicsBody?.categoryBitMask = GK.pipeCategory
            tCollider.physicsBody?.contactTestBitMask = GK.duckCategory
            pipeNode.addChild(tCollider)
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

        // Quick wing flutter
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
        gameDelegate?.gameDidStart()
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
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
                cloud.position.y = CGFloat.random(in: (GK.worldHeight * 0.5)...(GK.worldHeight - 40))
            }
        }

        // Parallax buildings
        for building in buildings {
            building.position.x -= GK.buildingSpeed * CGFloat(dt)
            if building.position.x < -(GK.worldWidth * 2) {
                building.position.x += GK.worldWidth * 4
            }
        }

        // Duck rotation based on velocity
        if let vy = duck.physicsBody?.velocity.dy {
            let target = vy > 0
                ? min(vy / GK.flapImpulse * 0.4, 0.4)
                : max(vy / 400, -CGFloat.pi / 2)
            duck.zRotation += (target - duck.zRotation) * 0.15
        }
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

        // Duck falls
        duck.removeAction(forKey: "wings")
        duck.physicsBody?.collisionBitMask = GK.groundCategory
        duck.physicsBody?.velocity = CGVector(dx: 0, dy: 200)

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
        phase = .ready

        let newSeed = Int.random(in: 1...999999)
        prng = SeededRandom(seed: newSeed)
        gapPositions = prng.generateGapPositions()

        duck.position = CGPoint(x: GK.duckStartX, y: GK.duckStartY)
        duck.zRotation = 0
        duck.physicsBody?.isDynamic = false
        duck.physicsBody?.velocity = .zero
        duck.physicsBody?.collisionBitMask = GK.groundCategory

        let float = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 10, duration: 0.5),
            SKAction.moveBy(x: 0, y: -10, duration: 0.5)
        ])
        duck.run(SKAction.repeatForever(float), withKey: "float")
        startWingAnimation()
        updateScore()
    }
}
