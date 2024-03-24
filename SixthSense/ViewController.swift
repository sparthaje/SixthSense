//
//  ViewController.swift
//  SixthSense
//
//  Created by Srikar Gouru on 3/23/24.
//

import SwiftUI
import Foundation
import UIKit
import ARKit
import simd

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
    var reset_date: Date = Date()
    var cloud_num: Int = 0
    let colors = [UIColor.red, UIColor.green, UIColor.orange, UIColor.blue, UIColor.purple, UIColor.cyan]
    var configuration: ARWorldTrackingConfiguration? = nil;
    var options: ARSession.RunOptions? = nil;
    var nearestPointDetector = NearestPointDetector()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up ARSCNView
        arView = ARSCNView(frame: view.bounds)
        view.addSubview(arView)
        arView.delegate = self
        
        // Set up SpatialAudioManager
        spatialAudioManager = SpatialAudioManager()
        
        // Check if LiDAR is available
        //        spatialAudioManager.playSound(from: <#T##SCNVector3#>, with: <#T##URL#>);
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) else {
            print("LiDAR not available on this device")
            return
        }
        
        print("LiDAR is available on this device")
        
        // Set up ARWorldTrackingConfiguration
        configuration = ARWorldTrackingConfiguration()
        //        configuration!.planeDetection = [.vertical]  // removed .horizontal
        configuration!.environmentTexturing = .automatic
        configuration!.frameSemantics = [.sceneDepth, .smoothedSceneDepth] // Use smoothedSceneDepth for better depth data
        //        configuration.frameSemantics.insert(.sceneDepth)
        options = [.resetTracking, .removeExistingAnchors]
        configuration!.sceneReconstruction = .meshWithClassification
        arView.session.run(configuration!, options: options!)
        print("Yurrrr")
    }
        
    // ARSCNViewDelegate methods to handle LiDAR data
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let frame = arView.session.currentFrame else { return }
        
        arView.session.getCurrentWorldMap { world_map, e in
            guard let featurePoints = world_map?.rawFeaturePoints else {return}

            let referencePoint = SCNVector3(
                frame.camera.transform.columns.3.x,
                frame.camera.transform.columns.3.y,
                frame.camera.transform.columns.3.z
            )
            let yaw = frame.camera.eulerAngles.y
            
            let new_points: [SIMD3<Double>] = self.filter_points(pcl: featurePoints.points, referencePoint: referencePoint, yaw: yaw)

            guard let nearest_points = self.nearestPointDetector.getNearestPoint(points: new_points, minPoints: 7, epsilon: 0.3) else
            {
                print("There's literally no nearest point bruh")
                self.displayPointCloud([new_points], referencePoint: referencePoint)
                return
            }
            print("Found n nearest points " + String(nearest_points.count))
            self.displayPointCloud([new_points, nearest_points], referencePoint: referencePoint)
               
            if Date().timeIntervalSince(self.reset_date) > 20 {
                self.arView.session.pause()
                self.arView.session.run(self.configuration!, options: self.options!)
                // reset world
                print("RESETTING SCENE MOTHER FUCKER")
                self.reset_date = Date()
            }
        };
    }
    
    func filter_points(pcl: [simd_float3], referencePoint: SCNVector3, yaw: Float) -> [SIMD3<Double>] {
        var new_points: [SIMD3<Double>] = []

        let num_original_points = pcl.count
        var num_angle_filtered_points = 0
        var num_ground_filtered_points = 0
        var minDistance = Float.greatestFiniteMagnitude
        for point in pcl {
            let scnPoint = SCNVector3(point)
            
            // Angle filter
            if (-sin(yaw) * (scnPoint.x - referencePoint.x)) + (-cos(yaw) * (scnPoint.z - referencePoint.z)) < 0 {
                continue
            }
            
            num_angle_filtered_points += 1
            
//            // Ground filtering
            if scnPoint.y <= -0.5 {
                continue
            }
            // Ceiling filtering
            if scnPoint.y >= -0.1 {
                continue
            }
            num_ground_filtered_points += 1
            
            // Distance filtering
            let distance = self.distanceBetween2D(scnPoint, and: referencePoint)
            if distance < 0.8 {
                continue
            }
            if distance > 2.0 {
                continue
            }
            if distance < minDistance {
                minDistance = distance
            }
            
            new_points.append(SIMD3<Double>(point))
        }
//        print("Num original points: " + String(num_original_points))
//        print("Num angle filtered points: " + String(num_angle_filtered_points))
//        print("Num ground filtered points: " + String(num_ground_filtered_points))
//        print("Num fully filtered points: " + String(new_points.count))
//        print("Min distance: " + String(minDistance))
        new_points.sort { (pointA, pointB) -> Bool in
            let d1 = self.distanceBetween2D(SCNVector3(
                            pointA.x,
                            pointA.y,
                            pointA.z
                        ), and: referencePoint)
            let d2 = self.distanceBetween2D(SCNVector3(
                            pointB.x,
                            pointB.y,
                            pointB.z
                        ), and: referencePoint)
            return d1 < d2;
        }
        
        return new_points;
    }

    func displayPointCloud(_ clusters: [any Sequence<SIMD3<Double>>], referencePoint: SCNVector3) {
        cloud_num += 1
                
        let pointCloudNode = SCNNode()
        let referencePointSIMD = SIMD3<Double>(referencePoint)
        
        for (i, points) in clusters.enumerated() {
            for point in points {
                var radius = 0.02
                if i == 0 {
                    radius = 0.005
                }
                let sphere = SCNSphere(radius: radius) // adjust radius as needed
                //                sphere.firstMaterial?.diffuse.contents = UIColor.red // adjust color as needed
                sphere.firstMaterial?.diffuse.contents = colors[i % colors.count] // adjust color as needed

                let pointNode = SCNNode(geometry: sphere)
                pointNode.position = SCNVector3(point)

                pointCloudNode.addChildNode(pointNode)
                
            }
        }
                
        DispatchQueue.main.async {
            self.arView.scene.rootNode.enumerateChildNodes { (node, stop) in
                node.removeFromParentNode()
            }
            
            self.arView.scene.rootNode.addChildNode(pointCloudNode)
        }
    }
    
    func distanceBetween(_ point1: SCNVector3, and point2: SCNVector3) -> Float {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        let dz = point1.z - point2.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }

    func distanceBetween2D(_ point1: SCNVector3, and point2: SCNVector3) -> Float {
        let dx = point1.x - point2.x
        let dz = point1.z - point2.z
        return sqrt(dx*dx + dz*dz)
    }

    func distanceBetween2D(_ point1: SIMD3<Float>, and point2: SIMD3<Float>) -> Float {
        let dx = point1.x - point2.x
        let dz = point1.z - point2.z
        return sqrt(dx*dx + dz*dz)
    }

    func distanceBetween2D(_ point1: SIMD3<Double>, and point2: SIMD3<Double>) -> Double {
        let dx = point1.x - point2.x
        let dz = point1.z - point2.z
        return sqrt(dx*dx + dz*dz)
    }

}

