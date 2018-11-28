//
//  MainStore.swift
//  Polymin-Proto-1
//
//  Created by Tyler Angert on 11/18/18.
//  Copyright © 2018 Tyler Angert. All rights reserved.
//

import Foundation
import SceneKit
import ReSwift

// MARK: Overall state
// Global state and shared variables.
struct AppState: StateType {
    var units: [String: Unit] = [String: Unit]() // Form: [ unitID : Unit ]
    var isPlaying: Bool = false
    var isQuantized: Bool = false
    var cameraPosition: SCNVector3 = SCNVector3(x: 0, y: 0, z: 0)
    
    // Split up into substates to subscribe to the appropriate things
    var cameraState = CameraState()
}

struct UIState: StateType {
    var isPlaying: Bool = false
    var isQuantized: Bool = false
}

struct CameraState: StateType {
    var cameraPosition: SCNVector3 = SCNVector3(x: 0, y: 0, z: 0)
}


// MARK: Validation functions before mutating state

// Makes sure that movement / placement doesn't occur within a certain radius.
func unitIsValid(unit: Unit, otherUnits: [Unit]) ->  Bool {
    let currentPos = SCNVector3ToGLKVector3(unit.position)
    let threshold = unit.node.radius
    for u in otherUnits {
        let comparisonPos = SCNVector3ToGLKVector3(u.position)
        let d = CGFloat(GLKVector3Distance(currentPos, comparisonPos))
//        print("Distance validation: \(d)")
        if d < threshold {
            return false
        }
    }
    return true
}


// MARK: Reducers
func appReducer(action: Action, state: AppState?) -> AppState {
    
    var state = state ?? AppState()
    
    switch action {
    case let a as addUnit:
        let isValid = unitIsValid(unit: a.unit, otherUnits: Array(state.units.values))
        state.units[a.id] = a.unit
        
    case let a as removeUnit:
        state.units[a.id] = nil
        
    case let a as setNewCameraPosition:
        state.cameraPosition = a.pos
        
    case let a as setIsQuantized:
        state.isQuantized = a.val
        
    case let a as setIsPlaying:
        state.isPlaying = a.val
        
    default:
        break
    }
    
    return state

}


// MARK: Store
var store = Store(
    reducer: appReducer,
    state: AppState(),
    middleware: [])
