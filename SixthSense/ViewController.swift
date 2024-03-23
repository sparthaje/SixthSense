//
//  ViewController.swift
//  SixthSense
//
//  Created by Arushi Shah on 3/23/24.
//

import SwiftUI
import Foundation
import UIKit
import ARKit

struct ViewContainer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ViewController {
        let viewController = ViewController()
        return viewController
    }

    func updateUIViewController(_ uiViewController: ViewController, context: Context) {}
}


class ViewController: UIViewController, ARSCNViewDelegate {

    var arView: ARSCNView!
    var spatialAudioManager: SpatialAudioManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Chat stuff
//        sceneView.delegate = self
//        sceneView.showsStatistics = true
//        let scene = SCNScene()
//        sceneView.scene = scene

        // Set up ARSCNView
        arView = ARSCNView(frame: view.bounds)
        view.addSubview(arView)
        arView.delegate = self
        
        // Set up SpatialAudioManager
        spatialAudioManager = SpatialAudioManager()

        // Check if LiDAR is available
//        spatialAudioManager.playSound(from: <#T##SCNVector3#>, with: <#T##URL#>);
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            print("LiDAR not available on this device")
            return
        }
        print("LiDAR is available on this device")

        // Set up ARWorldTrackingConfiguration
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        arView.session.run(configuration)
        print("Yurrrr")
        
    }

    
    // ARSCNViewDelegate methods to handle LiDAR data
//    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
//        // Process LiDAR data here
//        // ...
//    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let frame = arView.session.currentFrame else { return }

        // Accessing the raw feature points from LiDAR
        guard let rawFeaturePoints = frame.rawFeaturePoints else { return }

        // Define your reference point here
        // For example, this could be the camera's current position
        let referencePoint = SCNVector3(
            frame.camera.transform.columns.3.x,
            frame.camera.transform.columns.3.y,
            frame.camera.transform.columns.3.z
        )

        // Find the closest point
        if let closestPoint = findClosestPoint(to: referencePoint, in: rawFeaturePoints.points) {
            // Do something with the closest point
            // For example, you could update a visual indicator in your AR scene
        }
        
        displayPointCloud(rawFeaturePoints.points)

    }
    
    func displayPointCloud(_ points: [SIMD3<Float>]?) {
        guard let points = points else { return }
        
        let pointCloudNode = SCNNode()
        
        for point in points {
            let sphere = SCNSphere(radius: 0.001) // adjust radius as needed
            sphere.firstMaterial?.diffuse.contents = UIColor.red // adjust color as needed
            let pointNode = SCNNode(geometry: sphere)
            pointNode.position = SCNVector3(point)
            pointCloudNode.addChildNode(pointNode)
        }
        
        DispatchQueue.main.async {
            self.arView.scene.rootNode.addChildNode(pointCloudNode)
        }
    }


    func findClosestPoint(to referencePoint: SCNVector3, in points: [vector_float3]) -> SCNVector3? {
        guard !points.isEmpty else { return nil }

        var closestPoint: SCNVector3?
        var closestRawPoint: float3?
        var minimumDistance = Float.greatestFiniteMagnitude

        for point in points {
            let scnPoint = SCNVector3(point)
            let distance = distanceBetween(scnPoint, and: referencePoint)
            if distance < minimumDistance {
                minimumDistance = distance
                closestPoint = scnPoint
                closestRawPoint = point
            }
        }
        
        print("Num points: " + String(points.count))
        print("Minimum distance: " + String(minimumDistance))
        print(referencePoint)
        print(closestPoint)


        return closestPoint
    }

    func distanceBetween(_ point1: SCNVector3, and point2: SCNVector3) -> Float {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        let dz = point1.z - point2.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
}
