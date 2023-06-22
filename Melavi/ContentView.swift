//
//  ContentView.swift
//  Melavi
//
//  Created by CJ Ryan on 6/19/23.
//

import SwiftUI

struct ContentView: View {
    
    var audioTapper = AudioTapper.shared
    
    @State var isListening : Bool = false
    @State var sessionStarted : Bool = false
    
    @StateObject var sessionDataHandler : SessionDataHandler = .shared
    
    
    
    @State var activationFunctionOptions = ["softmax", "sigmoid", "logits"]
    @State var selectedActivationFunction = "softmax"
    
    var body: some View {
        ZStack {
            VStack {
                
                HStack {
                    
                    Text("Melavi")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.purple)
                    
                    Spacer()
                    
                    
                    /*
                    // do I want to have a settings page?
                    Button {} label: {
                        Image(systemName: "gear")
                            .foregroundColor(.purple)
                            .frame(width: 50, height: 50)
                    }
                    */
                    
                    
                    if isListening {
                        Button {
                            audioTapper.stopTapping()
                            self.isListening = false
                        } label: {
                            Image(systemName: "pause")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.purple)
                                .padding()
                                
                                
                        }
                    } else {
                        
                        Button {
                            audioTapper.checkPermissionAndStartTappingMicrophone()
                            self.isListening = true
                        } label: {
                            Image(systemName: "play")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.purple)
                                .padding()
                                
                               
                        }
                    
                    }
                }
                
                Picker("activation function",selection: $selectedActivationFunction) {
                    ForEach(activationFunctionOptions, id: \.self) { item in
                                    Text(item)
                                }
                }
                
                
                Divider()
                
                HStack {
                    Text("Observations:")
                        .padding()
                    Spacer()
                }
                
                Divider()
                
                ScrollView {
                    ForEach(self.sessionDataHandler.observations, id: \.self) { observation in
                        ObservationView(observation: observation)
                    }
                }
                
            }
            
            if !sessionStarted {
                Button {
                    audioTapper.checkPermissionAndStartTappingMicrophone()
                    self.isListening = true
                    self.sessionStarted = true
                } label: {
                    Text("Tap to start listening")
                        .font(.largeTitle)
                        .fontWeight(.thin)
                        .foregroundColor(.purple)

                }
            }
            
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct Observation : Hashable {
    let confidence : Float
    let scientific_name : String
    let common_name : String
    let id : Int
}

class SessionDataHandler : ObservableObject {
    
    public static let shared = SessionDataHandler()
    
    @Published var observations : [Observation] = []
    
    // dictionary that records how many times any specific
    // class was predicted
    var classOccurences : [Int : Int] = [:]
    
    // The number of times that a particular class needs to be observed in
    // order for it to be listed as a prediction
    var classThreshold : Int = 2
    
    func addObservation(confidence: Float, scientific_name: String, common_name: String, id: Int) {
        
        // records the observation in the classOccurences dictionary
        if classOccurences[id] == nil {classOccurences[id] = 1} else {classOccurences[id]! += 1}
        
        // if the observed class has been observed a certain threshold of times, then it
        // is probably a good guess
        if classOccurences[id]! == classThreshold {
            self.observations.append(Observation(confidence: confidence, scientific_name: scientific_name, common_name: common_name, id: id))
        }
        
        
    }
    
}

class SessionSettings : ObservableObject {
    public static let shared : SessionSettings = SessionSettings()
    
    @Published var activationFunction = "softmax"
  
}
