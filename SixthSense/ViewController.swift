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
import GoogleGenerativeAI
import AVFoundation

struct ViewContainer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ViewController {
        let viewController = ViewController()
        return viewController
    }

    func updateUIViewController(_ uiViewController: ViewController, context: Context) {}
}

class ViewController: UIViewController, ARSCNViewDelegate {
    var arView: ARSCNView!
    var reset_date: Date = Date()
    var last_ping_date: Date = Date()
    var cloud_num: Int = 0
    let colors = [UIColor.red, UIColor.green, UIColor.orange, UIColor.blue, UIColor.purple, UIColor.cyan]
    var configuration: ARWorldTrackingConfiguration? = nil;
    var options: ARSession.RunOptions? = nil;
    var nearestPointDetector = NearestPointDetector()

    var previousFrame: ARFrame?
    let model = GenerativeModel(name: "gemini-pro-vision", apiKey: "AIzaSyATZ4h33XqCyMN3yj50vvXupQLAsXD2wIk")
    let speechSynthesizer = AVSpeechSynthesizer()
    let soundPlayer = SoundPlayer()
    var givingContext = false
    var toggleSpatialAudio = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up ARSCNView
        arView = ARSCNView(frame: view.bounds)
        view.addSubview(arView)
        arView.delegate = self
        
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
        
        let screenRect = UIScreen.main.bounds
        let buttonHeight = screenRect.height / 2

        // Create a new button
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: screenRect.width, height: buttonHeight))
        button.backgroundColor = .black
        button.setTitle("General Context", for: .normal)
        button.addTarget(self, action: #selector(topButtonTapped), for: .touchUpInside)
        view.addSubview(button)

        // Create a new button
        let button2 = UIButton(frame: CGRect(x: 0, y: buttonHeight, width: screenRect.width, height: buttonHeight))
        button2.backgroundColor = .black
        button2.setTitle("Key Objects", for: .normal)
        button2.addTarget(self, action: #selector(bottomButtonTapped), for: .touchUpInside)
        view.addSubview(button2)

        let dividerHeight: CGFloat = 2  // You can adjust the thickness of the divider here
            let divider = UIView(frame: CGRect(x: 0, y: buttonHeight - dividerHeight / 2, width: screenRect.width, height: dividerHeight))
            divider.backgroundColor = .white
            view.addSubview(divider)
    }
    
    @objc func bottomButtonTapped() {
        print("Clicked bottom button")
        // Perform your desired action here
        if (previousFrame != nil) {
            let buffer = previousFrame!.capturedImage;
            let img = UIImage(ciImage: CIImage(cvPixelBuffer: buffer));
            givingContext = true
            let speechUtterance = AVSpeechUtterance(string: "Stop!")
            speechUtterance.voice = AVSpeechSynthesisVoice(language: "en-US") // Set the language
            speechSynthesizer.speak(speechUtterance)

            let prompt = "What is the closest key object in the field of view: people, chair, door, and table. Also provide its relative location in the frame (left, center, rigth). Limit response to only 1 sentence."
            givingContext = true
            Task {
                let result = await call_gemini(model: model, img: img, prompt: prompt)!
                print("API Response: \(result ?? "No output")")
                let speechUtterance = AVSpeechUtterance(string: result)
                speechUtterance.voice = AVSpeechSynthesisVoice(language: "en-US") // Set the language
                speechSynthesizer.speak(speechUtterance)
            }
            givingContext = false
            previousFrame = nil;
        }
    }
    @objc func topButtonTapped() {
        print("Clicked top button")
        // Perform your desired action here
        if (previousFrame != nil) {
            let buffer = previousFrame!.capturedImage;
            let img = UIImage(ciImage: CIImage(cvPixelBuffer: buffer));
            let prompt = "Given the following field of vision, contextualize the environment and provide what the environment could be (living room, classroom, conference room, kitchen, hallway). Keep responses short and within 2 sentences."
            givingContext = true
            Task {
                let result = await call_gemini(model: model, img: img, prompt: prompt)!
                print("API Response: \(result ?? "No output")")
                //givingContext = true
                let speechUtterance = AVSpeechUtterance(string: result)
                speechUtterance.voice = AVSpeechSynthesisVoice(language: "en-US") // Set the language
                speechSynthesizer.speak(speechUtterance)
            }
            givingContext = false
            previousFrame = nil;
        }
    }
    
    func call_gemini(model: GenerativeModel, img: UIImage?, prompt: String) async -> String? {
        do {
            let response = try await model.generateContent(prompt, img!);
            return response.text
        } catch {
            print("Error: (error)")
        }
        return "No output"
    }

    func playPing(angle : Double, depth : Double) {
        if !givingContext {
            let pan = -2 * angle / Double.pi  //cos(given_angle + Double.pi / 2)
            soundPlayer.playSound(sound: "biwo", type: "m4a", pan: Float(pan), distance: Float(depth))
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    // ARSCNViewDelegate methods to handle LiDAR data
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let frame = arView.session.currentFrame else { return }
        previousFrame = frame;
        
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
//                self.displayPointCloud([new_points], referencePoint: referencePoint)
                return
            }
//            print("Found n nearest points " + String(nearest_points.count))
//            self.displayPointCloud([new_points, nearest_points], referencePoint: referencePoint)

//            if self.cloud_num % 100 == 0 {
            var num_points = 0.0
            var avg_x = 0.0
            var avg_z = 0.0
            for point in nearest_points {
                avg_x += point.x - Double(referencePoint.x)
                avg_z += point.z - Double(referencePoint.z)
                num_points += 1.0
            }
            avg_x /= num_points
            avg_z /= num_points
            let magnitude = sqrt(avg_x * avg_x + avg_z * avg_z)
            let avg_point_angle = atan2(-avg_z, avg_x)
            var ping_angle = avg_point_angle - Double(yaw)
            ping_angle = atan2(sin(ping_angle), cos(ping_angle))
            
            let ping_frequency = 1.5
            if Date().timeIntervalSince(self.last_ping_date) > ping_frequency {
                self.playPing(angle: Double(ping_angle), depth: magnitude)
                self.last_ping_date = Date()
            }

            if Date().timeIntervalSince(self.reset_date) > 20 {
                self.arView.session.pause()
                self.arView.session.run(self.configuration!, options: self.options!)
                // reset world
                print("RESETTING SCENE")
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

