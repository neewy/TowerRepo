//
//  SpriteComponent.swift
//  TookaDefense
//
//  Created by Antoine Beneteau on 10/11/2015.
//  Copyright © 2015 Tastyapp. All rights reserved.
//

import SpriteKit
import GameplayKit

class EntityNode: SKSpriteNode {
	weak var entite: GKEntity!
	var sprite3d: SKSpriteNode?
}

class SpriteComponent: GKComponent {
	
	let node: EntityNode
//	let ISOnode: EntityNode
	
	init(entity: GKEntity, texture: SKTexture, size: CGSize, name: String) {
		node = EntityNode(texture: texture, color: SKColor.white, size: size)
		node.name = name
		node.entite = entity
//		make transparent
//		node.alpha = 0
		
		//CHANGED
		node.sprite3d = EntityNode(texture: texture, color: SKColor.white, size: size)
		node.sprite3d?.name = name
		
		if name == "Slow" || name == "Boost" || name == "Teleport" || name == "Repair" {
			node.alpha = 0.7
			node.zPosition = 0
		}
		if name == "Enemy" {
			node.zPosition = 1
		}
		super.init()
	}

	required init?(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}
}

