//
//  SpatialAudioManager.swift
//  SixthSense
//
//  Created by Srikar Gouru on 3/23/24.
//

import Foundation
import AVFoundation
import SceneKit

class SpatialAudioManager {
    private var audioEngine: AVAudioEngine
    private var audioPlayerNode: AVAudioPlayerNode
    private var audioEnvironmentNode: AVAudioEnvironmentNode

    init() {
        // Initialize the audio engine and nodes
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        audioEnvironmentNode = AVAudioEnvironmentNode()

        // Attach and connect nodes
        audioEngine.attach(audioPlayerNode)
        audioEngine.attach(audioEnvironmentNode)
        audioEngine.connect(audioPlayerNode, to: audioEnvironmentNode, format: nil)
        audioEngine.connect(audioEnvironmentNode, to: audioEngine.outputNode, format: nil)
    }

    func playSound(from position: SCNVector3, with audioFile: URL) {
        do {
            // Load the audio file
            let audioFile = try AVAudioFile(forReading: audioFile)

            // Configure the position of the audio in 3D space
            let audioPosition = AVAudio3DPoint(x: position.x, y: position.y, z: position.z)
            audioPlayerNode.position = audioPosition

            // Start the audio engine if it's not already running
            if !audioEngine.isRunning {
                try audioEngine.start()
            }

            // Schedule and play the audio file
            audioPlayerNode.scheduleFile(audioFile, at: nil, completionHandler: nil)
            audioPlayerNode.play()
        } catch {
            print("Error setting up audio: \(error)")
        }
    }
}
