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
    var date: Date!
    var count: Int32!

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
        
        count = 0

        // Set up ARWorldTrackingConfiguration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth] // Use smoothedSceneDepth for better depth data
        configuration.sceneReconstruction = .mesh
        arView.session.run(configuration)
        print("Yurrrr")
    
        date = Date()
    }
    

    
    // ARSCNViewDelegate methods to handle LiDAR data
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let frame = arView.session.currentFrame else { return }

        // Accessing the raw feature points from LiDAR
        guard let rawFeaturePoints = frame.rawFeaturePoints else { return }

        //Camera position
        let cameraTransform = frame.camera.transform
        let cameraPosition = extractPosition(from: cameraTransform)
        print("here")
        print(cameraPosition)
        print("here")
        // Define your reference point here
        // For example, this could be the camera's current position
        let referencePoint = SCNVector3(
            frame.camera.transform.columns.3.x,
            frame.camera.transform.columns.3.y,
            frame.camera.transform.columns.3.z
        )

        var new_points: [SIMD3<Float>] = []
        for point in rawFeaturePoints.points {
            let scnPoint = SCNVector3(point)
            let distance = distanceBetween(scnPoint, and: referencePoint)
            if distance > 0.2 {
                new_points.append(SIMD3<Float>(point))
            }
        }
//        for point in points {
//            let scnPoint = SCNVector3(point)
//            let distance = distanceBetween(scnPoint, and: referencePoint)
//            if distance < minimumDistance {
//                minimumDistance = distance
//                closestPoint = scnPoint
//            }
//        }

        
        // Find the closest point
//        if let closestPoint = findClosestPoint(to: referencePoint, in: rawFeaturePoints.points) {
        if let closestPoint = findClosestPoint(to: referencePoint, in: new_points) {
            // Do something with the closest point
            // For example, you could update a visual indicator in your AR scene
        }
        
//        displayPointCloud(rawFeaturePoints.points)
        displayPointCloud(new_points)

    }
    
    func extractPosition(from transform: matrix_float4x4) -> (x: Float, y: Float, z: Float) {
        let x = transform.columns.3.x
        let y = transform.columns.3.y
        let z = transform.columns.3.z
        return (x, y, z)
    }
    
    func displayPointCloud(_ points: [SIMD3<Float>]?) {
        let new_date = Date()
        print("Time diff: " + String(new_date.timeIntervalSinceReferenceDate - date.timeIntervalSinceReferenceDate))
        print("Time: " + String(new_date.timeIntervalSinceReferenceDate))
        print("Count: " + String(count))
        date = new_date
        count += 1

        guard let points = points else { return }
        
        let pointCloudNode = SCNNode()
        
        for point in points {
            let sphere = SCNSphere(radius: 0.001) // adjust radius as needed
            sphere.firstMaterial?.diffuse.contents = UIColor.red // adjust color as needed
            let pointNode = SCNNode(geometry: sphere)
            pointNode.position = SCNVector3(point)
            pointCloudNode.addChildNode(pointNode)
        }
        
        pointCloudNode.name = String(new_date.timeIntervalSinceReferenceDate)
        
        DispatchQueue.main.async {
            var to_remove: Int = self.arView.scene.rootNode.childNodes.count - 100
            print("To remove: " + String(to_remove))
            self.arView.scene.rootNode.enumerateChildNodes { (node, stop) in
                if to_remove > 0 {
                    node.removeFromParentNode()
                    to_remove -= 1
                }
            }

            print("Num child nodes left: " + String(self.arView.scene.rootNode.childNodes.count))

//            var minimum = Float.greatestFiniteMagnitude
//            self.arView.scene.rootNode.enumerateChildNodes { (node, stop) in
//                node.removeFromParentNode()
//                let a: Float? = Float(pointCloudNode.name!)
//                if a! < minimum{
//                    minimum = a!
//                }
//            }
//
//            print("Min time: " + String(minimum))
            self.arView.scene.rootNode.addChildNode(pointCloudNode)
        }
    }


    func findClosestPoint(to referencePoint: SCNVector3, in points: [vector_float3]) -> SCNVector3? {
        guard !points.isEmpty else { return nil }

        var closestPoint: SCNVector3?
        var minimumDistance = Float.greatestFiniteMagnitude

        for point in points {
            let scnPoint = SCNVector3(point)
            let distance = distanceBetween(scnPoint, and: referencePoint)
            if distance < minimumDistance {
                minimumDistance = distance
                closestPoint = scnPoint
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
