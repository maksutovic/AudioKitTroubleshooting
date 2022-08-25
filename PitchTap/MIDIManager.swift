//
//  MIDIManager.swift
//  PitchTap
//
//  Created by Maximilian Maksutovic on 8/14/22.
//

import Foundation
import AudioKit
import CoreMIDI
import Combine

enum TiltMidiEventError: Error {
    case packetIsOfUnkownType
}

protocol TiltMIDIPacket {
    var status: MIDIStatus { get set }
}

struct TiltMIDINoteOnPacket:TiltMIDIPacket {
    var status: MIDIStatus
    var noteNumber: MIDINoteNumber
    var noteVelocity: MIDIVelocity
    var channel: MIDIChannel {
        return status.channel
    }
    func printPacket() {
        print("\(status.description): noteNumber:\(noteNumber), velocity: \(noteVelocity)")
    }
}

struct TiltMIDINoteOffPacket: TiltMIDIPacket {
    var status: MIDIStatus
    var noteNumber: MIDINoteNumber
    var noteVelocity: MIDIVelocity
    var channel: MIDIChannel {
        return status.channel
    }
    func printPacket() {
        print("\(status.description): noteNumber:\(noteNumber), velocity: \(noteVelocity)")
    }
}

struct TiltMIDIControlChangePacket: TiltMIDIPacket {
    var status: MIDIStatus
    var control: MIDIControl
    var value: MIDIByte
    var channel: MIDIChannel {
        return status.channel
    }
    func printPacket() {
        print("\(status.description): control:\(control.description), value\(value)")
    }
}

struct TiltMIDIProgramChangePacket: TiltMIDIPacket {
    var status: MIDIStatus
    var programChangeNumber: MIDIByte
    var channel: MIDIChannel {
        return status.channel
    }
    






}



//struct TiltMidiEvent {
//    let events: [MIDIEvent]
//    
//    init(with packets: [TiltMIDIPacket]) throws {
//        var eventPackets: [MIDIEvent] = []
//        for packet in packets {
//            switch packet {
//                    case let noteOnP
//            }
//        }
//    }
//}
