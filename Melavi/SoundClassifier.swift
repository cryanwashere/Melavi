//
//  SoundClassifier.swift
//  Melavi
//
//  Created by CJ Ryan on 6/19/23.
//

import Foundation
import TensorFlowLite

public protocol SoundClassiferDelegate : class {
    func soundClassifier(
        _ soundClassifier: SoundClassifier,
        capturedClassName: String,
        capturedClassProbability: Float)
}


public class SoundClassifier {
    
    // make the class a singleton
    public static let shared : SoundClassifier = SoundClassifier()
    init()
    {   // setup the interpreter when the class is initialized
        setupInterpreter()
    }
    
    
    private let modelFileName : String = "BirdNET_GLOBAL_6K_V2.4_Model_INT8"//"BirdNET_GLOBAL_2K_V2.1_Model_INT8"
    private(set) var sampleRate = 0;
    
    private var interpreter : Interpreter!
    
    public var delegate : SoundClassiferDelegate?
    
    
    public var outputShape : Int?
   
    
    public func setupInterpreter() {
        print("setting up interpreter...")
        
        guard let modelPath = Bundle.main.path(forResource: modelFileName, ofType: ".tflite") else {print("model file path declaration failed");return}
        
        do {
            
            interpreter = try Interpreter(modelPath: modelPath)
            try interpreter.allocateTensors()
            
            let inputShape = try interpreter.input(at: 0).shape
            sampleRate = inputShape.dimensions[1]
            
            //this stuff will just display information about the model in the console
            print("Model ",modelFileName," Info: ")
            print("Input shape: ", inputShape)
            print("Input dataType: ", try interpreter.input(at:0).dataType )
           // print("Sample rate: ", sampleRate)
            
        } catch {
            print("Failed to create the interpreter with error: \(error.localizedDescription)")
            return
        }
        
    }
    
    
    
    func runModelInt16(inputBuffer: [Int16]) -> [Float]? {
        //print("running model check...")
        let outputTensor : Tensor
        do {
            
            let audioBufferData = int16ArrayToData(inputBuffer)
            //print("wave array converted to data check...")
            
        
            try interpreter.copy(audioBufferData, toInputAt: 0)
            //print("data copied to interpreter check...")
            try interpreter.invoke()
            //print("interpreter invoked check...")
            
            outputTensor = try interpreter.output(at: 0)
            
            
        } catch{
            print("Interpreter failed with error: \(error.localizedDescription)")
            return nil
        }
        
        let out = dataToFloatArray(outputTensor.data) ?? []
        
        return out
    }
    
    let labelsArray : [String.SubSequence] = {
        guard let fileURL = Bundle.main.url(forResource: "BirdNET_GLOBAL_6K_V2.4_Labels", withExtension: "txt") else {print("failed to declare label file url"); return []}
        
        do {
            let labels = try String(contentsOf: fileURL)
            let labelsArray = labels.split(separator: "\n") ?? []
            return labelsArray
        } catch {print(error.localizedDescription); return []}
        
    }()
    
    func labelFromIndex(index: Int) -> String? {
        return String(self.labelsArray[index])
    }
    
    private func int16ArrayToData(_ buffer: [Int16]) -> Data {
        let floatData = buffer.map {Float($0) / Float(Int16.max)}
        return floatData.withUnsafeBufferPointer(Data.init)
    }
    private func dataToFloatArray(_ data: Data) -> [Float]? {
        guard data.count % MemoryLayout<Float>.stride == 0 else {return nil}
        
        #if swift(>=5.0)
        return data.withUnsafeBytes { .init($0.bindMemory(to: Float.self)) }
        #else
        return data.withUnsafeBytes {
            .init(UnsafeBufferPointer<Float>(
                start: $0,
                count: unsafeData.count / MemoryLayout<Element>.stride
            ))
        }
        #endif
    }
}
