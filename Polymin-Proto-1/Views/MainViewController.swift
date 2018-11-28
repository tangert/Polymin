//
//  ViewController.swift
//  Polymin-Proto-1
//
//  Created by Tyler Angert on 10/13/18.
//  Copyright © 2018 Tyler Angert. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import AudioKit
import MusicTheorySwift
import ReSwift
import Pitchy

let FORCE_THRESHOLD: CGFloat = 5.5

class MainViewController: UIViewController, StoreSubscriber {

    @IBOutlet var sceneView: ARSCNView!
    
    // These are the local variables that emulate the state!
    // They're updated each time the state is changed.
    
    // NEW UNTIS: var units : [String: Unit] = [String: Unit]()
    var units = [Unit]()
    
    // Currently grabbed for moving
    var grabbedUnit: Unit?
    
    // Keeps track of selected units
    var selectedUnits: [String: Bool] = [String: Bool]()
    
    var unitIsSelected: Bool! = false
    var isQuantized: Bool! = false
    var isPlaying: Bool! = false
    var currentForce: CGFloat! = 0
    
    // MARK: Basic audiokit stuff
    var mixer = AKMixer()
    var delay = AKDelay()
    var reverb = AKReverb()
    
    // current frequency
    var cameraPosition: SCNVector3!
    var currQuantizedFreq: Float = 0
    
    // Have global vs local
    // TODO: Eventually move both of these to internal variables INSIDE of each component
    // Make both key and type configurable for each note
    var currentKey: Key = "c"
    var currentScaleType: ScaleType = ScaleType.major
    
    var currentNotes: [MusicTheorySwift.Pitch] {
        return Scale(type: currentScaleType, key: currentKey).pitches(octaves: [0,1,2,3,4,5,6,7,8])
    }
    
    var frequenciesFromNotes : [Float] {
        return currentNotes.compactMap({ $0.frequency })
    }
    
    var currentDistance: Float = 0
    
    // MARK: IBOutlets
    @IBOutlet weak var keyPicker: UIPickerView!
    @IBOutlet weak var scaleTypePicker: UIPickerView!
    @IBOutlet weak var quantizeSwitch: UISwitch!
    @IBOutlet weak var playButton: UIButton!
    
    // For the pickers
    var allKeys: [Key] = ["c","c#","d","d#","e","f","f#","g","g#","a","a#","b"]
    var allScales: [ScaleType] = [.major, .minor, .pentatonicBlues, .chromatic, .whole, .spanishGypsy]

    func newState(state: AppState) {
        cameraPosition = state.cameraPosition
    }
    
    // MARK: View life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Delegates
        self.keyPicker.delegate = self
        self.keyPicker.dataSource = self
        self.keyPicker.tag = 0
        
        self.scaleTypePicker.delegate = self
        self.scaleTypePicker.dataSource = self
        self.scaleTypePicker.tag = 1
        
        self.quantizeSwitch.isOn = false
        
        setupARScene()
        setupAudio()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // ReSwift store
        store.subscribe(self)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.environmentTexturing = .automatic
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        store.unsubscribe(self)
    }
    
    
    func setupARScene() {
        // Basic ARKit setup
        sceneView.delegate = self
        sceneView.session.delegate = self
//        sceneView.showsStatistics = true
//        sceneView.debugOptions = ARSCNDebugOptions.showFeaturePoints
        
        let scene = SCNScene()
        sceneView.scene = scene
    }
    
    // MARK: UI setup
    func setupUI() {
        // Picker
        keyPicker.backgroundColor = UIColor.white.withAlphaComponent(0.7)
        keyPicker.tintColor = UIColor.white
        keyPicker.layer.cornerRadius = 15
        keyPicker.clipsToBounds = true
        
        scaleTypePicker.backgroundColor = UIColor.white.withAlphaComponent(0.7)
        scaleTypePicker.tintColor = UIColor.darkGray
        scaleTypePicker.layer.cornerRadius = 15
        scaleTypePicker.clipsToBounds = true
        
        
        playButton.backgroundColor = UIColor.white.withAlphaComponent(0.7)
        playButton.layer.cornerRadius = playButton.bounds.size.width/2
        playButton.clipsToBounds = true
    }
    
    // MARK: Audio setup
    func setupAudio() {
        
        reverb.dryWetMix = 0.5
        delay.time = 0.5
        
        mixer = AKMixer([reverb, delay])
        mixer.volume = 1/self.units.count

        AudioKit.output = mixer
        do {
            try AudioKit.start()
        } catch {
            AKLog("AudioKit did not start!")
        }
    }

    @IBAction func quantizePressed(_ sender: UISwitch) {
        isQuantized.toggle()
    }
    
    @IBAction func pressPlay(_ sender: UIButton) {
        isPlaying = false
        turnSynths(on: false)
        UIView.animate(withDuration: 0.1) {
            self.playButton.backgroundColor = UIColor.white.withAlphaComponent(0.7)
            self.playButton.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        }
    }
    
    @IBAction func playDown(_ sender: Any) {
        isPlaying = true
        turnSynths(on: true)
        UIView.animate(withDuration: 0.1) {
            self.playButton.backgroundColor = UIColor.white.withAlphaComponent(0.9)
            self.playButton.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
        }
    }
    
    func getTouchedPosition() -> SCNVector3 {
        guard let cameraNode = self.sceneView.pointOfView else { return SCNVector3() }
        let distance: Float = 0.05 // Hardcoded depth
        let pos = getSceneSpacePosition(inFrontOf: cameraNode, atDistance: distance)
        return pos
    }
    
    func getSceneSpacePosition(inFrontOf node: SCNNode, atDistance distance: Float) -> SCNVector3 {
        let localPosition = SCNVector3(x: 0, y: 0, z: -distance)
        let scenePosition = node.convertPosition(localPosition, to: nil)
        return scenePosition
    }
    
    // FIXME: do better with error checking!
    
    func updateFrequencies() {
        // go through and calculate the distance for EACH unit
        // Need to localize the quantization
        
        for i in 0..<units.count {

            let unit = units[i]
            let synth = unit.synth
            let conn = unit.connection
            
            // Update the position
            conn!.update(newCameraPos: cameraPosition)
            
            let billboardConstraint = SCNBillboardConstraint()
            billboardConstraint.freeAxes = [.X, .Y, .Z]
            unit.label.constraints = [billboardConstraint]
            
            
            // Calculate the distance between that connection's sphere node and the camera
            let distance = GLKVector3Distance(SCNVector3ToGLKVector3(cameraPosition), SCNVector3ToGLKVector3(conn!.spherePos))
            
            // Calculate the frequency
            // TODO: Make this adjustable?
            let freq = 50/distance
            
            if !isPlaying && !unit.label.isHidden {
                unit.label.isHidden = true
            } else if isPlaying {
                unit.label.isHidden = false
            }
            
            if isQuantized {
                guard let quantizedFreq = frequenciesFromNotes.first(where: { Float($0) >= freq }) else { return }
                
                do {
                    let note = try PitchCalculator.offsets(forFrequency: Double(quantizedFreq)).closest.note.string
                    // Excess calls
                    unit.updateText(newText: note)
                    synth!.frequency = Double(quantizedFreq)
                } catch {
                    print("error grabbing note")
                }

            } else {
                
                do {
                    let note = try  PitchCalculator.offsets(forFrequency: Double(freq)).closest.note.string
                    unit.updateText(newText: note)
                    synth!.frequency = Double(freq)
                } catch {
                    print("error grabbing note")
                }
            }
            
        }
    }
    
    func startSynths() {
        for u in units{
            if(!u.synth.isStarted && u.selected) {
                u.synth.start()
            }
        }
    }
    
    // MARK: Basic touch handling
    func turnSynths(on: Bool) {
        if on {
            mixer.volume = 1
        } else {
            mixer.volume = 0
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        guard let touch = touches.first else { return }
        let touchLocation: CGPoint = touch.location(in: sceneView)
        let hits = self.sceneView.hitTest(touchLocation, options: nil)
        
        if !hits.isEmpty {
            
            guard let tappedUnit = hits.first?.node else { return }
            guard let selected = store.state.units[tappedUnit.name!] else { return }
            guard let id = selected.id else { return }
            
            // If it's not selected, turn it on
            if !selectedUnits[id]! {
                selectedUnits[id] = true
                grabbedUnit = selected
                selected.select()
            } else {
                // it's already been selected; turn it off
                selectedUnits[id] = false
                selected.deselect()
            }
            unitIsSelected = true
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        //1. Get The Current Touch Point
        guard let touch = touches.first else { return }
        currentForce = touch.force

        if currentForce > FORCE_THRESHOLD {
            // should check the curent position that the node is gonna grab
            // Create a unit
            let nodePos = getTouchedPosition()
            mixer.volume = 0
            startSynths()
            
            if positionIsValid(unitPosition: nodePos, threshold: 0.02, otherUnits: units) {
                
                let unit = Unit(cameraPosition: cameraPosition, nodePosition: nodePos)
                unit.select()
//                unit.synth.start()
                
                // REDUX
                store.dispatch(addUnit(unit: unit))
                
                // Add to the list of units
                units.append(unit)
                
                // initialize the unit id into the dict
                selectedUnits[unit.id] = true
                
                // Connect it's synth to the mixer
                mixer.connect(input: unit.synth)
                mixer.volume = 1/self.selectedUnits.keys.count
                
                // Add to the view
                self.sceneView.scene.rootNode.addChildNode(unit)
            }
        }
    }
    
    func positionIsValid(unitPosition: SCNVector3, threshold: CGFloat, otherUnits: [Unit]) ->  Bool {
        if otherUnits.count < 1 {
            return true
        }
        let currentPos = SCNVector3ToGLKVector3(unitPosition)
        for u in otherUnits {
            let comparisonPos = SCNVector3ToGLKVector3(u.node.position)
            let d = CGFloat(GLKVector3Distance(currentPos, comparisonPos))
            if d <= threshold {
                return false
            }
        }
        return true
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("Touches ended")
//        store.dispatch(setIsPlaying(val: false))
//        turnSynths(on: false)
        grabbedUnit = nil
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("Touches cancelled")
    }
}


// MARK: ARKit Delegates
extension MainViewController: ARSCNViewDelegate, ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        let space = frame.camera.transform.columns.3
        let cameraPosition = SCNVector3(space.x, space.y, space.z)
        
        store.dispatch(setNewCameraPosition(pos: cameraPosition))
        
        // if you are within a certain distance just turn them off!
        
        
        if let grabbed = grabbedUnit {
            
            // Updates the position
//            let newPos = SCNVector3(cameraPosition.x, cameraPosition.y, cameraPosition.z - 0.035)
//            if positionIsValid(unitPosition: newPos, threshold: 0.02, otherUnits: units) {
//                // FIXME: need to make these reactive, it's all manual updates now
//                // Also palce into one big update function
//                grabbed.connection.spherePos = newPos
//                grabbed.connection.update(newCameraPos: newPos)
//                let offset = Float(grabbed.node.radius/2)
//                grabbed.label.position = SCNVector3(newPos.x - offset*3, newPos.y  + offset, newPos.z)
//                grabbed.node.runAction(SCNAction.move(to: newPos, duration: 0.1))
//            }
        }
        
        if self.units.count > 0 {
            updateFrequencies()
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
}

extension MainViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    
    // Number of columns of data
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // The number of rows of data
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView.tag == 0 {
            return allKeys.count
        } else {
            return allScales.count
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView.tag == 0 {
            let pickedKey = allKeys[pickerView.selectedRow(inComponent: component)]
            currentKey = pickedKey
        } else {
            let pickedScaleType = allScales[pickerView.selectedRow(inComponent: component)]
            currentScaleType = pickedScaleType
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        var labelData: String!
        
        if pickerView.tag == 0 {
            labelData = allKeys[row].description
        } else {
            labelData = allScales[row].description
        }
        
        pickerView.subviews[1].isHidden = true
        pickerView.subviews[2].isHidden = true

        let myTitle = NSAttributedString(string: labelData, attributes: [NSAttributedStringKey.foregroundColor: UIColor.black.withAlphaComponent(0.9), NSAttributedStringKey.font: UIFont.systemFont(ofSize: 13, weight: UIFont.Weight.black)])
        
        return myTitle
    }
}
