//
//  AudioManager.swift
//  PitchTap
//
//  Created by Maximilian Maksutovic on 6/4/22.
//

import Foundation
import AudioKit
import AudioKitEX
import SoundpipeAudioKit
import AudioToolbox
import Accelerate
import Combine
import AVFoundation

struct PitchData {
    public var pitch: Float = 0.0
    public var amplitude: Float = 0.0
}

class AudioManager {
    var data = PitchData()
    
    static let shared = AudioManager()
    let engine = AudioEngine()
    let initalDevice: Device
    
    var tracker: PitchTap!
    let mic: AudioEngine.InputNode
    let silence: Fader
    
    var pitchClosure: ((PitchData) -> Void)?
    
    var pitchTapSubject = PassthroughSubject<PitchData, Never>()
    
    var piano: AppleSampler
    var metroSampler: AppleSampler
    var metroSequencer: Sequencer
    var callbackInst: CallbackInstrument = CallbackInstrument()
    
    let noteFrequencies: [Float] = [16.35, 17.32, 18.35, 19.45, 20.60,
                           21.83, 23.12, 24.50, 25.96, 27.50,
                           29.14, 30.87]
    
    let octaveFourFrequencies: [Float] = [
        261.63, 277.18, 293.66, 311.13, 329.63, 349.23, 369.99, 392.00, 415.30, 440.00, 466.16, 493.88
    ]
    
    let noteNamesWithSharps = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    let noteNamesWithFlats = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]
    
    init() {
        guard let input = engine.input else { fatalError() }
        guard let device = engine.inputDevice else { fatalError() }
        
        initalDevice = device
        
        mic = input
        silence = Fader(mic, gain: 0)
        
        piano = AppleSampler()
        metroSampler = AppleSampler()
        
        metroSequencer = Sequencer()
        metroSequencer.addTrack(for: metroSampler)
        
        callbackInst = CallbackInstrument(midiCallback: {(status, beat, _) in
            print("status:\(status) Beat: \(beat)")
        })
        
        metroSequencer.addTrack(for: callbackInst)
        
        let mixer = Mixer([silence, piano, metroSampler, callbackInst])
        engine.output = mixer
        
        tracker = PitchTap(mic) { [weak self] pitch, amp in
            if amp.mean >= 0.3 {
                let pitchAvg = pitch.mean
                let ampAvg = amp.mean
                let data = PitchData(pitch: pitchAvg, amplitude: ampAvg)
                self?.pitchTapSubject.send(data)
            }
        }
    }
    
    func start() {
        do {
            try engine.start()
            loadSounds()
        } catch let err {
            print(err)
        }
    }
    func stop() {
        engine.stop()
    }
    
    func startTracker() {
        tracker.start()
    }
    
    func sleep() {
        DispatchQueue.main.async {
            print("Halting signal chain while interrupted")
            self.metroSequencer.stop()
            self.mic.stop()
            self.silence.stop()
            self.tracker.stop()
            self.callbackInst.stop()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                do {
                    try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
    
    func wake() {
        DispatchQueue.main.async {
            print("Starting signal chain after interruption")
            do {
                do {
                    Settings.bufferLength = .short
                    try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(Settings.bufferLength.duration)
                    try AVAudioSession.sharedInstance().setCategory(.playAndRecord,
                                                                    options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothA2DP, .allowAirPlay, .allowBluetooth])
                    try AVAudioSession.sharedInstance().setActive(true)
                    self.mic.start()
                    self.silence.start()
                    self.tracker.start()
                    self.callbackInst.start()
                } catch let err {
                    print(err)
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    func getRandomFrequency() -> Float {
        guard let random = octaveFourFrequencies.randomElement() else { return -69.69 }
        return random
    }
    
    func loadSounds() {
        let filename = "musescore-piano.sf2"
        let folderName = "Sounds"
        do {
            try piano.loadSoundFont("musescore-piano", preset: 1, bank: 0)
            guard let url = Bundle.main.resourceURL?.appendingPathComponent("clave.wav") else { print("Can't load clave")
                return
            }
            let audioFile = try AVAudioFile(forReading: url)
            try metroSampler.loadAudioFile(audioFile)
            
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func playNote() {
        piano.play(noteNumber: 60, velocity: 127, channel: 0)
    }
    
    public func playClave() {
        metroSampler.play(noteNumber: 47, velocity: 120, channel: 0)
    }
    
    public func startSequencer() {
        let bpm = 120
        let beats = 40
        let tsNum = 4
        metroSequencer.clear()
        metroSequencer.tempo = BPM(bpm)
        metroSequencer.loopEnabled = false
        metroSequencer.length = Double(beats)
        
//        callbackData = CallbackData(tsNum: tsNum, hasPickup: hasPickup)

        guard let metroTrack = metroSequencer.tracks.first else { fatalError() }
        guard let callbackTrack = metroSequencer.tracks.last else { fatalError() }
        metroTrack.length = Double(beats)
        metroTrack.clear()
        
        callbackTrack.length = Double(beats)
        callbackTrack.clear()
        
        for i in 0 ..< beats {
            if i == 0 {
                metroTrack.sequence.add(noteNumber: MIDINoteNumber(47), velocity: 120, channel: 0, position: Double(i), duration: 1.0)
                callbackTrack.sequence.add(noteNumber: MIDINoteNumber(47), velocity: 120, channel: 0, position: Double(i), duration: 1.0)
            } else if i % tsNum == 0 {
                metroTrack.sequence.add(noteNumber: MIDINoteNumber(47), velocity: 120, channel: 0, position: Double(i), duration: 1.0)
                callbackTrack.sequence.add(noteNumber: MIDINoteNumber(47), velocity: 120, channel: 0, position: Double(i), duration: 1.0)
            } else {
                metroTrack.sequence.add(noteNumber: MIDINoteNumber(40), velocity: 90, channel: 0, position: Double(i), duration: 1.0)
                callbackTrack.sequence.add(noteNumber: MIDINoteNumber(40), velocity: 90, channel: 0, position: Double(i), duration: 1.0)
            }
        }
        
        metroSequencer.playFromStart()
    }
}

extension Array where Element: FloatingPoint {

    func sum() -> Element {
        return self.reduce(0, +)
    }

    func avg() -> Element {
        return self.sum() / Element(self.count)
    }

    func std() -> Element {
        let mean = self.avg()
        let v = self.reduce(0, { $0 + ($1-mean)*($1-mean) })
        return sqrt(v / (Element(self.count) - 1))
    }
}

extension Array where Element == Double {
    var mean: Double {
        return vDSP.mean(self)
    }
}

extension Array where Element == AUValue {
    
    func removeOutliers(targetFrequency: Float) -> [Float]? {
        let percent = targetFrequency * 0.025
        print("Outlier: Target Frequency:\(targetFrequency)")
        let lowerBound = targetFrequency - percent
        let upperBound = targetFrequency + percent
        
        print("LB:\(lowerBound) | UB:\(upperBound)")
        
        let sorted = self.sorted(by: <)
        
        let result = sorted.filter { ($0 >= lowerBound) && ($0 <= upperBound) }
        
        print("Before:\(sorted)")
        print("After:\(result)")
        
        if result.count == 0 {
            return nil
        } else {
            return result
        }
    }
    
    func removeOutliersWithQuartiles() -> [Float] {
        let sorted = self.sorted(by: <)
        let X = self[0..<sorted.count]
        let (q2Index1, q2Index2, Q2) = self.findMedian(X)
        let L = sorted[0..<q2Index2]
        let U = sorted[(q2Index1+1)..<sorted.count]
        let (_, _, Q1) = self.findMedian(L)
        let (_, _, Q3) = self.findMedian(U)
        
        print("Q1:\(Q1) | Q2:\(Q2) | Q3:\(Q3)")
        let interquartileRange = Q3-Q1
        
        print("IQR:\(interquartileRange)")
        
        let iqrBelowQ1 = Q1 - (1.5 * interquartileRange)
        print("IQR Below Q1:\(iqrBelowQ1)")
        let iqrAboveA3 = Q3 + (1.5 * interquartileRange)
        print("IQR Above Q3:\(iqrAboveA3)")

        let filtered = sorted.filter { $0 > iqrBelowQ1 && $0 < iqrAboveA3}
        
        print("Before:\(sorted)")
        print("After:\(filtered)")
        
        return sorted.filter { $0 > iqrBelowQ1 && $0 < iqrAboveA3}
    }
    
    func findMedian(_ sortedArraySlice: ArraySlice<Float>) -> (Int, Int, Float) {
        let data = sortedArraySlice
        let index1 = (data.count-1)/2
        let index2 = (data.count)/2
        let sliceIndex1 = index1 + data.startIndex
        let sliceIndex2 = index2 + data.startIndex
        let median = (data[sliceIndex1] + data[sliceIndex2])/2
        return (sliceIndex1, sliceIndex2, median)
    }
    
    var median: Float {
        let sorted = self.sorted(by: <)
        if self.count % 2 != 0 {
            return sorted[self.count/2]
        } else {
            return sorted[self.count/2] + sorted[self.count/2 - 1] / 2.0
        }
    }
    
    var mean: Float {
        return vDSP.mean(self)
    }
}
