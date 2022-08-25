//
//  AudioManager+Extensions.swift
//  PitchTap
//
//  Created by Maximilian Maksutovic on 8/10/22.
//

import Foundation
import AudioKit
import AudioKitEX
import SoundpipeAudioKit
import SwiftUI

struct ShakerMetronomeData {
    var isPlaying = false
    var tempo: BPM = 120
    var timeSignatureTop: Int = 4
    var downbeatNoteNumber = MIDINoteNumber(6)
    var beatNoteNumber = MIDINoteNumber(10)
    var beatNoteVelocity = 100.0
    var currentBeat = 0
}

class ShakerConductor: ObservableObject {
    let engine = AudioEngine()
    var callbackInst = CallbackInstrument()
    let osc = Oscillator()
    let reverb: Reverb
    let mixer = Mixer()
    var sequencer = Sequencer()
    
    @Published var data = ShakerMetronomeData() {
        didSet {
            data.isPlaying ? sequencer.play() : sequencer.stop()
            sequencer.tempo = data.tempo
            updateSequences()
        }
    }
    
    func updateSequences() {
        var track = sequencer.tracks.first!
        
        track.clear()
        track.sequence.add(noteNumber: data.downbeatNoteNumber, position: 0.0, duration: 0.4)
        let vel = MIDIVelocity(Int(data.beatNoteVelocity))
        for beat in 1 ..< data.timeSignatureTop {
            track.sequence.add(noteNumber: data.beatNoteNumber, position: Double(beat), duration: 0.1)
            
        }
        
        track = sequencer.tracks[1]
        track.length = Double(data.timeSignatureTop)
        track.clear()
        for beat in 0 ..< data.timeSignatureTop {
            track.sequence.add(noteNumber: MIDINoteNumber(beat), velocity: vel, channel: 0, position: Double(beat), duration: 0.1)
        }
    }
    
    init() {
        let fader = Fader(osc)
        fader.gain = 20.0
        
        reverb = Reverb(fader)
        
        let _ = sequencer.addTrack(for: fader)
        
        callbackInst = CallbackInstrument(midiCallback: {(_, beat, _) in
            self.data.currentBeat = Int(beat)
            print(beat)
        })
        
        let _ = sequencer.addTrack(for: callbackInst)
        updateSequences()
        
        mixer.addInput(reverb)
    }
}
