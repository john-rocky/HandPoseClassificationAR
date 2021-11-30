//
//  ARViewController.swift
//  HandPoseClassificationAR
//
//  Created by 間嶋大輔 on 2021/11/27.
//

import UIKit
import CoreML
import ARKit
import Vision
import SceneKit

class ARViewController: UIViewController,ARSessionDelegate {

//    var arView: ARView!
    var arScnView: ARSCNView!
    var frameCounter: Int = 0
    let handPosePredictionInterval: Int = 30
    var model = try? HandPoseClassifier(configuration: MLModelConfiguration())
    var viewWidth:Int = 0
    var viewHeight:Int = 0
    var currentHandPoseObservation: VNHumanHandPoseObservation?
    var heartNode: SCNNode!
    var starNodes: [SCNNode] = []
    var isEffectAppearing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        arScnView = ARSCNView(frame: view.bounds)
        view.addSubview(arScnView)
        viewWidth = Int(arScnView.bounds.width)
        viewHeight = Int(arScnView.bounds.height)

        let config = ARFaceTrackingConfiguration()
        arScnView.session.delegate = self
        arScnView.session.run(config, options: [.removeExistingAnchors])
        prepareEffects()
       
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        let pixelBuffer = frame.capturedImage
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let handPoseRequest = VNDetectHumanHandPoseRequest()
            handPoseRequest.maximumHandCount = 1
            handPoseRequest.revision = VNDetectHumanHandPoseRequestRevision1
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,orientation: .right , options: [:])
            do {
                try handler.perform([handPoseRequest])
            } catch {
                assertionFailure("HandPoseRequest failed: \(error)")
            }
            
            guard let handPoses = handPoseRequest.results, !handPoses.isEmpty else { return }
            guard let observation = handPoses.first else { return }
            currentHandPoseObservation = observation
            frameCounter += 1
            if frameCounter % handPosePredictionInterval == 0 {
                frameCounter = 0
                makePrediction(handPoseObservation: observation)
            }
        }
    }
    
    func makePrediction(handPoseObservation: VNHumanHandPoseObservation) {
        guard let keypointsMultiArray = try? handPoseObservation.keypointsMultiArray() else { fatalError() }
        do {
            let prediction = try model!.prediction(poses: keypointsMultiArray)
            let label = prediction.label
            guard let confidence = prediction.labelProbabilities[label] else { return }
            print("label:\(prediction.label)\nconfidence:\(confidence)")
            if confidence > 0.9 {
                switch label {
                case "fingerHeart":displayFingerHeartEffect()
                case "peace":displayPeaceEffect()
                default : break
                }
            }
        } catch {
            print("Prediction error")
        }
    }
    
    func displayFingerHeartEffect(){
        guard !isEffectAppearing else { return }
        isEffectAppearing = true
        guard let handPoseObservation = currentHandPoseObservation,let indexFingerPosition = getHandPosition(handPoseObservation: handPoseObservation) else {return}
        heartNode.position = indexFingerPosition
        let fadeIn = SCNAction.fadeIn(duration: 0.2)
        let up = SCNAction.move(by: SCNVector3(x: 0, y: 0.1, z: 0), duration: 0.1)
        let shakeHalfRight = SCNAction.rotate(by: -0.3, around: SCNVector3(x: 0, y: 0, z: 1), duration: 0.025)
        let shakeLeft = SCNAction.rotate(by: 0.6, around: SCNVector3(x: 0, y: 0, z: 1), duration: 0.05)
        let shakeRight = SCNAction.rotate(by: -0.6, around: SCNVector3(x: 0, y: 0, z: 1), duration: 0.05)
        let shakeHalfLeft = SCNAction.rotate(by: 0.3, around: SCNVector3(x: 0, y: 0, z: 1), duration: 0.025)
        let shake = SCNAction.sequence([shakeLeft,shakeRight])
        let fadeOut = SCNAction.fadeOut(duration: 1)
        let shakeRepeat = SCNAction.sequence([shakeHalfRight,shake,shake,shake,shake,shakeHalfLeft])
        let switchEffectAppearing = SCNAction.run { node in
            self.isEffectAppearing = false
        }
        heartNode.runAction(.sequence([fadeIn,up,shakeRepeat,fadeOut,switchEffectAppearing]))
    }
    
    func displayPeaceEffect(){
        starNodes.forEach { star in
            star.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: star.geometry ?? SCNBox(width: 0.01, height: 0.01, length: 0.01, chamferRadius: 0), options: [:]))

        }
    }
    
    func getHandPosition(handPoseObservation: VNHumanHandPoseObservation) -> SCNVector3? {
        guard let indexFingerTip = try? handPoseObservation.recognizedPoints(.all)[.indexPIP],
              indexFingerTip.confidence > 0.3 else {return nil}
        let deNormalizedIndexPoint = VNImagePointForNormalizedPoint(CGPoint(x: indexFingerTip.location.x, y:1-indexFingerTip.location.y), viewWidth,  viewHeight)
        let infrontOfCamera = SCNVector3(x: 0, y: 0, z: -0.2)
        guard let cameraNode = arScnView.pointOfView else { return nil}
        let pointInWorld = cameraNode.convertPosition(infrontOfCamera, to: nil)
        var screenPos = arScnView.projectPoint(pointInWorld)
        screenPos.x = Float(deNormalizedIndexPoint.x)
        screenPos.y = Float(deNormalizedIndexPoint.y)
        let finalPosition = arScnView.unprojectPoint(screenPos)
        print(finalPosition)
        return finalPosition
    }
    
    func prepareEffects() {
        let scene = SCNScene(named: "art.scnassets/Effects.scn")!
        guard let heart = scene.rootNode.childNode(withName: "Love reference", recursively: true)?.clone() else {return}
        heart.scale = SCNVector3(x: 0.0005, y: 0.0005, z: 0.0005)
        heartNode = heart
        arScnView.scene.rootNode.addChildNode(heart)
        heart.opacity = 0
        
        for _ in 0...7 {
            guard let star = scene.rootNode.childNode(withName: "starBox", recursively: true)?.clone() else {return}
            star.scale = SCNVector3(x: 0.01, y: 0.01, z: 0.01)
            starNodes.append(star)
        }
    }
}
