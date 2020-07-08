//
//  ViewController.swift
//  SpeechRecorder
//
//  Created by Shota Ekuni on 2020/07/06.
//  Copyright © 2020 Shota Ekuni. All rights reserved.
//

import UIKit
import Speech
import AVFoundation
import Photos

class ViewController: UIViewController {
    

    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var CaptureImageView: UIImageView!
    
    var capture: Capture!
    
    var isRecording: Bool = false
    
    // Speech Recognition
    let recognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "ja_JP"))!
    var audioEngine: AVAudioEngine!
    var recognitionReq: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        audioEngine = AVAudioEngine()
        textView.text = ""
        
        capture = Capture(CaptureImageView: CaptureImageView)

        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            DispatchQueue.main.async {
                if authStatus != SFSpeechRecognizerAuthorizationStatus.authorized {
                        self.recordButton.isEnabled = false
                        self.recordButton.backgroundColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
                    }
            }
        }
    }

    
    
    @IBAction func recordButtonTapped(_ sender: Any) {
        if isRecording == false{
            isRecording = true
            capture.setRecordStatus(_isRecording: isRecording)
            
            recordButton.setTitle("Recording now", for: .normal)
            recordButton.setTitleColor(UIColor.systemPink, for: .normal)
            try! startLiveTranscription()
        }else{
            isRecording = false
            capture.setRecordStatus(_isRecording: isRecording)
            
            recordButton.setTitle("Record", for: .normal)
            recordButton.setTitleColor(UIColor.systemBlue, for: .normal)
            stopLiveTranscription()
        }

        print("tapped")
    }
    
    /*
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
        PHPhotoLibrary.shared().performChanges({
             PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)}) {
             saved, error in
             if saved {
                  print("Save status SUCCESS")
             }
        }
        
        // show alert
        let alert: UIAlertController = UIAlertController(title: "Recorded!", message: outputFileURL.absoluteString, preferredStyle:  .alert)
        let okAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil)
        alert.addAction(okAction)
        self.present(alert, animated: true, completion: nil)
    }
    */
    
    
    func stopLiveTranscription() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionReq?.endAudio()
    }
    
    func startLiveTranscription() throws {

      // もし前回の音声認識タスクが実行中ならキャンセル
      if let recognitionTask = self.recognitionTask {
        recognitionTask.cancel()
        self.recognitionTask = nil
      }
      textView.text = ""

      // 音声認識リクエストの作成
      recognitionReq = SFSpeechAudioBufferRecognitionRequest()
      guard let recognitionReq = recognitionReq else {
        return
      }
      recognitionReq.shouldReportPartialResults = true

      // オーディオセッションの設定
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
      let inputNode = audioEngine.inputNode

      // マイク入力の設定
      let recordingFormat = inputNode.outputFormat(forBus: 0)
      inputNode.installTap(onBus: 0, bufferSize: 2048, format: recordingFormat) { (buffer, time) in
        recognitionReq.append(buffer)
      }
      audioEngine.prepare()
      try audioEngine.start()

        
        // Speech Recognize
      recognitionTask = recognizer.recognitionTask(with: recognitionReq, resultHandler: { (result, error) in
        if let error = error {
          print("\(error)")
        } else {
          DispatchQueue.main.async {
            self.textView.text = result?.bestTranscription.formattedString
          }
        }
      })
    }
}

