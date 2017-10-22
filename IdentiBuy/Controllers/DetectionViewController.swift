//
//  DetectionViewController.swift
//  IdentiBuy
//
//  Created by Wilson Ding on 10/22/17.
//  Copyright © 2017 Wilson Ding. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class DetectionViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    let bubbleDepth : Float = 0.01
    var latestPrediction : String = "…"

    var visionRequests = [VNRequest]()
    let dispatchQueueML = DispatchQueue(label: "com.wilsonding.dispatchQueue")

    var didLoadAdvertisement = false

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self

        let scene = SCNScene()

        sceneView.scene = scene

        sceneView.autoenablesDefaultLighting = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)

        guard let selectedModel = try? VNCoreMLModel(for: Inceptionv3().model) else {
            fatalError("Could not load model. Ensure model has been drag and dropped (copied) to XCode Project from https://developer.apple.com/machine-learning/ . Also ensure the model is part of a target (see: https://stackoverflow.com/questions/45884085/model-is-not-part-of-any-target-add-the-model-to-a-target-to-enable-generation ")
        }

        let classificationRequest = VNCoreMLRequest(model: selectedModel, completionHandler: classificationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
        visionRequests = [classificationRequest]

        loopCoreMLUpdate()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal

        sceneView.session.run(configuration)

        didLoadAdvertisement = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            // Do any desired updates to SceneKit here.
        }
    }

    override var prefersStatusBarHidden : Bool {
        return true
    }

    @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
        let arHitTestResults : [SCNHitTestResult] = sceneView.hitTest(gestureRecognize.location(in: sceneView), options: nil)

        if arHitTestResults.count > 0 {
            performSegue(withIdentifier: "didHitAdvertisement", sender: nil)
        }
    }

    func handleAdvertisement() {
        let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)

        let arHitTestResults : [ARHitTestResult] = sceneView.hitTest(screenCentre, types: [.featurePoint])

        if let closestResult = arHitTestResults.first {
            let transform : matrix_float4x4 = closestResult.worldTransform
            let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

            let node : SCNNode = createAdvertisement()
            sceneView.scene.rootNode.addChildNode(node)
            node.position = worldCoord

            self.didLoadAdvertisement = true
        }
    }

    func createAdvertisement() -> SCNNode {
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y

        let imagePlane = SCNPlane(width: 0.5, height: 0.25)
        imagePlane.firstMaterial?.diffuse.contents = UIImage(named: "Advertisement")
        imagePlane.firstMaterial?.lightingModel = .constant
        let advertisementNode = SCNNode(geometry: imagePlane)

        let advertisementNodeParent = SCNNode()
        advertisementNodeParent.addChildNode(advertisementNode)
        advertisementNodeParent.constraints = [billboardConstraint]

        return advertisementNodeParent
    }

    func loopCoreMLUpdate() {
        dispatchQueueML.async {
            self.updateCoreML()

            self.loopCoreMLUpdate()
        }

    }

    func classificationCompleteHandler(request: VNRequest, error: Error?) {
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }

        guard let observations = request.results else {
            print("No results")
            return
        }

        let classifications = observations[0...1] // top 2 results
            .flatMap({ $0 as? VNClassificationObservation })
            .map({ "\($0.identifier) \(String(format:"- %.2f", $0.confidence))" })
            .joined(separator: "\n")


        DispatchQueue.main.async {
            print(classifications)
            print("--")

            var objectName:String = "…"
            objectName = classifications.components(separatedBy: "-")[0]
            objectName = objectName.components(separatedBy: ",")[0]
            self.latestPrediction = objectName.replacingOccurrences(of: " ", with: "")

            if !self.didLoadAdvertisement {
                if self.latestPrediction == "iPod" {
                    self.handleAdvertisement()
                }
            }
        }
    }

    func updateCoreML() {
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
    }
}

extension UIFont {
    func withTraits(traits:UIFontDescriptorSymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
}
