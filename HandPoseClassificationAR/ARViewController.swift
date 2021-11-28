//
//  ARViewController.swift
//  HandPoseClassificationAR
//
//  Created by 間嶋大輔 on 2021/11/27.
//

import UIKit
import CoreML
import ARKit
import RealityKit
import Vision
import SceneKit

class ARViewController: UIViewController,ARSessionDelegate {

    var arView: ARView!
    var frameCounter: Int = 0
    let handPosePredictionInterval: Int = 30
    var model = try? HandPoseClassifier(configuration: MLModelConfiguration())
    var viewWidth:Int = 0
    var viewHeight:Int = 0
    var indexFingerPosition: SIMD3<Float> = [0,0,0]
    private var faceAnchor: AnchorEntity?

    override func viewDidLoad() {
        super.viewDidLoad()
        arView = ARView(frame: view.bounds)
        view.addSubview(arView)
        viewWidth = Int(arView.bounds.width)
        viewHeight = Int(arView.bounds.height)

        let config = ARFaceTrackingConfiguration()
        arView.session.delegate = self
        arView.session.run(config, options: [.removeExistingAnchors])
        
        faceAnchor = AnchorEntity(.face)
        arView.scene.anchors.append(faceAnchor!)

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
            frameCounter += 1
            if frameCounter % handPosePredictionInterval == 0 {
                frameCounter = 0
                makePrediction(handPoseObservation: observation)
            }
            
            getHandPosition(handPoseObservation: observation)
        }
        
//        print(faceAnchor?.transformMatrix(relativeTo: nil))

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
        
    }
    
    func displayPeaceEffect(){
        
    }
    
    func getHandPosition(handPoseObservation: VNHumanHandPoseObservation) {
        guard let indexFingerTip = try? handPoseObservation.recognizedPoints(.all)[.indexTip],
              indexFingerTip.confidence > 0.3 else {return}
        let deNormalizedIndexPoint = VNImagePointForNormalizedPoint(CGPoint(x: indexFingerTip.location.x, y:1-indexFingerTip.location.y), viewWidth,  viewHeight)
        let oneMeterFarPlane = simd_float4x4([0,0,0,0], [0,0,0,0], [0,0,0,0], [0,0,0.01,1])
        let unProjectedPoint = arView.unproject(deNormalizedIndexPoint, ontoPlane: oneMeterFarPlane)
        print(deNormalizedIndexPoint)
        let projectPoint = arView.project([0,0,-1])
        
        print(unProjectedPoint)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
