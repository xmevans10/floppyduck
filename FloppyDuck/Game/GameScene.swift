import SpriteKit

// MARK: - Game Phase

enum GamePhase {
    case ready      // waiting for first tap
    case countdown  // 3-2-1 before multiplayer
    case playing    // game active
    case dead       // hit pipe/ground, falling
    case gameOver   // final state
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
    
    // Layers
    private let worldNode = SKNode()
    private let backgroundLayer = SKNode()
    private let pipeLayer = SKNode()
    private let groundLayer = SKNode()
    private let hudLayer = SKNode()
    
    // Duck
    private var duck: SKSpriteNode!
    private var duckTextures: [SKTexture] = []
    private var wingTimer: Timer?
    
    // Score
    private var scoreLabel: SKLabelNode!
    private var scoreShadow: SKLabelNode!
    
    // Ground scrolling
    private var groundTiles: [SKSpriteNode] = []
    private let groundTileWidth: CGFloat = 800
    
    // Pipe spawning
    private var pipeTimer: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0
    
    // Cloud / Building parallax
    private var clouds: [SKSpriteNode] = []
    private var buildings: [SKSpriteNode] = []
    
    // Scale to fill screen
    private var scaleFactor: CGFloat = 1
    
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
        backgroundColor = .clear
        physicsWorld.gravity = CGVector(dx: 0, dy: GK.gravity / 60) // SpriteKit applies per-frame
        physicsWorld.contactDelegate = self
        
        addChild(worldNode)
        worldNode.addChild(backgroundLayer)
        worldNode.addChild(pipeLayer)
        worldNode.addChild(groundLayer)
        addChild(hudLayer)
        
        setupBackground()
        setupGround()
        setupDuck()
        setupHUD()
        setupClouds()
        setupBuildings()
        
        // Duck floats gently before first tap
        let float = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 10, duration: 0.5),
            SKAction.moveBy(x: 0, y: -10, duration: 0.5)
        ])
        duck.run(SKAction.repeatForever(float), withKey: "float")
        
        // Pause physics until tap
        duck.physicsBody?.isDynamic = false
    }
    
    // MARK: - Background
    
    private func setupBackground() {
        let skyNode = SKSpriteNode(
            texture: TextureFactory.skyTexture(size: CGSize(width: GK.worldWidth, height: GK.worldHeight)),
            size: CGSize(width: GK.worldWidth + 40, height: GK.worldHeight + 40)
        )
        skyNode.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight / 2)
        skyNode.zPosition = -100
        backgroundLayer.addChild(skyNode)
    }
    
    private func setupClouds() {
        let cloudCount = 5
        for _ in 0..<cloudCount {
            let w = CGFloat.random(in: 60...120)
            let h = w * 0.5
            let cloud = SKSpriteNode(texture: TextureFactory.cloudTexture(width: w, height: h), size: CGSize(width: w, height: h))
            cloud.position = CGPoint(
                x: CGFloat.random(in: 0...GK.worldWidth),
                y: CGFloat.random(in: (GK.worldHeight * 0.5)...(GK.worldHeight - 40))
            )
            cloud.alpha = CGFloat.random(in: 0.4...0.7)
            cloud.zPosition = -90
            backgroundLayer.addChild(cloud)
            clouds.append(cloud)
        }
    }
    
    private func setupBuildings() {
        let buildingData: [(x: CGFloat, w: CGFloat, h: CGFloat)] = [
            (0, 35, 80), (38, 25, 55), (65, 40, 95), (110, 30, 65),
            (145, 50, 110), (200, 28, 72), (232, 45, 88), (282, 35, 60),
            (322, 42, 100), (368, 30, 75), (400, 38, 90)
        ]
        for data in buildingData {
            let shade = CGFloat.random(in: 0.55...0.75)
            let tex = TextureFactory.buildingTexture(width: data.w, height: data.h, shade: shade)
            let building = SKSpriteNode(texture: tex, size: CGSize(width: data.w, height: data.h))
            building.anchorPoint = CGPoint(x: 0, y: 0)
            building.position = CGPoint(x: data.x, y: GK.groundHeight - 10)
            building.zPosition = -50
            backgroundLayer.addChild(building)
            buildings.append(building)
        }
    }
    
    // MARK: - Ground
    
    private func setupGround() {
        let tilesNeeded = Int(ceil(GK.worldWidth / groundTileWidth)) + 2
        for i in 0..<tilesNeeded {
            let tex = TextureFactory.groundTexture(width: groundTileWidth)
            let tile = SKSpriteNode(texture: tex, size: CGSize(width: groundTileWidth, height: GK.groundHeight))
            tile.anchorPoint = CGPoint(x: 0, y: 0)
            tile.position = CGPoint(x: CGFloat(i) * groundTileWidth, y: 0)
            tile.zPosition = 50
            groundLayer.addChild(tile)
            groundTiles.append(tile)
        }
        
        // Ground physics — thin edge at top
        let groundBody = SKNode()
        groundBody.position = CGPoint(x: GK.worldWidth / 2, y: GK.groundHeight)
        groundBody.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.worldWidth * 2, height: 2))
        groundBody.physicsBody?.isDynamic = false
        groundBody.physicsBody?.categoryBitMask = GK.groundCategory
        groundBody.physicsBody?.contactTestBitMask = GK.duckCategory
        worldNode.addChild(groundBody)
        
        // Ceiling (invisible)
        let ceiling = SKNode()
        ceiling.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight + 20)
        ceiling.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.worldWidth * 2, height: 2))
        ceiling.physicsBody?.isDynamic = false
        worldNode.addChild(ceiling)
    }
    
    // MARK: - Duck
    
    private func setupDuck() {
        // Pre-render 3 wing frames
        duckTextures = (0...2).map { TextureFactory.duckTexture(wingPhase: $0) }
        
        duck = SKSpriteNode(texture: duckTextures[0],
                            size: CGSize(width: GK.duckRadius * 2.8, height: GK.duckRadius * 2.4))
        duck.position = CGPoint(x: GK.duckX, y: GK.duckStartY)
        duck.zPosition = 40
        
        // Physics
        duck.physicsBody = SKPhysicsBody(circleOfRadius: GK.duckRadius * 0.85)
        duck.physicsBody?.categoryBitMask = GK.duckCategory
        duck.physicsBody?.contactTestBitMask = GK.pipeCategory | GK.groundCategory
        duck.physicsBody?.collisionBitMask = GK.groundCategory
        duck.physicsBody?.allowsRotation = false
        duck.physicsBody?.restitution = 0
        duck.physicsBody?.linearDamping = 0
        
        worldNode.addChild(duck)
        
        // Wing animation timer
        startWingAnimation()
    }
    
    private func startWingAnimation() {
        let wingAction = SKAction.animate(with: duckTextures, timePerFrame: 0.12)
        duck.run(SKAction.repeatForever(wingAction), withKey: "wings")
    }
    
    // MARK: - HUD
    
    private func setupHUD() {
        // Score shadow
        scoreShadow = SKLabelNode(fontNamed: "Futura-Bold")
        scoreShadow.fontSize = 56
        scoreShadow.fontColor = UIColor(white: 0, alpha: 0.5)
        scoreShadow.position = CGPoint(x: GK.worldWidth / 2 + 2, y: GK.worldHeight - 80 - 2)
        scoreShadow.zPosition = 200
        scoreShadow.text = "0"
        hudLayer.addChild(scoreShadow)
        
        // Score label
        scoreLabel = SKLabelNode(fontNamed: "Futura-Bold")
        scoreLabel.fontSize = 56
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: GK.worldWidth / 2, y: GK.worldHeight - 80)
        scoreLabel.zPosition = 201
        scoreLabel.text = "0"
        hudLayer.addChild(scoreLabel)
    }
    
    private func updateScore() {
        scoreLabel.text = "\(score)"
        scoreShadow.text = "\(score)"
        
        // Pop animation
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
                texture: TextureFactory.pipeBodyTexture(height: bottomH),
                size: CGSize(width: GK.pipeWidth, height: bottomH)
            )
            bottomBody.anchorPoint = CGPoint(x: 0.5, y: 0)
            bottomBody.position = CGPoint(x: 0, y: GK.groundHeight)
            pipeNode.addChild(bottomBody)
            
            // Bottom cap
            let bottomCap = SKSpriteNode(
                texture: TextureFactory.pipeCapTexture(),
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
                texture: TextureFactory.pipeBodyTexture(height: topH),
                size: CGSize(width: GK.pipeWidth, height: topH)
            )
            topBody.anchorPoint = CGPoint(x: 0.5, y: 0)
            topBody.position = CGPoint(x: 0, y: topY)
            topBody.yScale = -1 // flip top pipe
            pipeNode.addChild(topBody)
            
            // Top cap
            let topCap = SKSpriteNode(
                texture: TextureFactory.pipeCapTexture(),
                size: CGSize(width: GK.pipeWidth + 10, height: 30)
            )
            topCap.anchorPoint = CGPoint(x: 0.5, y: 1)
            topCap.position = CGPoint(x: 0, y: topY + 4)
            pipeNode.addChild(topCap)
        }
        
        // Collision body for entire pipe pair
        // Bottom collision
        if bottomH > 0 {
            let bCollider = SKNode()
            bCollider.position = CGPoint(x: 0, y: GK.groundHeight + bottomH / 2)
            bCollider.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: GK.pipeWidth - 4, height: bottomH))
            bCollider.physicsBody?.isDynamic = false
            bCollider.physicsBody?.categoryBitMask = GK.pipeCategory
            bCollider.physicsBody?.contactTestBitMask = GK.duckCategory
            pipeNode.addChild(bCollider)
        }
        
        // Top collision
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
        
        // Score trigger (invisible line in the gap)
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
        let moveAction = SKAction.moveBy(x: -moveDistance, y: 0, duration: moveDuration)
        let removeAction = SKAction.removeFromParent()
        pipeNode.run(SKAction.sequence([moveAction, removeAction]))
        
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
        case .gameOver:
            break // handled by SwiftUI overlay
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
            SKAction.setTexture(duckTextures[1]),
            SKAction.wait(forDuration: 0.06),
            SKAction.setTexture(duckTextures[2]),
            SKAction.wait(forDuration: 0.06),
            SKAction.setTexture(duckTextures[0]),
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
            if building.position.x < -(building.size.width + 10) {
                building.position.x = GK.worldWidth + 10
            }
        }
        
        // Duck rotation based on velocity
        if let vy = duck.physicsBody?.velocity.dy {
            let target = vy > 0
                ? min(vy / GK.flapImpulse * 0.4, 0.4)
                : max(vy / 400, -CGFloat.pi / 2)
            let current = duck.zRotation
            duck.zRotation = current + (target - current) * 0.15
        }
    }
    
    // MARK: - Collision
    
    func didBegin(_ contact: SKPhysicsContact) {
        let bodies = [contact.bodyA, contact.bodyB]
        let masks = bodies.map { $0.categoryBitMask }
        
        // Score trigger
        if masks.contains(GK.scoreCategory) && masks.contains(GK.duckCategory) {
            // Remove the trigger so it doesn't fire again
            let scorebody = bodies.first { $0.categoryBitMask == GK.scoreCategory }
            scorebody?.node?.removeFromParent()
            
            score += 1
            updateScore()
            Haptic.score()
            gameDelegate?.gameDidScore(score)
            return
        }
        
        // Death — pipe or ground
        if phase == .playing {
            die()
        }
    }
    
    private func die() {
        phase = .dead
        Haptic.death()
        
        // Stop pipe movement
        pipeLayer.isPaused = true
        
        // Stop ground scrolling
        groundLayer.isPaused = true
        
        // Flash effect
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
        let shake = SKAction.sequence([
            SKAction.moveBy(x: 5, y: 3, duration: 0.03),
            SKAction.moveBy(x: -10, y: -6, duration: 0.03),
            SKAction.moveBy(x: 8, y: 4, duration: 0.03),
            SKAction.moveBy(x: -3, y: -1, duration: 0.03),
            SKAction.moveTo(x: 0, duration: 0.03),
            SKAction.moveTo(y: 0, duration: 0.03),
        ])
        worldNode.run(shake)
        
        // Let duck fall
        duck.removeAction(forKey: "wings")
        duck.physicsBody?.collisionBitMask = GK.groundCategory
        duck.physicsBody?.velocity = CGVector(dx: 0, dy: 200)
        
        // Transition to game over after a beat
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            self.phase = .gameOver
            self.gameDelegate?.gameDidEnd(score: self.score)
        }
    }
    
    // MARK: - Reset
    
    func resetGame() {
        // Remove pipes
        pipeLayer.removeAllChildren()
        pipeLayer.isPaused = false
        groundLayer.isPaused = false
        
        // Reset state
        pipeIndex = 0
        pipeTimer = 0
        lastUpdate = 0
        score = 0
        phase = .ready
        
        // Re-seed
        let newSeed = Int.random(in: 1...999999)
        prng = SeededRandom(seed: newSeed)
        gapPositions = prng.generateGapPositions()
        
        // Reset duck
        duck.position = CGPoint(x: GK.duckX, y: GK.duckStartY)
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
        
        // Reset HUD
        updateScore()
    }
}
