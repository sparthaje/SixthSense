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

struct PointWithCloudNumber {
    var cloud_num: Int
    var point: SIMD3<Float>
}

class ViewController: UIViewController, ARSCNViewDelegate {
    var arView: ARSCNView!
    var spatialAudioManager: SpatialAudioManager!
    var date: Date!
    var cloud_num: Int = 0
    let colors = [UIColor.red, UIColor.green, UIColor.orange, UIColor.blue, UIColor.purple, UIColor.cyan]
    var main_lidar_cloud : [PointWithCloudNumber] = []
    var first_camera_pos: SCNVector3? = nil;
    var configuration: ARWorldTrackingConfiguration? = nil;
    var options: ARSession.RunOptions? = nil;
    var dbscan = DBScan()
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
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
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
        configuration!.sceneReconstruction = .mesh
        arView.session.run(configuration!, options: options!)
        print("Yurrrr")
        
        date = Date()
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
            
            // Ground filtering
            if scnPoint.y <= referencePoint.y - 1.0 {
                continue
            }
            // Ceiling filtering
            if scnPoint.y >= referencePoint.y + 0.5 {
                continue
            }
            num_ground_filtered_points += 1
            
            // Distance filtering
            let distance = self.distanceBetween2D(scnPoint, and: referencePoint)
            if distance < 0.5 {
                continue
            }
            if distance > 2 {
                continue
            }
            
            if distance < minDistance {
                minDistance = distance
            }
            
            new_points.append(SIMD3<Double>(point))
        }
        print("Num original points: " + String(num_original_points))
        print("Num angle filtered points: " + String(num_angle_filtered_points))
        print("Num ground filtered points: " + String(num_ground_filtered_points))
        print("Num fully filtered points: " + String(new_points.count))
        print("Min distance: " + String(minDistance))
        //            let clusters = clusterPoints(points: new_points, minPoints: 5, epsilon: 0.1)
        //            let clusters = self.dbscan.clusterPoints(points: new_points, minPoints: 5, epsilon: 0.1)
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
    
    // ARSCNViewDelegate methods to handle LiDAR data
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let frame = arView.session.currentFrame else { return }
        
        arView.session.getCurrentWorldMap { world_map, e in
            guard let featurePoints = world_map?.rawFeaturePoints else {return}
            
            let cameraTransform = frame.camera.transform
            let cameraPosition = self.extractPosition(from: cameraTransform)
            let referencePoint = SCNVector3(
                frame.camera.transform.columns.3.x,
                frame.camera.transform.columns.3.y,
                frame.camera.transform.columns.3.z
            )
            let yaw = frame.camera.eulerAngles.y
            
            let new_points: [SIMD3<Double>] = self.filter_points(pcl: featurePoints.points, referencePoint: referencePoint, yaw: yaw)

            guard let nearest_points = self.nearestPointDetector.getNearestPoint(points: new_points, minPoints: 5, epsilon: 0.3) else
            {
                print("There's literally no nearest point bruh")
                return
            }
            self.displayPointCloud([new_points, nearest_points])

//            if new_points.count > 20 {
//                let firstHalf = Array(new_points[..<20])
////                let clusters = [new_points, firstHalf]
//                let clusters = self.dbscan.clusterPoints(points: new_points, minPoints: 10, epsilon: 1)
//                //            self.displayPointCloud(new_points)
//                print("Num clusters: " + String(clusters.count))
//                for (i, cluster) in clusters.enumerated() {
//                    print("Cluster " + String(i) + ": " + String(cluster.count))
//                }
//                self.displayPointCloud(clusters)
//            } else {
//                print("less than 20 LLL")
//            }
                
            if (featurePoints.points.count > 5000) {
                self.arView.session.pause()
                self.arView.session.run(self.configuration!, options: self.options!)
                // reset world
                print("RESETTING SCENE MOTHER FUCKER")
            }
        };
        
        //            let cameraTransform = frame.camera.transform
        //            let cameraPosition = extractPosition(from: cameraTransform)
        //            let referencePoint = SCNVector3(
        //                frame.camera.transform.columns.3.x,
        //                frame.camera.transform.columns.3.y,
        //                frame.camera.transform.columns.3.z
        //            )
        
        // Accessing the raw feature points from LiDAR
        //        guard let rawFeaturePoints = frame.rawFeaturePoints else { return }
        
        //Camera position
        
        // Define your reference point here
        // For example, this could be the camera's current position
        
        
        //        var new_points = rawFeaturePoints.points
        
        //        var new_points: [SIMD3<Float>] = []
        //        for point in rawFeaturePoints.points {
        //            let scnPoint = SCNVector3(point)
        //            let distance = distanceBetween(scnPoint, and: referencePoint)
        //            if distance > 1.5 {
        //                new_points.append(SIMD3<Float>(point))
        //            }
        //        }
        
        // Find the closest point
        //        if let closestPoint = findClosestPoint(to: referencePoint, in: rawFeaturePoints.points) {
        //        let (closestP, minimumDistance) = findClosestPoint(to: referencePoint, in: new_points)
        //        if closestP != nil {
        //            // Do something with the closest point
        //            // For example, you could update a visual indicator in your AR scene
        //            print("you are " + String(minimumDistance) + "away from the closest object")
        //
        //        }
        
        // Prepare for point cloud conversion
        
        //        displayPointCloud(new_points)
        //        let even_newer_points = clusterPoints(points: new_points, minPoints: 10, epsilon: 0.2)
        //        displayPointCloud(even_newer_points)
    }
    
    func extractPosition(from transform: matrix_float4x4) -> (x: Float, y: Float, z: Float) {
        let x = transform.columns.3.x
        let y = transform.columns.3.y
        let z = transform.columns.3.z
        return (x, y, z)
    }
    
    func displayPointCloud(_ clusters: [any Sequence<SIMD3<Double>>]) {
        //        print("Num clusters: " + String(clusters.count))
        let new_date = Date()
        //        print("Time diff: " + String(new_date.timeIntervalSinceReferenceDate - date.timeIntervalSinceReferenceDate))
        //        print("Time: " + String(new_date.timeIntervalSinceReferenceDate))
        //        print("Cloud num: " + String(cloud_num))
        date = new_date
        cloud_num += 1
                
        let pointCloudNode = SCNNode()
        
        for (i, points) in clusters.enumerated() {
            for point in points {
                let scaler = CGFloat(2*i + 1)
                let sphere = SCNSphere(radius: 0.005 * scaler) // adjust radius as needed
                //                sphere.firstMaterial?.diffuse.contents = UIColor.red // adjust color as needed
                sphere.firstMaterial?.diffuse.contents = colors[i % colors.count] // adjust color as needed
                let pointNode = SCNNode(geometry: sphere)
                //                pointNode.position = SCNVector3(point.point)
                pointNode.position = SCNVector3(point)
                pointCloudNode.addChildNode(pointNode)
                
            }
        }
        
        pointCloudNode.name = String(new_date.timeIntervalSinceReferenceDate)
        
        DispatchQueue.main.async {
            self.arView.scene.rootNode.enumerateChildNodes { (node, stop) in
                node.removeFromParentNode()
            }
            
            self.arView.scene.rootNode.addChildNode(pointCloudNode)
        }
    }
    
    
//    func findClosestPoint(to referencePoint: SCNVector3, in points: [vector_float3]) -> (SCNVector3?, Float) {
//        guard !points.isEmpty else { return (nil,Float.greatestFiniteMagnitude) }
//        
//        var closestPoint: SCNVector3?
//        var minimumDistance = Float.greatestFiniteMagnitude
//        
//        for point in points {
//            let scnPoint = SCNVector3(point)
//            let distance = distanceBetween(scnPoint, and: referencePoint)
//            if distance < minimumDistance {
//                minimumDistance = distance
//                closestPoint = scnPoint
//            }
//        }
//        
//        print("Num points: " + String(points.count))
//        //        print("Minimum distance: " + String(minimumDistance))
//        //        print(referencePoint)
//        //        print(closestPoint)
//        
//        return (closestPoint, minimumDistance)
//    }
    
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

}

