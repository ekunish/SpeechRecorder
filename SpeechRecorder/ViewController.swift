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

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {
    

    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var textView: UITextView!
    
    var isRecording: Bool = false
    
    // Speech Recognition
    let recognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "ja_JP"))!
    var audioEngine: AVAudioEngine!
    var recognitionReq: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    
    // Video Camera
    var videoDevice: AVCaptureDevice?
    let fileOutput = AVCaptureMovieFileOutput()
    
    
    func setUpCamera() {
        let captureSession: AVCaptureSession = AVCaptureSession()
        self.videoDevice = self.defaultCamera()
        let audioDevice: AVCaptureDevice? = AVCaptureDevice.default(for: AVMediaType.audio)

        // video input setting
        let videoInput: AVCaptureDeviceInput = try! AVCaptureDeviceInput(device: videoDevice!)
        captureSession.addInput(videoInput)

        // audio input setting
        let audioInput = try! AVCaptureDeviceInput(device: audioDevice!)
        captureSession.addInput(audioInput)

        // max duration setting
        self.fileOutput.maxRecordedDuration = CMTimeMake(value: 60, timescale: 1)

        captureSession.addOutput(fileOutput)

        // video quality setting
        captureSession.beginConfiguration()
        if captureSession.canSetSessionPreset(.hd4K3840x2160) {
            captureSession.sessionPreset = .hd4K3840x2160
        } else if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }
        captureSession.commitConfiguration()

        captureSession.startRunning()

        // プレビュー表示用のレイヤ
        var cameraPreviewLayer : AVCaptureVideoPreviewLayer
        // 指定したAVCaptureSessionでプレビューレイヤを初期化
        cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        // プレビューレイヤが、カメラのキャプチャーを縦横比を維持した状態で、表示するように設定
        cameraPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        // プレビューレイヤの表示の向きを設定
        cameraPreviewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait

        cameraPreviewLayer.frame = view.frame
        self.view.layer.insertSublayer(cameraPreviewLayer, at: 0)
    }
    
    func defaultCamera() -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(.builtInDualCamera, for: AVMediaType.video, position: .back) {
            return device
        } else if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back) {
            return device
        } else {
            return nil
        }
    }

    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        audioEngine = AVAudioEngine()
        textView.text = ""
        
        self.setUpCamera()
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
    
    
    
    @IBAction func recordButtonTapped(_ sender: Any) {
        if isRecording == false{
            let tempDirectory: URL = URL(fileURLWithPath: NSTemporaryDirectory())
            let fileURL: URL = tempDirectory.appendingPathComponent("temp.mov")
            print(tempDirectory)
            print(fileURL)
            fileOutput.startRecording(to: fileURL, recordingDelegate: self)
            
            recordButton.setTitle("Recording now", for: .normal)
            recordButton.setTitleColor(UIColor.systemPink, for: .normal)
            try! startLiveTranscription()
        }else if self.fileOutput.isRecording {
            fileOutput.stopRecording()
            
            recordButton.setTitle("Record", for: .normal)
            recordButton.setTitleColor(UIColor.systemBlue, for: .normal)
            stopLiveTranscription()
        }
        isRecording = !isRecording
        print("tapped")
    }
    
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
}

