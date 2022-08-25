//
//  FrequencyService.swift
//  PitchTap
//
//  Created by Maximilian Maksutovic on 7/4/22.
//

import Foundation
import AudioKit
import AudioKitEX
import SoundpipeAudioKit
import Combine

enum FrequencyServiceState {
    case notListening
    case listening
}

class FrequencyService {
    private var frequencySubscription: AnyCancellable?
    static let shared = FrequencyService()
    private let audio = AudioManager.shared
    var state: FrequencyServiceState = .notListening
    var pitchBuffer: [Float] = []
    
    let lowerBound: Float = 0.975
    let upperBound: Float = 1.025
    
    
    
    func listenForFrequency(frequnecyToCheck: Float) {
        state = .listening
        print("Need Frequency:\(frequnecyToCheck)")
        frequencySubscription = audio.pitchTapSubject
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: {[weak self] data in
                guard let self = self else { return }
                if self.state == .listening {
                    print("Pitch:\(data.pitch) | Needed:\(frequnecyToCheck)")
                    self.pitchBuffer.append(data.pitch)
                    if self.pitchBuffer.count >= 3 {
                        self.state = .notListening
                        if let outliersRemoved = self.pitchBuffer.removeOutliers(targetFrequency: frequnecyToCheck) {
                            let toCheck = outliersRemoved.mean
                            self.processFrequency(toCheck: toCheck, needed: frequnecyToCheck, autoFail: false)
                        } else {
                            self.processFrequency(toCheck: 0.0, needed: 0.0, autoFail: true)
                        }

                    }
                }
            })
    }
    
    func processFrequency(toCheck: Float, needed: Float, autoFail: Bool) {
        if autoFail {
            print("AutoFail")
        } else {
            let passed = checkRealNote(checked: toCheck, needed: needed)
        }
        pitchBuffer.removeAll()
    }
    
    func checkRealNote(checked: Float, needed: Float) -> Bool {
        let neededLB = needed * lowerBound
        let neededUB = needed * upperBound
        
        if checked >= neededLB && checked <= neededUB {
            print("We passed!\nChecked:\(checked) | LB:\(neededLB) | UB:\(neededUB) | real:\(needed)")
            return true
        } else {
            print("Boo did not pass:\(checked)")
            return false
        }
    }
}
