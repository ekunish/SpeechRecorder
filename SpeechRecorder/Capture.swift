//
//  Capture.swift
//  SpeechRecorder
//
//  Created by Shota Ekuni on 2020/07/07.
//  Copyright © 2020 Shota Ekuni. All rights reserved.
//


import UIKit
import CoreLocation
import CoreAudio
import CoreMotion
import CoreFoundation
import AVFoundation
import MediaPlayer
import Photos
import Foundation

class Capture: NSObject {
    
    
    var captureSession: AVCaptureSession!
    var videoDevice: AVCaptureDevice!
    var audioDevice: AVCaptureDevice!
    var videoInput: AVCaptureDeviceInput!
    var audioInput: AVCaptureDeviceInput!
    var videoDataOutput: AVCaptureVideoDataOutput!
    var audioDataOutput: AVCaptureAudioDataOutput!
    var start = Date()
    
    var videoWriterInput: AVAssetWriterInput!
    var videoWriterAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    var videoWriter: AVAssetWriter!

    var audioWriterInput: AVAssetWriterInput!

    var fileURL: URL!
    var pixelBuffer: CVPixelBuffer? = nil
    var fps: __int32_t = 30
    var time:Int = 1
    var frameCount: Int! = 0
    var isRecording: Bool = false
    var createdVideoWriterAdaptor: Bool = false
    var sampleBuffer: CMSampleBuffer!
    

    var realFPS: __uint32_t = 0
    
    var formatWidth: Int32 = 1080
    var formatHeight: Int32 = 1920
    var torchLevel: Float = 0
    
    var isSaving: Bool = false
    
    
    var lastVideo: Int64 = 0 // 一つ前の時間情報を保存する(Video用)
    var lastAudio: Int64 = 0 // 一つ前の時間情報を保存する(Audio用)
    var frameCounter = 0 // フレームのカウント


    
    
    init(CaptureImageView: UIImageView){
        super.init()

        self.createNewAlbum(albumTitle: "SpeechRecorder", callback: { (isSuccess) in
            if isSuccess {
                print("成功")
            }
            else {
                print("失敗")
            }
        })
        
        print("starting setup capture")
        self.setupVideo(captureImageView: CaptureImageView)
        self.torch(level: 0.0)
    }
    

    
    
    func setupVideo(captureImageView: UIImageView){
        // generate session
        self.captureSession = AVCaptureSession()
        self.captureSession.beginConfiguration()
               
        // add videoDevice to captureSession
        self.videoDevice = AVCaptureDevice.default(for: AVMediaType.video)
        self.videoInput = try! AVCaptureDeviceInput(device: self.videoDevice)
        self.captureSession.addInput(self.videoInput)

        self.switchFormat(targetFPS: self.fps)
        

        // add audioDevice to captureSession
        self.audioDevice = AVCaptureDevice.default(for: AVMediaType.audio)
        self.audioInput = try! AVCaptureDeviceInput(device: self.audioDevice)
        self.captureSession.addInput(self.audioInput)
        

        // videoDataOutput
        self.videoDataOutput = AVCaptureVideoDataOutput()
        self.videoDataOutput.videoSettings =
           [kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_32BGRA]
           as [String : Any]
        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
        self.captureSession.addOutput(self.videoDataOutput)
        
        
        // audioDataOutput
        self.audioDataOutput = AVCaptureAudioDataOutput()
        
        self.captureSession.addOutput(self.audioDataOutput)

        
        let videoConnection = videoDataOutput.connection(with: AVMediaType.video)
        videoConnection?.videoOrientation = .portrait

        print("videoConnection start")
        
        
        // preview
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.backgroundColor = UIColor.black.cgColor
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = captureImageView.bounds
        print(captureImageView.bounds)
        //previewLayer.connection!.videoOrientation = .portrait
        captureImageView.layer.addSublayer(previewLayer)
        
        // session start
        self.captureSession.commitConfiguration()
        self.captureSession.startRunning()
        // qos引数は処理の優先順位
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async {
               // 上記処理の終了後、下記処理をメインスレッドで実行
            }
        }
    }
    
    func torch(level: Float) {
        if let avDevice = AVCaptureDevice.default(for: AVMediaType.video){
           print("flash slider:  \(level)")
           if avDevice.hasTorch {
               do {
                   try avDevice.lockForConfiguration()
                   if (level > 0.0){
                       do {
                           try avDevice.setTorchModeOn(level: level)
                       } catch {
                           print("error")
                       }
                   } else {
                       avDevice.torchMode = AVCaptureDevice.TorchMode.off
                   }
                   avDevice.unlockForConfiguration()
               } catch {
                   print("Torch could not be used")
               }
           } else {
               print("Torch is not available")
           }
        }
        else{
           // no support
        }
    }
    
    func imageFromSampleBuffer(sampleBuffer :CMSampleBuffer) -> UIImage {
         let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!

         // イメージバッファのロック
         CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))

         // 画像情報を取得
         let base = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)!
         let bytesPerRow = UInt(CVPixelBufferGetBytesPerRow(imageBuffer))
         let width = UInt(CVPixelBufferGetWidth(imageBuffer))
         let height = UInt(CVPixelBufferGetHeight(imageBuffer))

         //print("width: \(width)")
         //print("height: \(height)")

         // ビットマップコンテキスト作成
         let colorSpace = CGColorSpaceCreateDeviceRGB()
         let bitsPerCompornent = 8
         let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) as UInt32)
         let newContext = CGContext(data: base, width: Int(width), height: Int(height), bitsPerComponent: Int(bitsPerCompornent), bytesPerRow: Int(bytesPerRow), space: colorSpace, bitmapInfo: bitmapInfo.rawValue)! as CGContext

         // 画像作成
         let imageRef = newContext.makeImage()!
         let image = UIImage(cgImage: imageRef, scale: 1.0, orientation: UIImage.Orientation.up)
         // イメージバッファのアンロック
         CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))

         // 回転
         return image
    }
    
    
    func switchFormat(targetFPS: __int32_t) {
        // カメラの設定
        do {
            // セッションが始動中なら止める
            let isRunning = self.captureSession.isRunning
            if isRunning {
                self.captureSession.stopRunning()
            }
            
            // カメラの設定を触るときはデバイスをロックする
            try self.videoDevice.lockForConfiguration()

            /* カメラにフレームレートを設定する */
            self.fps = targetFPS
            
            // 取得したフォーマットを格納する変数
            var selectedFormat: AVCaptureDevice.Format! = nil
            // そのフレームレートの中で一番大きい解像度を取得する
            var maxWidth: Int32 = 0
            // フォーマットを探る
            for format in videoDevice.formats {
                // フォーマット内の情報を抜き出す (for in と書いているが1つの format につき1つの range しかない)
                for range: AVFrameRateRange in format.videoSupportedFrameRateRanges {
                    let description = format.formatDescription as CMFormatDescription    // フォーマットの説明
                    let dimensions = CMVideoFormatDescriptionGetDimensions(description)  // 幅・高さ情報を抜き出す
                    let width = dimensions.width                                         // 幅
                    let height = dimensions.height
                    //print("フォーマット情報 : \(description)")
                    //print("maxFrameRate: \(range.maxFrameRate)")
                
                    // 指定のフレームレートで一番大きな解像度を得る
                    if Float64(self.fps) == range.maxFrameRate && width == 1920 && height == 1080{ // width >= maxWidth
                        //print("このフォーマットを候補にする")
                        selectedFormat = format
                        maxWidth = width
                        print(maxWidth)
                    }
                }
            }
            
            // フォーマットが取得できていれば設定する
            if selectedFormat != nil {
                do {
                    try videoDevice.lockForConfiguration()
                    videoDevice.activeFormat = selectedFormat
                    videoDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(self.fps))
                    videoDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(self.fps))
                    //videoDevice.unlockForConfiguration()
                    let description = selectedFormat.formatDescription as CMFormatDescription
                    let dimensions = CMVideoFormatDescriptionGetDimensions(description)  // 幅・高さ情報を抜き出す
                    formatWidth = dimensions.height
                    formatHeight = dimensions.width
                    print("\(description)")
                    print("\(formatWidth)")
                    print("\(formatHeight)")
                }
                catch {
                    print("フォーマット・フレームレートが指定できなかった")
                }
            } else {
                print("指定のフォーマットが取得できなかった")
            }
            

            // 低照度で撮影する場合の明るさのブースト
            if self.videoDevice.isLowLightBoostEnabled {
                self.videoDevice.automaticallyEnablesLowLightBoostWhenAvailable = true
            }


            // 露出の設定 （画面の中心に露出を合わせる）
            if self.videoDevice.isExposureModeSupported(.continuousAutoExposure) && self.videoDevice.isExposurePointOfInterestSupported {
                self.videoDevice.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
                self.videoDevice.exposureMode = .continuousAutoExposure
                //self.videoDevice.exposureMode = .autoExpose
            
            }
            
            // デバイスのアンロック
            self.videoDevice.unlockForConfiguration()

            // セッションが始動中だったら再開する
            if isRunning {
                self.captureSession.startRunning()
            }
        } catch {
            print(error)
            return
        }
    }
    
    // アルバムの作成
    func createNewAlbum(albumTitle: String, callback: @escaping (Bool) -> Void) {
        if self.albumExists(albumTitle: albumTitle) {
            callback(true)
        } else {
            PHPhotoLibrary.shared().performChanges({
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumTitle)
            }) { (isSuccess, error) in
                callback(isSuccess)
            }
        }
    }
    // アルバムが既にあるか確認
    func albumExists(albumTitle: String) -> Bool {
        let albums = PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.album, subtype:
            PHAssetCollectionSubtype.albumRegular, options: nil)
        for i in 0 ..< albums.count {
            let album = albums.object(at: i)
            if album.localizedTitle != nil && album.localizedTitle == albumTitle {
                return true
            }
        }
        return false
    }
    
    
    func setRecordStatus(_isRecording: Bool){
        self.isRecording = _isRecording
        
        // qos引数は処理の優先順位
        DispatchQueue.global().async {
           // 上記処理の終了後、下記処理をメインスレッドで実行
            if(self.isRecording){
                print("set RecordStatus start")
                self.startRecord()
            }else if !self.isSaving{
                self.stopRecord()
            }
        }
    }
    
    func startRecord() {
        // ビデオの保存URL
        fileURL = NSURL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("\(NSUUID().uuidString).mp4")

        let width = self.formatWidth // 1080
        let height = self.formatHeight //1920のはず…
        
        do {
            try videoWriter = AVAssetWriter(outputURL: fileURL!, fileType: AVFileType.mov)
            
            // ビデオ入力設定 (h264コーデックを使用・フルHD)
            let videoSettings = [
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCodecKey: AVVideoCodecType.h264
                ] as [String: Any]
            
            videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings as [String : AnyObject])
            videoWriterInput?.expectsMediaDataInRealTime = true
            
            if videoWriter.canAdd(videoWriterInput){
                videoWriter.add(videoWriterInput)
                print("video input added")
            } else {
                print("no video input added")
            }
            
            
            // AVAssetWriterInputPixelBufferAdaptor
            videoWriterAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoWriterInput!,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height,
                    ]
            )
            
            
            
            // audio
            let audioOutputSettings: Dictionary<String, AnyObject> = [
                AVFormatIDKey : kAudioFormatMPEG4AAC as AnyObject,
                AVEncoderAudioQualityKey : AVAudioQuality.max.rawValue as AnyObject,
                AVNumberOfChannelsKey : 2 as AnyObject,
                AVSampleRateKey : 44100.0 as AnyObject,
                AVEncoderBitRateKey : 128000 as AnyObject
            ]
            audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioOutputSettings)
            audioWriterInput.expectsMediaDataInRealTime = true
            
            if videoWriter.canAdd(audioWriterInput){
                videoWriter.add(audioWriterInput)
                print("audio input added")
            } else {
                print("no audio input added")
            }
            
            
            // 動画生成開始
            videoWriter!.startWriting()
            videoWriter!.startSession(atSourceTime: CMTime.zero)
            
        } catch {
            print("couldn't create videoWriter")
        }
        
        print("success: create videoWriterAdaptor")
        // フレーム番号の初期化
        frameCount = 0
        self.createdVideoWriterAdaptor = true
    }
    
    
    


    func updateRecord(sampleBuffer: CMSampleBuffer){
        // 動画の時間を生成(その画像の表示する時間/開始時点と表示時間を渡す)
        print("frameCount: \(frameCount ?? 0)")
        let frameTime: CMTime = CMTimeMake(value: Int64(__int32_t(frameCount) * __int32_t(time)), timescale: self.fps)
        frameCount += 1
        let second = CMTimeGetSeconds(frameTime)
        print("second: \(second)")
        
        
        if (!videoWriterAdaptor.assetWriterInput.isReadyForMoreMediaData) {
            print("couldn't add pixelBufferAdapter")
//            return
        } else if (!videoWriterAdaptor.append(CMSampleBufferGetImageBuffer(sampleBuffer)!, withPresentationTime: frameTime)) {
            print(videoWriter!.error!)
        }
        
        //
        if (!audioWriterInput!.isReadyForMoreMediaData){
            print("couldn't add audio")
        } else {
            audioWriterInput.append(CMSampleBufferGetImageBuffer(sampleBuffer)! as! CMSampleBuffer)
        }
        
    }
    
    
    func stopRecord() {
        // 動画生成終了
        if videoWriterInput == nil || videoWriter == nil{
            return
        }
        self.isSaving = true
        print("movie saving.................................")
        videoWriterInput!.markAsFinished()
        videoWriter!.endSession(atSourceTime: CMTimeMake(value: Int64((__int32_t(frameCount)) *  __int32_t(time)), timescale: self.fps))
        videoWriter!.finishWriting(completionHandler: {
            // Finish!
            print("movie created.")
            self.videoWriterInput = nil
            if self.fileURL != nil {
                print("================")
            }
        })
        
        saveVideo(contentUrl: self.fileURL)
        self.isSaving = false
    }
    
    func saveVideo(contentUrl: URL){
        // mp4 ファイルならフォトライブラリに書き出す
        PHPhotoLibrary.shared().performChanges({
            // フォトアプリの中にあるアルバムを検索する.
            let list = PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.album, subtype: PHAssetCollectionSubtype.any, options: nil)
            var assetAlbum : PHAssetCollection!
            // リストの中にあるオブジェクトに対して１つずつ呼び出す.
            list.enumerateObjects { (album, index, isStop) in
                // アルバムを検出.
                let albumTitle: String = "SpeechRecorder"
                if album.localizedTitle == albumTitle {
                    print("album exists")
                    assetAlbum = album
                }
            }
            // URLからResultFetchを作成.
            let result = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: contentUrl)
            // PHAssetを作成.
            let assetPlaceholder = result?.placeholderForCreatedAsset
            // どのアルバムに入れるかを選択.
            let albumChangeRequset = PHAssetCollectionChangeRequest(for: assetAlbum)
            // アルバムにアセットを追加する.
            albumChangeRequset?.addAssets([assetPlaceholder!] as NSFastEnumeration)
            
        }) { (isCompleted, error) in
            if isCompleted {
                // フォトライブラリに書き出し成功
                do {
                  try FileManager.default.removeItem(atPath: contentUrl.path)
                  print("フォトライブラリ書き出し・ファイル削除成功 : \(contentUrl.lastPathComponent)")
                }
                catch {
                  print("フォトライブラリ書き出し後のファイル削除失敗 : \(contentUrl.lastPathComponent)")
                }
            }else {
            print("フォトライブラリ書き出し失敗 : \(contentUrl)")
            }
        }
    }
}





extension Capture : AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate{

    func captureOutput(_ captureoutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        //let isVideo = captureOutput is AVCaptureAudioDataOutput
        
        var blockBuffer: CMBlockBuffer?
        let audioBufferList = AudioBufferList.allocate(maximumBuffers: 1)
        defer {
          free(audioBufferList.unsafeMutablePointer)
        }
        
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
          sampleBuffer,
          bufferListSizeNeededOut: nil,
          bufferListOut: audioBufferList.unsafeMutablePointer,
          bufferListSize: MemoryLayout<AudioBufferList>.size,
          blockBufferAllocator: nil,
          blockBufferMemoryAllocator: nil,
          flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment),
          blockBufferOut: &blockBuffer
        )
        
        guard blockBuffer != nil, let audioBuffer = audioBufferList.first else { return }
        let audioSampleBuffer = UnsafeBufferPointer<Int16>(audioBuffer)
        guard audioSampleBuffer.count > 0 else { return }
        
        print("captureOutput dataSize=\(audioBuffer.mDataByteSize)")
        for _ in audioSampleBuffer {
          // ENAMRATE SAMPLE DATA...
        }
        DispatchQueue.global(qos: .userInitiated).async {

            DispatchQueue.main.async {
            }
        }
    }
}
