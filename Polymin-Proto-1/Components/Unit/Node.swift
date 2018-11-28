//
//  Sphere.swift
//  Polymin-Proto-1
//
//  Created by Tyler Angert on 10/13/18.
//  Copyright © 2018 Tyler Angert. All rights reserved.
//

import Foundation
import ARKit

class Node: SCNNode {
    
    let radius: CGFloat = 0.01
    
    override init() {
        super.init()
        self.geometry = SCNSphere(radius: radius)
    }
    
    init(position: SCNVector3) {
        super.init()
        self.geometry = SCNSphere(radius: radius)
        
        // Graphics setup
        let reflectiveMaterial = SCNMaterial()
        reflectiveMaterial.lightingModel = .physicallyBased
        reflectiveMaterial.metalness.contents = 1.0
        reflectiveMaterial.roughness.contents = 0
        self.geometry?.firstMaterial = reflectiveMaterial
        
        // Set the position
        self.position = position
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
}
