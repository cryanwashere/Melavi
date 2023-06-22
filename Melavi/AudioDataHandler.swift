//
//  AudioDataHandler.swift
//  Melavi
//
//  Created by CJ Ryan on 6/19/23.
//

import Foundation
import AVFAudio







struct sessionBuffer {
    
    let timeFinished : Date
    let pcmBuffer : AVAudioPCMBuffer
    let stride : Int
    
    init(timeFinished: Date, pcmBuffer: AVAudioPCMBuffer, stride: Int ){
        self.timeFinished = timeFinished
        self.pcmBuffer = pcmBuffer
        self.stride = stride
    }
    
}


class AudioTapper {
    

    
    // make the class a singleton
    public static let shared : AudioTapper = AudioTapper()
    
    
    let soundClassifier = SoundClassifier.shared
    
    
    private let conversionQueue = DispatchQueue(label: "conversionQueue")
    
    private var audioEngine = AVAudioEngine()
    
    // the sample rate refers to how many times per second the microphone captures a
    // sample. therefore, every second the microphone records the air pressure around
    // it sampleRate times.
    public let sampleRate : Int = 48000
    
    var sessionBuffers : [sessionBuffer] = Array()
    
    func requestPermission(){
        AVAudioSession.sharedInstance().requestRecordPermission{granted in
            if granted {
                self.startTappingMicrophone()
            } else {
                self.checkPermissionAndStartTappingMicrophone()
            }
        }
    }
    func checkPermissionAndStartTappingMicrophone() {
        print("checking permission to record...")
        switch AVAudioSession.sharedInstance().recordPermission{
        case .granted:
            print("permission granted")
            startTappingMicrophone()
        case .denied:
            print("permission denied")
            return
        case .undetermined:
            requestPermission()
        default:
            return
        }
    }
    

    
    func startTappingMicrophone(){
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        
        guard let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: true
        )  else {print("failed to declare recordingFormat");return}
        
        guard let formatConverter = AVAudioConverter(from: inputFormat, to:recordingFormat) else {print("failed to create format converter");return}
        
        // the buffer tap
        inputNode.installTap(onBus: 0,
                             bufferSize: AVAudioFrameCount(sampleRate*3), // the neural network graph takes in buffers of sequences that are 3 seconds long
                             format: inputFormat) {buffer, _ in
            
     
            
            // all the processing of the sound data is not done on the main queue
            self.conversionQueue.async {
                
                // create a PCM buffer for the data
                guard let pcmBuffer = AVAudioPCMBuffer(
                    pcmFormat: recordingFormat,
                    frameCapacity: AVAudioFrameCount(recordingFormat.sampleRate * 3.0)
                ) else {return}
                pcmBuffer.frameLength = pcmBuffer.frameCapacity
                
                var error : NSError?
                let inputBlock : AVAudioConverterInputBlock = {_, outStatus in
                    outStatus.pointee = AVAudioConverterInputStatus.haveData
                    return buffer
                }
                
                // put the data into the PCM buffer
                formatConverter.convert(to: pcmBuffer, error: &error, withInputFrom: inputBlock)
                
                if let error = error {
                    print("format converter failed: ", error.localizedDescription)
                    return
                }
                
                
                print("buffer tapped...")
                
                if let audioArray = self.pcmBufferToChannelData(pcmBuffer: pcmBuffer, Stride: buffer.stride) {
                    if var prediction : [Float] = self.soundClassifier.runModelInt16(inputBuffer: audioArray) {
                        
                        
                        
                        if SessionSettings.shared.activationFunction == "softmax" {
                            // Use softmax on the logits
                            for i in 0..<prediction.count {
                                prediction[i] = expf(prediction[i])
                            }
                            var exp_sum : Float = 0.0
                            for i in 0..<prediction.count {
                                exp_sum += prediction[i]
                            }
                            for i in 0..<prediction.count {
                                prediction[i] = prediction[i] / exp_sum
                            }
                        } else if SessionSettings.shared.activationFunction == "sigmoid" {
                            // Use Sigmoid on the logits
                            for i in 0..<prediction.count {
                                prediction[i] = 1/(1+expf(-prediction[i]))
                            }
                        }
                        
                        
                        
                        let predicted_id : Int = prediction.argmax()!
                        print(SessionSettings.shared.activationFunction, self.soundClassifier.labelFromIndex(index: predicted_id), prediction[predicted_id])
                        let label : String = self.soundClassifier.labelFromIndex(index: predicted_id)!
                        
                        print(SessionDataHandler.shared.classThreshold)
                        
                        if prediction[predicted_id] > 0.9 {
                            DispatchQueue.main.async {
                                SessionDataHandler.shared.addObservation(
                                    confidence: prediction[predicted_id],
                                    scientific_name: String(label.split(separator: "_")[0]),
                                    common_name: String(label.split(separator: "_")[1]),
                                    id: predicted_id
                                )
                            }
                        }
                        
                        
                    }
                } else {print("failed to convert PCM buffer to channel data")}
                
                
                //self.sessionBuffers.append(sessionBuffer(timeFinished: Date(), pcmBuffer: pcmBuffer, stride: buffer.stride))
                // gets rid of all superfluous buffers, so that leaving the app on will not
                // cause a memory error, because the sessionBuffers array will grow infinitely
                //self.clearSessionBuffers()
            }
        }
        
        // set up and start the audioEngine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: ", error.localizedDescription)
        }
    }
    func stopTapping() {
        // stop the audioEngine and remove the buffer tap
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    func pcmBufferToChannelData(pcmBuffer: AVAudioPCMBuffer, Stride: Int) -> [Int16]? {
        if let channelData = pcmBuffer.int16ChannelData {
            let channelDataValue = channelData.pointee
            let channelDataValueArray = stride(from: 0,
                                               to: Int(pcmBuffer.frameLength),
                                               by: Stride).map {channelDataValue[$0]}
            
            
           return channelDataValueArray
        } else {return nil}
    }
    func getSessionBuffers(start: Date, end: Date) -> [sessionBuffer] {
        var result : [sessionBuffer] = Array()
        for i in 0..<self.sessionBuffers.count {
            let time = self.sessionBuffers[i].timeFinished
            if time.timeIntervalSince(start)>0 && time.timeIntervalSince(end)-3 < 0{
                result.append(self.sessionBuffers[i])
            }
        }
        return result
    }
    func clearSessionBuffers() {
        var done = false
        var itr = 0
        let now = Date()
        while !done {
            if sessionBuffers.isEmpty || itr+1 >= sessionBuffers.count {return}
            if now.timeIntervalSince(self.sessionBuffers[itr].timeFinished)>10{
                print("removing excess session buffer at \(self.sessionBuffers[itr].timeFinished)")
                sessionBuffers.remove(at: itr)
            } else {
                itr+=1
            }
        }
    }
}




extension Array where Element: Comparable {
    func argmax() -> Index? {
        return indices.max(by: { self[$0] < self[$1] })
    }
    
    func argmin() -> Index? {
        return indices.min(by: { self[$0] < self[$1] })
    }
}

extension Array {
    func argmax(by areInIncreasingOrder: (Element, Element) throws -> Bool) rethrows-> Index? {
        return try indices.max { (i, j) throws -> Bool in
            try areInIncreasingOrder(self[i], self[j])
        }
    }
    
    func argmin(by areInIncreasingOrder: (Element, Element) throws -> Bool) rethrows-> Index? {
        return try indices.min { (i, j) throws -> Bool in
            try areInIncreasingOrder(self[i], self[j])
        }
    }
}

