//
//  FiringComponent.swift
//  TookaDefense
//
//  Created by Antoine Beneteau on 10/11/2015.
//  Copyright © 2015 Tastyapp. All rights reserved.
//

import SpriteKit
import GameplayKit

class FiringComponent: GKComponent {
	
	let towerType: TowerType
	let parentComponent: SpriteComponent
	var currentTarget: EnemyEntity?
	var timeTillNextShot: TimeInterval = 0
	
	
	init(towerType: TowerType, parentComponent: SpriteComponent) {
		self.towerType = towerType
		self.parentComponent = parentComponent
		super.init()
	}

	required init?(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}
	
	override func update(deltaTime seconds: TimeInterval) {
		super.update(deltaTime: seconds)
		
		guard let target = currentTarget else { return }
		
		
		timeTillNextShot -= seconds
		if timeTillNextShot > 0 { return }
		timeTillNextShot = towerType.fireRate
		
		let projectile = ProjectileEntity(towerType: towerType)
		let projectileNode = projectile.spriteComponent.node
		
		//CHANGED
//		let projectileISONode = projectile.spriteComponent.ISOnode
//		projectileISONode.position = point2DToIso(projectileNode.position)
//		parentNode.addChild(projectileISONode)
		
		projectileNode.position = CGPoint(x: 0.0, y: 0.0)
		parentComponent.node.addChild(projectileNode)
		
		
		
		let targetNode = target.spriteComponent.node
		projectileNode.rotateToFaceNode(targetNode, sourceNode: parentComponent.node)
		
		
		let fireVector = CGVector(dx: targetNode.position.x - parentComponent.node.position.x, dy: targetNode.position.y - parentComponent.node.position.y)
		
		let soundAction = SKAction.playSoundFileNamed("\(towerType.rawValue)Fire.mp3", waitForCompletion: false)
		let fireAction = SKAction.move(by: fireVector, duration: 0.2)
		let damageAction = SKAction.run { () -> Void in
			target.healthComponent.takeDamage(self.towerType.damage)
		}
		let removeAction = SKAction.run { () -> Void in
			projectileNode.removeFromParent()
		}
		
		let action = SKAction.sequence([soundAction, fireAction, damageAction,removeAction])
		projectileNode.run(action)
		
		//Changed
		let projectileIsoNode = projectileNode.sprite3d
		projectileIsoNode?.position = point2DToIso(CGPoint(x: 0.0, y: 0.0))
		parentComponent.node.sprite3d?.addChild(projectileIsoNode!)
		
		//CHANGED
		let targetISONode = targetNode.sprite3d
		projectileIsoNode?.rotateToFaceNode(targetISONode!, sourceNode: parentComponent.node.sprite3d!)
		
		//CHANGED
		let fireVectorIso = CGVector(dx: (targetISONode?.position.x)! - (parentComponent.node.sprite3d?.position.x)!, dy: (targetISONode?.position.y)! - (parentComponent.node.sprite3d?.position.y)!)
		
		let fireActionIso = SKAction.move(by: fireVectorIso, duration: 0.2)
		let damageActionIso = SKAction.run{ () -> Void in
			target.healthComponentIso.takeDamage(self.towerType.damage)
		}
		let removeActionIso = SKAction.run {
			() -> Void in
			projectileIsoNode?.removeFromParent()
		}
		
		let actionIso = SKAction.sequence([fireActionIso, damageActionIso, removeActionIso])
		projectileIsoNode?.run(actionIso)
	}
}


