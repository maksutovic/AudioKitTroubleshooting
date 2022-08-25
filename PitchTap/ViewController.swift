//
//  ViewController.swift
//  PitchTap
//
//  Created by Maximilian Maksutovic on 6/4/22.
//

import UIKit
import Combine

class ViewController: UIViewController {

    private var cancellable = Set<AnyCancellable>()
    let audio = AudioManager.shared
    let freqService = FrequencyService.shared
    
    @IBOutlet weak var pitchLabel: UILabel!
    @IBOutlet weak var ampLabel: UILabel!
    
    @IBOutlet weak var frequencyToCheckLabel: UILabel!
    @IBOutlet weak var actualLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        audio.start()
        audio.startTracker()
        
        audio.pitchTapSubject
            .sink(receiveValue: {[weak self] data in
                //print("Freq:\(data.pitch)")
                self?.updateLabels(with: data)
            }).store(in: &cancellable)
        // Do any additional setup after loading the view.
    }

    @IBAction func tappedButton(_ sender: Any) {
        let random = audio.getRandomFrequency()
        freqService.listenForFrequency(frequnecyToCheck: random)
    }
    
    @IBAction func tappedPlayNote(_ sender: UIButton) {
        audio.playNote()
    }
    func updateLabels(with data:PitchData) {
        DispatchQueue.main.async {
            self.pitchLabel.text = "Pitch: \(data.pitch)"
            self.ampLabel.text = "Amp:\(data.amplitude)"
        }
    }
    @IBAction func tappedPlayClave(_ sender: UIButton) {
        audio.playClave()
    }
    
    @IBAction func tappedStartSequencer(_ sender: UIButton) {
        audio.startSequencer()
    }
}

