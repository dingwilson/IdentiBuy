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

    var advertisementTimer = Timer()

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

        advertisementTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(handleAdvertisement), userInfo: nil, repeats: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()

        advertisementTimer.invalidate()
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
            performSegue(withIdentifier: "test", sender: self)
        }
    }

    @objc func handleAdvertisement() {
        if self.didLoadAdvertisement {
            self.advertisementTimer.invalidate()
            return
        }

        if latestPrediction == "iPod" {
            let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)

            let arHitTestResults : [ARHitTestResult] = sceneView.hitTest(screenCentre, types: [.featurePoint])

            if let closestResult = arHitTestResults.first {
                let transform : matrix_float4x4 = closestResult.worldTransform
                let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

                let node : SCNNode = createNewBubbleParentNode("T-Mobile Advertisement")
                sceneView.scene.rootNode.addChildNode(node)
                node.position = worldCoord
            }
            
            self.didLoadAdvertisement = true
            self.advertisementTimer.invalidate()
        }
    }

    func createNewBubbleParentNode(_ text : String) -> SCNNode {
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y

        var bubble: SCNText!

        bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))

        var font = UIFont(name: "Futura", size: 0.15)
        font = font?.withTraits(traits: .traitBold)
        bubble.font = font
        bubble.alignmentMode = kCAAlignmentCenter
        bubble.firstMaterial?.diffuse.contents = UIColor.blue
        bubble.firstMaterial?.specular.contents = UIColor.white
        bubble.firstMaterial?.isDoubleSided = true
        bubble.chamferRadius = CGFloat(bubbleDepth)

        let (minBound, maxBound) = bubble.boundingBox
        let bubbleNode = SCNNode(geometry: bubble)
        bubbleNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2)
        bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)

        let sphere = SCNSphere(radius: 0.005)
        sphere.firstMaterial?.diffuse.contents = UIColor.cyan
        let sphereNode = SCNNode(geometry: sphere)

        let bubbleNodeParent = SCNNode()
        bubbleNodeParent.addChildNode(bubbleNode)
        bubbleNodeParent.addChildNode(sphereNode)
        bubbleNodeParent.constraints = [billboardConstraint]

        return bubbleNodeParent
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
