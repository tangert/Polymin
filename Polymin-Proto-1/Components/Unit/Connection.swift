//
//  Connection.swift
//  Polymin-Proto-1
//
//  Created by Tyler Angert on 10/13/18.
//  Copyright © 2018 Tyler Angert. All rights reserved.
//

import Foundation
import SceneKit
import ARKit

// Perhaps have a connection model (a struct) and also a connection visualization (the node)
class Connection {
    
    // Adds a connection using only the two vector positions
    var spherePos: SCNVector3!
    var cameraPos: SCNVector3!
    
    // FIXME: clean this up yo
    var startPos: SCNVector3!
    var endPos: SCNVector3!
    
    init(from cameraPos: SCNVector3, to spherePos: SCNVector3) {
        self.spherePos = spherePos
        self.cameraPos = cameraPos
        
        // Don't draw the connection
        startPos = self.cameraPos
        endPos = self.spherePos
    }
    
    func update(newCameraPos: SCNVector3) {
        // Calibrate the new position
        let newPos = SCNVector3(newCameraPos.x, newCameraPos.y - 0.0035, newCameraPos.z - 0.0025)
        startPos = newPos
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
