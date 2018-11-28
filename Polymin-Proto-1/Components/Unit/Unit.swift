//
//  Unit.swift
//  Polymin-Proto-1
//
//  Created by Tyler Angert on 11/18/18.
//  Copyright © 2018 Tyler Angert. All rights reserved.
//

import Foundation
import ARKit
import AudioKit
import MusicTheorySwift

/*
 
 The unit contains three main respoinsibilities
 
 1. Math: the  calculations between nodes and the camera to feed into the sound and visuals
 2. Sound: the actual audio kit details
 3. Visual: the interface and response to the data
 4. Music theory: the scale calculations for each unit
  
*/

class Unit: SCNNode {
    
    // MARK: Constants
    var scaleFactor: CGFloat = 1.25
    var animationDuration: TimeInterval = 0.15
    
    // MARK: Children
    var id: String!
    var node: Node!
    var connection: Connection!
    var synth: AKOscillator!
    var label: SCNNode!
    
    // MARK: Local state
    // Musical properties begin with an underscore
    var selected: Bool! = true
    var _key: Key!
    var _scaleType: ScaleType!
    var _scale : Scale {
        return Scale(type: _scaleType, key: _key)
    }
    
    override init() {
        super.init()
    }
    
    init(cameraPosition: SCNVector3, nodePosition: SCNVector3) {
    
        super.init()
        
        // Child properties
        node = Node(position: nodePosition)
        connection = Connection(from: cameraPosition, to: nodePosition)
        synth = AKOscillator(waveform: AKTable(.sine))
        
        synth.rampDuration = 0.05
        label = createTextNode(string: "Play!")
        
        // Set the identifier for the visible child node
        let id = UUID().uuidString
        self.id = id
        self.name = id
        node.name = id
        
        self.addChildNode(node)
        self.addChildNode(label)
    }
    
    
    // MARK: Helper methods
    // updates the properties of the note based on changes from the global store. called from subscribe method
    func select() {
        selected = true
        
        if !synth.isStarted {
            synth.start()
        }
        
        node.runAction(SCNAction.scale(by: scaleFactor, duration: animationDuration))
        node.runAction(SCNAction.fadeOpacity(to: 1, duration: animationDuration))
        label.runAction(SCNAction.fadeOpacity(to: 1, duration: animationDuration))
    }
    
    func deselect() {
        selected = false
        synth.stop()
        node.runAction(SCNAction.scale(by: 1/scaleFactor, duration: animationDuration))
        node.runAction(SCNAction.fadeOpacity(to: 0.6, duration: animationDuration))
        label.runAction(SCNAction.fadeOpacity(to: 0.3, duration: animationDuration))
    }
    
    func createTextNode(string: String) -> SCNNode {
        let text = SCNText(string: string, extrusionDepth: 0.1)
        text.font = UIFont.systemFont(ofSize: 1.0)
        text.flatness = 0.001
        text.firstMaterial?.diffuse.contents = UIColor.white
        
        let textNode = SCNNode(geometry: text)
        
        let fontSize = Float(0.02)
        textNode.scale = SCNVector3(fontSize, fontSize, fontSize)
        let offset = Float(node.radius/2)
        textNode.position = SCNVector3(node.position.x - offset, node.position.y  + offset, node.position.z)
        return textNode
    }
    
    func updateText(newText: String) {
        if let textGeometry = label.geometry as? SCNText {
            textGeometry.string = newText
        }
    }
    
    func clear() {
        self.removeFromParentNode()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
}
