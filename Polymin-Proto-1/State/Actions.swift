//
//  Actions.swift
//  Polymin-Proto-1
//
//  Created by Tyler Angert on 11/20/18.
//  Copyright © 2018 Tyler Angert. All rights reserved.
//

import Foundation
import ReSwift
import SceneKit

// MARK: UI Interactions
// Add a unit to the screen! Needs the tapped position and an ID
struct addUnit: Action {
    var id: String!
    var unit: Unit!
    init(unit: Unit) {
        self.unit = unit
        self.id = unit.name
    }
}

// Removes a given unit from the tree
struct removeUnit: Action {
    var id: String!
    init(id: String) {
        self.id = id
    }
}

// Moves a unit with a pan
struct moveUnit: Action {
    var id: String!
    init(id: String) {
        self.id = id
    }
}


// MARK: Boolean toggles
struct setIsQuantized: Action {
    var val: Bool!
    init(val: Bool) {
        self.val = val
    }
}

struct setIsPlaying: Action {
    var val: Bool!
    init(val: Bool) {
        self.val = val
    }
}

// MARK: Math and camera position
struct setNewCameraPosition: Action {
    var pos: SCNVector3
    init(pos: SCNVector3) {
        self.pos = pos
    }
}

