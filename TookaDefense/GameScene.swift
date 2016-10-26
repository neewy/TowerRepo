import SpriteKit
import GameplayKit

class GameScene: GameSceneInit {
	
	
	let gridHeightModifier = 0.5
	let gridWidthModifier = 0.5
	
	var grid = SKNode()
	var optionGrid = SKNode()
	var hudGrid = SKNode()
	var layout = [[GKEntity]]()
	var offsetX: Double!
	var offsetY: Double!
	
	//Camera
	let cameraNode = SKCameraNode()
	
	var waveManager: WaveManager!
	
	lazy var stateMachine: GKStateMachine = GKStateMachine(states:
		[
			GameSceneReadyState(scene: self),
			GameSceneLevelSelector(scene: self),
			GameSceneActiveState(scene: self),
			GameSceneWinState(scene: self),
			GameSceneLoseState(scene: self)
		])
	
	var lastUpdateTimeInterval: TimeInterval = 0
	
	var entities = Set<GKEntity>()
	
	var towerSelectorNodes = [TowerSelectorNode]()
	var placingTower = false
	var placingTowerOnNode = SKNode()
	
	var selectorPosition: int2 = int2(0,0)
	
	lazy var componentSystems: [GKComponentSystem] = {
		let animationSystem = GKComponentSystem(
			componentClass: AnimationComponent.self)
		let firingSystem = GKComponentSystem(componentClass: FiringComponent.self)
		return [animationSystem, firingSystem]
	}()
	
	override func didMove(to view: SKView) {
		super.didMove(to: view)

		// No physics 
		physicsWorld.gravity = CGVector(dx: 0, dy: 0)

		// Camera Settings
		cameraNode.zPosition = CGFloat(UInt32.max)
		addChild(cameraNode)
		camera = cameraNode
		cameraNode.position.x = size.width / 2
		cameraNode.position.y = size.height / 2
		
		// Add background
		let background = SKSpriteNode(color: UIColor(red: 0.20, green: 0.29, blue: 0.37, alpha: 1.0), size: CGSize(width: self.size.width*5, height: self.size.height*5))
		background.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
		addChild(background)
		
		stateMachine.enter(GameSceneReadyState.self)
		
		let waves = [
			Wave(enemyCount: 5, enemyDelay: 1.5, enemyType: .Enemy1),
			Wave(enemyCount: 5, enemyDelay: 1.5, enemyType: .Enemy2),
		]
		waveManager = WaveManager(waves: waves,
			newWaveHandler: { (waveNum) -> Void in self.run(SKAction.playSoundFileNamed("NewWave.mp3", waitForCompletion: false))},
			newEnemyHandler: { (enemyType) -> Void in self.addEnemy(enemyType, gridposition: int2(0,15), endGridPosition: int2(19,15))}
		)
		waveLabel.text = "\(waveManager.currentWave)/\(waveManager.waves.count)"
	}
	
	override func update(_ currentTime: TimeInterval) {
		super.update(currentTime)
		if isPaused { return }
		
		guard view != nil else { return }
		
		let deltaTime = currentTime - lastUpdateTimeInterval
		lastUpdateTimeInterval = currentTime
		
		stateMachine.update(deltaTime: deltaTime)
		
		for componentSystem in componentSystems {
			componentSystem.update(deltaTime: deltaTime)
		}
	}
	
	override func didFinishUpdate() {
		let enemies: [EnemyEntity] = entities.flatMap { entity in
			if let enemy = entity as? EnemyEntity {
				return enemy
			}
			return nil
		}
		let towers: [TowerEntity] = entities.flatMap { entity in
			if let tower = entity as? TowerEntity {
				return tower
			}
			return nil
		}
		let slower: [ObstacleEntity] = entities.flatMap { entity in
			if let slower = entity as? ObstacleEntity {
				return slower
			}
			return nil
		}
		
		for tower in towers {
			let towerType = tower.towerType
			var target: EnemyEntity?
			for enemy in enemies.filter({
				(enemy: EnemyEntity) -> Bool in
				distanceBetween(tower.spriteComponent.node, nodeB: enemy.spriteComponent.node) < towerType.range}) {
					
					if let t = target {
						if enemy.spriteComponent.node.position.x >
							t.spriteComponent.node.position.x {
								target = enemy
						}
					} else {
						target = enemy
					}
			}
			tower.firingComponent.currentTarget = target
		}
		
		for enemy in enemies {
			for slow in slower {
				let test: Bool = (coordinateOfPoint(slow.spriteComponent.node.position)!.x == coordinateOfPoint(enemy.spriteComponent.node.position)!.x) && (coordinateOfPoint(slow.spriteComponent.node.position)!.y == coordinateOfPoint(enemy.spriteComponent.node.position)!.y)
				if slow.obstacleType == .Slow && !enemy.slowed {
					if test {
						boosterParticule(slow.spriteComponent.node.position, explosionType: "ABDA")
						enemy.enemySlowed(0.7)
					}
				} else if slow.obstacleType == .Boost && !enemy.boosted {
					if test {
						boosterParticule(slow.spriteComponent.node.position, explosionType: "ABDA")
						enemy.enemyBoosted(1.3)
					}
				} else if slow.obstacleType == .Teleport && !enemy.teleported{
					if test {
						var position = teleport[1].spriteComponent.node.position
						if position == slow.spriteComponent.node.position {
							position = teleport[0].spriteComponent.node.position
						}
						teleportParticule(teleport[1].spriteComponent.node.position, explosionType: "ABDA")
						teleportParticule(teleport[0].spriteComponent.node.position, explosionType: "ABDA")
						enemy.enemyTeleported(position)
						setEnemyOnPath(enemy, toPoint: enemy.endPoint)
						updateVisualPath()
					}
				} else if slow.obstacleType == .Diamond && diamond == 0{
					if test {
						diamond += 1
						diamondLabel.text = "\(diamond)"
						slow.spriteComponent.node.zPosition = 2
						slow.spriteComponent.node.run(SKAction.move(to: diamondLabelImage.position, duration: 1.0))
					}
				}
			}
			if enemy.healthComponent.health <= 0 {
				for _ in 0..<5 {
					explosion(enemy.spriteComponent.node.position, explosionType: "Enemy")
				}
				gold += enemy.enemyType.goldReward
				updateHUD()
				enemyKilled += 1
				if waveManager.removeEnemyFromWave() == true {
					if levelToLoad <= levels.count {
						stateMachine.enter(GameSceneWinState.self)
					}
				}
				waveLabel.text = "\(waveManager.currentWave)/\(waveManager.waves.count)"
				remove(enemy)
			}
			else if enemy.spriteComponent.node.position.x >= enemy.endPoint.x - 1 {
				baseLives -= enemy.enemyType.baseDamage
				updateHUD()
				
				if baseLives <= 0 {
					stateMachine.enter(GameSceneLoseState.self)
				}
				remove(enemy)
			}
		}
	}
	
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		for touch in (touches ) {
			let touchLocation = touch.location(in: self)
			let touchedNode = self.atPoint(touchLocation)
			
			switch stateMachine.currentState {
			case is GameSceneReadyState:
				if touchedNode.name == "playButton" {
					stateMachine.enter(GameSceneLevelSelector.self)
					return
				}
			case is GameSceneLevelSelector:
				switch touchedNode.name! {
				case "homeButton":
					let newScene = GameScene(fileNamed:"GameScene")
					newScene!.scaleMode = .aspectFill
					let reveal = SKTransition.doorsCloseHorizontal(withDuration: 0.5)
					self.view?.presentScene(newScene!, transition: reveal)
					break
				case "box1":
					levelToLoad = 1
					stateMachine.enter(GameSceneActiveState.self)
					break
				case "box2":
					levelToLoad = 2
					stateMachine.enter(GameSceneActiveState.self)
					break
				case "box3":
					levelToLoad = 3
					stateMachine.enter(GameSceneActiveState.self)
					break
				case "box4":
					levelToLoad = 4
					stateMachine.enter(GameSceneActiveState.self)
					break
				case "box5":
					levelToLoad = 5
					stateMachine.enter(GameSceneActiveState.self)
					break
				case "box6":
					levelToLoad = 6
					stateMachine.enter(GameSceneActiveState.self)
					break
				case "box7":
					levelToLoad = 7
					stateMachine.enter(GameSceneActiveState.self)
					break
				case "box8":
					levelToLoad = 8
					stateMachine.enter(GameSceneActiveState.self)
					break
				case "box9":
					levelToLoad = 9
					stateMachine.enter(GameSceneActiveState.self)
					break
				case "box10":
					levelToLoad = 10
					stateMachine.enter(GameSceneActiveState.self)
					break
				default:
					break
				}
			case is GameSceneActiveState:
				let position = coordinateOfPoint(touchLocation)
				if (coordinateOfPoint(touchLocation)?.x)! < 20 && (coordinateOfPoint(touchLocation)?.y)! < 20 &&
					(coordinateOfPoint(touchLocation)?.x)! >= 0 && (coordinateOfPoint(touchLocation)?.y)! >= 0 {
					print("================================")
					print(Int(position!.x))
					print(Int(position!.y))
					print("================================")
					if layout[Int(position!.x)][Int(position!.y)].components.count == 0 && placingTower == false{
						placingTowerOnNode = touchedNode
						showTowerSelector(atPosition: touchLocation)
						selectorPosition = position!
						return
					}
					else if placingTower {
						if let touchedNode = self.atPoint(touchLocation).name {
							placeTower(selectorPosition, touchedNode: touchedNode)
							hideTowerSelector()
							return
						} else {
							hideTowerSelector()
							return
						}
					}
				} else {
					if touchedNode.name == "LeaveButton" {
						let newScene = GameScene(fileNamed:"GameScene")
						newScene!.scaleMode = .aspectFill
						let reveal = SKTransition.doorsCloseHorizontal(withDuration: 0.5)
						self.view?.presentScene(newScene!, transition: reveal)
						return
					}
					if touchedNode.name == "PauseButton" && !isPaused{
						isPaused = true
					} else {
						isPaused = false
					}
				}
				break
			case is GameSceneLoseState:
				if touchedNode.name == "homeButton" {
					let newScene = GameScene(fileNamed:"GameScene")
					newScene!.scaleMode = .aspectFill
					let reveal = SKTransition.doorsCloseHorizontal(withDuration: 0.5)
					self.view?.presentScene(newScene!, transition: reveal)
					return
				}
				break
			case is GameSceneWinState:
				if touchedNode.name == "homeButton" {
					let newScene = GameScene(fileNamed:"GameScene")
					newScene!.scaleMode = .aspectFill
					let reveal = SKTransition.doorsCloseHorizontal(withDuration: 0.5)
					self.view?.presentScene(newScene!, transition: reveal)
					return
				}
				break
			default:
				break
			}
		}
	}
	
	func startFirstWave() {
		waveManager.startNextWave()
	}
	
	func addEntity(_ entity: GKEntity) {
		entities.insert(entity)
		for componentSystem in self.componentSystems {
			componentSystem.addComponent(foundIn: entity)
		}
		if let spriteNode = entity.component(
			ofType: SpriteComponent.self)?.node {
				addNode(spriteNode, toGameLayer: .sprites)
			//CHANGED
				spriteNode.sprite3d!.position = point2DToIso(spriteNode.position)
				addNode(spriteNode.sprite3d!, toGameLayer: .sprites)
		}
		//CHANGED
		
//		if let spriteISONode = entity.component(
//			ofType: SpriteComponent.self)?.ISOnode {
//			spriteISONode.position = point2DToIso(isoPos)
//			addNode(spriteISONode, toGameLayer: .sprites)
//		}
	}
	
	func addEnemy(_ enemyType: EnemyType, gridposition: int2, endGridPosition: int2) {
		let startPosition = pointForGridPosition(gridposition)
		let endPosition = pointForGridPosition(endGridPosition)
		
		let enemy = EnemyEntity(enemyType: enemyType, size: CGSize(width: GRID_SIZE, height: GRID_SIZE), endPoint: endPosition)
		let enemyNode = enemy.spriteComponent.node
		
		enemyNode.position = startPosition
		//CHANGED
//		enemy.spriteComponent.node.position = point2DToIso(enemy.spriteComponent.node.position)
		setEnemyOnPath(enemy, toPoint: enemy.endPoint)
		updateVisualPath()
		
//		enemy.spriteComponent.node.position = pointIsoTo2D(enemy.spriteComponent.node.position)
		addEntity(enemy)
	}
	
	func addTower(_ towerType: TowerType, gridPosition: int2) {
		if gold >= towerType.cost {
			gold -= towerType.cost
			moneySpent += towerType.cost
			updateHUD()
			if let node = graph.node(atGridPosition: gridPosition) {
				//CHANGED
				let position = pointForGridPosition(gridPosition)
				let coordinate = gridPosition
				
				let towerEntity = TowerEntity(towerType: towerType, size: CGSize(width: GRID_SIZE, height: GRID_SIZE))
				towerEntity.spriteComponent.node.position = position
				
				//Change?
				
				layout[Int(coordinate.x)][Int(coordinate.y)] = towerEntity
				
				graph.remove([node])
				recalculateEnemyPaths()
				if path != nil {updateVisualPath()}
				
				addEntity(towerEntity)
			}
		}
	}
	
	func addObstacle(_ obstacleType: ObstacleType, gridPosition: int2) {
		if let node = graph.node(atGridPosition: gridPosition) {
			let position = pointForGridPosition(gridPosition)
			let coordinate = gridPosition
			
			let obstacleEntity = ObstacleEntity(obstacleType: obstacleType, size: CGSize(width: GRID_SIZE * 0.9, height: GRID_SIZE * 0.9))
			obstacleEntity.spriteComponent.node.position = position
			layout[Int(coordinate.x)][Int(coordinate.y)] = obstacleEntity
			
			switch obstacleType {
			case .Wall:
				graph.remove([node])
				break
			case .Teleport:
				teleport.append(obstacleEntity)
				break
			default:
				break
			}
			addEntity(obstacleEntity)
		}
	}
	
	func randomPosition() ->int2 {
		let x: Int32
		let y: Int32
		
		x = Int32(arc4random() % UInt32(LEVEL_SIZE.column - 4))
		y = Int32(arc4random() % UInt32(LEVEL_SIZE.row - 1))
		
		return int2(x,y)
	}
	
	func coordinateOfPoint(_ location: CGPoint) -> int2? {
		let col = Int32(ceil((Double(location.x) - offsetX) / GRID_SIZE)) - 1
		let row = Int32(ceil((Double(location.y) - offsetY) / GRID_SIZE)) - 1
		
		return int2(col, row) // use range operator here to make it better
	}
	
	// returns CGPoint at center of grid coordinate
	func pointForGridPosition(_ gridPosition: int2) -> CGPoint {
		let x = Double(gridPosition.x) * GRID_SIZE + offsetX + (GRID_SIZE / 2)
		let y = Double(gridPosition.y) * GRID_SIZE + offsetY + (GRID_SIZE / 2)
		return CGPoint(x: x, y: y)
	}
	
	func ISOpointForGridPosition(_ gridPosition: int2) -> CGPoint{
	//invert y pre conversion
	let x = Double(gridPosition.x) * 20
	let y = Double(gridPosition.y) * 20
	//
	return CGPoint(x: x, y: y)
	}

	
	func createGrid() {
		grid = SKNode()
		
		let usableHeight = Double(size.height) * gridHeightModifier
		let usableWidth = Double(size.width) * gridWidthModifier
		
		offsetX = (Double(size.width) - GRID_SIZE * Double(LEVEL_SIZE.column)) / 4.0
		offsetY = (Double(size.height) - GRID_SIZE * Double(LEVEL_SIZE.row)) / 2.5
		
		for col in 0 ..< LEVEL_SIZE.column {
			let xPos = GRID_SIZE * Double(col)
			layout.append(Array(repeating: GKEntity(), count: LEVEL_SIZE.row))
			
			for row in 0 ..< LEVEL_SIZE.row {
				let yPos = GRID_SIZE * Double(row)
				
				let path = UIBezierPath(rect: CGRect(x: xPos + offsetX, y: yPos + offsetY, width: GRID_SIZE, height: GRID_SIZE))
				let box = SKShapeNode()
				box.path = path.cgPath
				box.strokeColor = UIColor.gray
				box.alpha = 0.3
				grid.addChild(box)
			}
		}
		self.addChild(grid)
	}
	
	
	
	func createOptionGrid() {
		optionGrid = SKNode()
		
		for row in 0 ..< LEVEL_SIZE.row / 2 {
			let yPos = GRID_SIZE * 2.0 * Double(row) + offsetY
			let path = UIBezierPath(rect: CGRect(x: GRID_SIZE * Double(LEVEL_SIZE.column) + offsetX * 1.3, y: yPos, width: GRID_SIZE * 2.0, height: GRID_SIZE * 2.0))
			let box = SKShapeNode()
			box.path = path.cgPath
			box.strokeColor = UIColor.gray
			box.alpha = 1.0
			box.lineWidth = 2.0
			
			pauseButton.position = hudConvertPlacement(0, hud: "Option", boxWidthAndHeight: CGSize(width: GRID_SIZE * 2.0, height: GRID_SIZE * 2.0))
			leaveButton.position = hudConvertPlacement(1, hud: "Option", boxWidthAndHeight: CGSize(width: GRID_SIZE * 2.0, height: GRID_SIZE * 2.0))
			sellButton.position = hudConvertPlacement(2, hud: "Option", boxWidthAndHeight: CGSize(width: GRID_SIZE * 2.0, height: GRID_SIZE * 2.0))
			buyButton.position = hudConvertPlacement(3, hud: "Option", boxWidthAndHeight: CGSize(width: GRID_SIZE * 2.0, height: GRID_SIZE * 2.0))
			recordButton.position = hudConvertPlacement(4, hud: "Option", boxWidthAndHeight: CGSize(width: GRID_SIZE * 2.0, height: GRID_SIZE * 2.0))
			
			optionGrid.addChild(box)
		}
		addChild(optionGrid)
	}
	
	func createHUDGrid() {
		hudGrid = SKNode()
		
		for row in 0 ..< LEVEL_SIZE.column / 6 {
			let yPos = GRID_SIZE * Double(LEVEL_SIZE.row) + offsetY + offsetX * 0.3
			let path = UIBezierPath(rect: CGRect(x: GRID_SIZE * 6.0 * Double(row) + offsetX, y: yPos, width: GRID_SIZE * 6.0, height: GRID_SIZE))
			let box = SKShapeNode()
			box.path = path.cgPath
			box.strokeColor = UIColor.gray
			box.alpha = 1.0
			box.lineWidth = 2.0
			
			hudGrid.addChild(box)
		}
		
		goldLabel.position = hudConvertPlacement(0, hud: "Stats", boxWidthAndHeight: CGSize(width: GRID_SIZE * 6.0, height: GRID_SIZE))
		baseLabel.position = hudConvertPlacement(1, hud: "Stats", boxWidthAndHeight: CGSize(width: GRID_SIZE * 6.0, height: GRID_SIZE))
		waveLabel.position = hudConvertPlacement(2, hud: "Stats", boxWidthAndHeight: CGSize(width: GRID_SIZE * 6.0, height: GRID_SIZE))
		diamondLabel.position = hudConvertPlacement(3, hud: "Stats", boxWidthAndHeight: CGSize(width: GRID_SIZE * 5.5, height: GRID_SIZE))
		self.addChild(hudGrid)
	}
	
	func hudConvertPlacement(_ gridPosition: Int, hud: String, boxWidthAndHeight: CGSize) ->CGPoint {
		let x: Double
		let y: Double
		
		let a = offsetY
		let b = offsetX
		let lOffset = b! * 0.3
		let boxW = boxWidthAndHeight.width / 2
		let boxH = boxWidthAndHeight.height / 2
		
		if hud == "Stats" {
			x = b! + Double(gridPosition + (gridPosition + 1)) * Double(boxW)
			y = a! + GRID_SIZE * Double(LEVEL_SIZE.row) + lOffset + Double(boxH)
			return CGPoint(x: x, y: y)
		} else if hud == "Option" {
			x = b! * 1.3 + GRID_SIZE * Double(LEVEL_SIZE.column) + Double(boxW)
			y = a! + Double(gridPosition + (gridPosition + 1)) * Double(boxH)
			return CGPoint(x: x, y: y)
		}
		return CGPoint(x: 0, y: 0)
	}
	
	func addHudStuff() {
		let optionStuffSize = CGSize(width: GRID_SIZE * 1.5, height: GRID_SIZE * 1.5)
		let statStuffSize = CGSize(width: GRID_SIZE / 2, height: GRID_SIZE / 2)
		
		pauseButton.size = optionStuffSize
		pauseButton.name = "PauseButton"
		self.addChild(pauseButton)
		leaveButton.size = optionStuffSize
		leaveButton.name = "LeaveButton"
		self.addChild(leaveButton)
		sellButton.size = optionStuffSize
		sellButton.name = "SellButton"
		self.addChild(sellButton)
		buyButton.size = optionStuffSize
		buyButton.name = "BuyButton"
		self.addChild(buyButton)
		recordButton.size = optionStuffSize
		recordButton.name = "RecordButton"
		self.addChild(recordButton)
		
		baseLabel.run(SKAction.fadeAlpha(to: 1.0, duration: 0.5))
		baseLabelImage.size = statStuffSize
		baseLabelImage.position = CGPoint(x: baseLabel.position.x - CGFloat(GRID_SIZE * 2.0), y: baseLabel.position.y)
		self.addChild(baseLabelImage)
		goldLabel.run(SKAction.fadeAlpha(to: 1.0, duration: 0.5))
		goldLabelImage.size = statStuffSize
		goldLabelImage.position = CGPoint(x: goldLabel.position.x - CGFloat(GRID_SIZE * 2.0), y: goldLabel.position.y)
		self.addChild(goldLabelImage)
		waveLabel.run(SKAction.fadeAlpha(to: 1.0, duration: 0.5))
		waveLabelImage.size = statStuffSize
		waveLabelImage.position = CGPoint(x: waveLabel.position.x - CGFloat(GRID_SIZE * 2.0), y: waveLabel.position.y)
		self.addChild(waveLabelImage)
		diamondLabel.run(SKAction.fadeAlpha(to: 1.0, duration: 0.5))
		diamondLabelImage.size = statStuffSize
		diamondLabelImage.position = CGPoint(x: diamondLabel.position.x - CGFloat(GRID_SIZE / 1.15), y: diamondLabel.position.y)
		self.addChild(diamondLabelImage)
		
	}
	
	func showTowerSelector(atPosition position: CGPoint) {
		if placingTower == true {return}
		placingTower = true
		
		let gridPosition = coordinateOfPoint(position)
		selectedBox = SKSpriteNode(imageNamed: "selectedBox1")
		selectedBox.alpha = 0.0
		let animation1 = SKAction.fadeAlpha(to: 0.5, duration: 0.5)
		selectedBox.position = pointForGridPosition(gridPosition!)
		selectedBox.size = CGSize(width: GRID_SIZE, height: GRID_SIZE)
		self.addChild(selectedBox)
		selectedBox.run(animation1)
		
		
		for towerSelectorNode in towerSelectorNodes {
			
			towerSelectorNode.position = pointForGridPosition(gridPosition!)
			gameLayerNodes[.hud]!.addChild(towerSelectorNode)
			
			towerSelectorNode.show()
		}
	}
	
	func hideTowerSelector() {
		if placingTower == false { return }
		placingTower = false
		
		let animation1 = SKAction.fadeAlpha(to: 0.0, duration: 1.0)
		selectedBox.run(animation1)
		
		for towerSelectorNode in towerSelectorNodes {
			towerSelectorNode.hide {
				towerSelectorNode.removeFromParent()
			}
		}
	}
	
	func loadTowerSelectorNodeForSellAndBuy(_ towerToSell: TowerType) {
		let towerTypeCount = TowerType.allValues.count
		let nodeForSellAndBuyPath: String = Bundle.main.path(forResource: "TowerMenu", ofType: "sks")!
		let nodeForSellAndBuyScene = NSKeyedUnarchiver.unarchiveObject(withFile: nodeForSellAndBuyPath) as! SKScene
		
		for t in 0..<towerTypeCount {
			let towerSelectorNode = (nodeForSellAndBuyScene.childNode(withName: "MainNode"))!.copy() as! TowerSelectorNode
			towerSelectorNode.setTowerSell(towerToSell, towerType: TowerType.allValues[t], pointForSelection: numToPointForSelection(t))
		}
	}
	
	func loadTowerSelectorNodes() {
		let towerTypeCount = TowerType.allValues.count
		
		let towerSelectorNodePath: String = Bundle.main.path(forResource: "TowerMenu", ofType: "sks")!
		let towerSelectorNodeScene = NSKeyedUnarchiver.unarchiveObject(withFile: towerSelectorNodePath) as! SKScene
		
		for t in 0..<towerTypeCount {
			let towerSelectorNode = (towerSelectorNodeScene.childNode(withName: "MainNode"))!.copy() as! TowerSelectorNode
			towerSelectorNode.setTower(TowerType.allValues[t], pointForSelection: numToPointForSelection(t))
			
			towerSelectorNodes.append(towerSelectorNode)
		}
	}
	
	func numToPointForSelection(_ number: Int) ->CGPoint {
		let x = CGFloat(GRID_SIZE * 1.4)
		switch number {
		case 0:
			return CGPoint(x: x, y: 0)
		case 1:
			return CGPoint(x: 0, y: x * 1.26)
		case 2:
			return CGPoint(x: -x, y: 0)
		case 3:
			return CGPoint(x: 0, y: -x)
		default:
			break
		}
		return CGPoint(x: x, y: 0)
	}
	
	func initializeGrid() {
		graph = GKGridGraph(fromGridStartingAt: int2(0, 0), width: Int32(LEVEL_SIZE.column), height: Int32(LEVEL_SIZE.row), diagonalsAllowed: false)
		pathLine = SKNode()
		self.addChild(pathLine)
	}
	
	func setEnemyOnPath(_ enemy: EnemyEntity, toPoint point: CGPoint)
	{
		let enemyNode = enemy.spriteComponent.node
		
//		let pos = enemyNode.position
//		let coord2d = pointIsoTo2D(pos)
//		let coord = coordinateOfPoint(coord2d)
		
		let currentNode = graph.node(atGridPosition: coordinateOfPoint(enemyNode.position)!)
		let endNode = graph.node(atGridPosition: coordinateOfPoint(enemy.endPoint)!)
		print ("=======================")

		print(currentNode)
		print(endNode)
		print ("=======================")
		
		path = graph.findPath(from: currentNode!, to: endNode!) as! [GKGridGraphNode]
		path.remove(at: 0)

		var sequence = [SKAction]()
		var sequenceIso = [SKAction]()
		
		for node in path {
			let location = pointForGridPosition(node.gridPosition)
			let locationIso = point2DToIso(location) //Changed
//			let location = point2DToIso(pointForGridPosition(node.gridPosition))
			let update = SKAction.run({ [unowned self] in
				enemyNode.position = location //self.pointForGridPosition(node.gridPosition)
				})
			//Changed
			let updateIso = SKAction.run({enemyNode.sprite3d?.position = locationIso})
			
			let actionDuration = TimeInterval(200.0 / enemy.enemyType.speed)
			let action = SKAction.move(to: location, duration: actionDuration)
			
			//Changed
			let actionIso = SKAction.move(to: locationIso, duration: actionDuration)
			
			sequence += [action,update]
			sequenceIso += [actionIso, updateIso]
		}
		enemyNode.run(SKAction.sequence(sequence))
		enemyNode.sprite3d?.run(SKAction.sequence(sequenceIso))
	}
	
	func recalculateEnemyPaths() {
		let enemies: [EnemyEntity] = entities.flatMap { entity in
			if let enemy = entity as? EnemyEntity {
				if enemy.healthComponent.health <= 0 {return nil}
				return enemy
			}
			return nil
		}
		
		for enemy in enemies {
			setEnemyOnPath(enemy, toPoint: enemy.endPoint)
		}
	}
	
	
	func updateVisualPath() {
		pathLine.removeAllChildren()
		
		let escapePath = self.path
		
		var index = 0
		for node in escapePath! {
			let position = pointForGridPosition(node.gridPosition)
			
			if index + 1 < (escapePath?.count)! {
				let nextPosition = pointForGridPosition((escapePath?[index + 1].gridPosition)!)
				let bezierPath = UIBezierPath()
				let startPoint = CGPoint(x: position.x, y: position.y)
				let endPoint = CGPoint(x: nextPosition.x, y: nextPosition.y)
				bezierPath.move(to: startPoint)
				bezierPath.addLine(to: endPoint)
				
				let pattern: [CGFloat] = [CGFloat(GRID_SIZE / 10), CGFloat(GRID_SIZE / 10)]
				let dashed = CGPath(__byDashing: bezierPath.cgPath, transform: nil, phase: 0, lengths: pattern, count: 2)!
				
				let line = SKShapeNode(path: dashed)
				line.strokeColor = UIColor.black
				pathLine.addChild(line)
				
				//CHANGED
				let bezierPath3d = UIBezierPath()
				let startPoint3d = point2DToIso((CGPoint(x: position.x, y: position.y)))
				let endPoint3d = point2DToIso(CGPoint(x: nextPosition.x, y: nextPosition.y))
				bezierPath3d.move(to: startPoint3d)
				bezierPath3d.addLine(to: endPoint3d)
				let dashed3d = CGPath(__byDashing: bezierPath3d.cgPath, transform: nil, phase: 0, lengths: pattern, count: 2)!
				let line3d = SKShapeNode(path: dashed3d)
				line3d.strokeColor = UIColor.black
				pathLine.addChild(line3d)
			}
			index += 1
		}
	}
	
	func placeTower(_ selectorPosition: int2, touchedNode: String) {
		if touchedNode == "Tower_Icon_WaterTower" {
			addTower(.Water, gridPosition: selectorPosition)
		} else if touchedNode == "Tower_Icon_PlantTower" {
			addTower(.Plant, gridPosition: selectorPosition)
		} else if touchedNode == "Tower_Icon_IceTower" {
			addTower(.Ice, gridPosition: selectorPosition)
		} else if touchedNode == "Tower_Icon_FireTower" {
			addTower(.Fire, gridPosition: selectorPosition)
		}
	}
	
	func loadLevel(_ level: Int) {
		let levelNumber = level - 1
		for i in 0..<LEVEL_SIZE.row {
			for j in 0..<LEVEL_SIZE.column {
				if levels[levelNumber][19 - i][j] == 1 {
					addObstacle(.Wall, gridPosition: int2(Int32(j),Int32(i)))
				} else if levels[levelNumber][19 - i][j] == 2 {
					addObstacle(.Slow, gridPosition: int2(Int32(j),Int32(i)))
				} else if levels[levelNumber][19 - i][j] == 3 {
					addObstacle(.Boost, gridPosition: int2(Int32(j),Int32(i)))
				} else if levels[levelNumber][19 - i][j] == 4 {
					addObstacle(.Repair, gridPosition: int2(Int32(j),Int32(i)))
				} else if levels[levelNumber][19 - i][j] == 5 {
					addObstacle(.Diamond, gridPosition: int2(Int32(j),Int32(i)))
				} else if levels[levelNumber][19 - i][j] == 6 {
					addObstacle(.Teleport, gridPosition: int2(Int32(j),Int32(i)))
				}
			}
		}
	}
	
	func remove(_ entity: GKEntity) {
		if let spriteNode = entity.component(ofType: SpriteComponent.self)?.node {
			spriteNode.sprite3d?.removeFromParent()
			spriteNode.sprite3d = nil
			spriteNode.removeFromParent()
		}
		entities.remove(entity)
	}
	
	func explosion(_ position: CGPoint, explosionType: String) {
		let explosionEmitterNode = SKEmitterNode(fileNamed:"ExplosionParticule")
		explosionEmitterNode!.position = position
		explosionEmitterNode?.zPosition = 2
		
		self.addChild(explosionEmitterNode!)
		
		let coinEarnedImage = SKSpriteNode(imageNamed: "GoldImage")
		coinEarnedImage.position = (explosionEmitterNode?.position)!
		coinEarnedImage.size = CGSize(width: GRID_SIZE / 2, height: GRID_SIZE / 2)
		coinEarnedImage.zPosition = 2
		addChild(coinEarnedImage)
		coinEarnedImage.run(SKAction.move(to: goldLabelImage.position, duration: 1.0))
	}
	
	func teleportParticule(_ position: CGPoint, explosionType: String) {
		let explosionEmitterNode = SKEmitterNode(fileNamed:"MagicTp")
		explosionEmitterNode!.position = position
		explosionEmitterNode?.zPosition = 2
		
		self.addChild(explosionEmitterNode!)
	}
	
	func boosterParticule(_ position: CGPoint, explosionType: String) {
		let explosionEmitterNode = SKEmitterNode(fileNamed:"SlowAndBoost")
		explosionEmitterNode!.position = position
		explosionEmitterNode?.zPosition = 2
		self.addChild(explosionEmitterNode!)
	}
	
	
	// Camera
	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		for touch in touches {
			let location = touch.location(in: self)
			let previousLocation = touch.previousLocation(in: self)
			
			let deltaX = location.x - previousLocation.x
			let deltaY = location.y - previousLocation.y
			cameraNode.position.x -= deltaX
			cameraNode.position.y -= deltaY
		}
	}
}




