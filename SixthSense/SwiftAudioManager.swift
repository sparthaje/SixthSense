//
//  SpatialAudioManager.swift
//  SixthSense
//
//  Created by Srikar Gouru on 3/23/24.
//

import AVFoundation

class SoundPlayer {
    var audioPlayer: AVAudioPlayer?
    func playSound(sound: String, type: String, pan: Float, distance: Float) {
        if let path = Bundle.main.path(forResource: sound, ofType: type) {
            do {
                try AVAudioSession.sharedInstance().setCategory(
                    AVAudioSession.Category.ambient
                )
                try AVAudioSession.sharedInstance().setActive(true)
                audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                audioPlayer?.pan = pan
                let vol = Float(1.2 - cos(pan) + 0.4 / (distance * distance))
                audioPlayer?.volume = vol
                audioPlayer?.play()
            } catch {
                print("ERROR: Could not find and play the sound file.")
            }
        }
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
    }
    
}
