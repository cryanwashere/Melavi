//
//  SpeciesInfoView.swift
//  Melavi
//
//  Created by CJ Ryan on 6/19/23.
//

import Foundation
import SwiftUI





struct ObservationView: View {
    
    @State var observation : Observation
    
    @StateObject var speciesInfoModel = SpeciesInfoModel()
    
    @State var showInfo : Bool = false
    
    var body: some View {
        HStack{
            Button {
                self.showInfo = true
              
            } label: {
                VStack{
                    HStack{
                       
                        // display the image if it has been loaded
                        if self.speciesInfoModel.image != nil {
                            Image(uiImage: self.speciesInfoModel.image!)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                                .frame(width: 50, height: 50)
                        }
                        
                        VStack{
                            Text("\(observation.common_name)")
                                .foregroundColor(.purple)
                                .frame(alignment: .bottomLeading)
                                .font(.system(size: 20))
                                .fontWeight(.medium)
                            
                        }// VStack (hold the display name of the predicted class, and the confidence of the prediction)
                            
                        Spacer()
                        
                    }// HStack (hold the display name of the class, and the class icon)
                    ProgressView("confidence: \(observation.confidence)", value: observation.confidence, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                            
                                
                }//VStack (Hold the information, and then a confidence bar below it)
                .padding()
            }// Button (open a google search in the browser)
        }// HStack (contains info about the predicted class)
        .onAppear {
            speciesInfoModel.fetchInfo(observation.scientific_name)
        }
        .sheet(isPresented: $showInfo) {
            SpeciesInfoView(scientific_name: observation.scientific_name, speciesInfoModel: self.speciesInfoModel, isShowing: $showInfo)
        }
    }
}





struct SpeciesInfoView: View {

@State var scientific_name : String

@ObservedObject var speciesInfoModel : SpeciesInfoModel

@Binding var isShowing : Bool

var body: some View {
ScrollView{
HStack {
Button {
self.isShowing = false
} label: {
Text("done")
.font(.system(size: 20))
.fontWeight(.medium)
.foregroundColor(.red)
}
.padding()
Spacer()
}

if self.speciesInfoModel.speciesInfo != nil {
VStack{
/*
ImageURLView(imageUrl: self.speciesInfoModel.speciesInfo!.originalimage.source)
.clipShape(Circle())
.shadow(radius: 5)
//.frame(width: 300, height: 300)
.padding()
*/
// show the image if it has been loaded
if self.speciesInfoModel.image != nil {
Image(uiImage: self.speciesInfoModel.image!)
.clipShape(Circle())
.shadow(radius: 5)
.padding()
}

HStack{
VStack{
Text(self.speciesInfoModel.speciesInfo!.title)
.font(.system(size: 30))
.fontWeight(.medium)
.foregroundColor(.purple)

}
Spacer()
}
HStack{
Text(self.speciesInfoModel.speciesInfo!.description)
.font(.system(size: 20))
.fontWeight(.regular)

Spacer()
}
}
.padding()


Text(self.speciesInfoModel.speciesInfo!.extract)
.padding()

HStack {
Spacer()
Link("open in Wikipedia", destination: URL(string: self.speciesInfoModel.speciesInfo!.content_urls.mobile.page)!)
.padding()
}


} else {
Text("No info available. Try connecting to the internet.")
}

}
.onAppear {

if speciesInfoModel.speciesInfo == nil {
speciesInfoModel.fetchInfo(scientific_name)
}
}
}
}





struct SpeciesInfo : Codable {
let title: String
let displaytitle: String
let extract: String
let description: String

let thumbnail : Thumbnail
let originalimage : Originalimage
let content_urls : Content_urls


struct Thumbnail : Codable {
let source: String
}
struct Originalimage : Codable {
let source: String
}

struct Content_urls : Codable {
let mobile : Mobile
struct Mobile : Codable {
let page: String
}
}


}

class SpeciesInfoModel: ObservableObject {
@Published var speciesInfo : SpeciesInfo? = nil
@Published var image : UIImage? = nil

func loadImage() {
    if self.speciesInfo != nil {
    DispatchQueue.global().async {
        if let url = URL(string: self.speciesInfo!.thumbnail.source), let imageData = try? Data(contentsOf: url), let uiImage = UIImage(data: imageData) {
        DispatchQueue.main.async {
            print("updating loaded image...")
                let resizedImage = uiImage.resized(to: CGSize(width: 224, height: 224 * (uiImage.size.height / uiImage.size.width)))
                    self.image = resizedImage
                }
            }
        }
    }
}

func fetchInfo(_ scientific_name: String) {

if self.speciesInfo == nil {
var formattedString = scientific_name.replacingOccurrences(of: " ", with: "_")
guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(formattedString)") else { return }
print("getting species info from: \(url)")

URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
guard let self = self else {
return
}

if let data = data {
do {
let info = try JSONDecoder().decode(SpeciesInfo.self, from: data)
DispatchQueue.main.async {
//print(info)
self.speciesInfo = info
self.loadImage()
}
} catch let error {
print(error.localizedDescription)
}
}
}.resume()
} else {
print("not fetching info because data has already been loaded")
}
}
}

extension UIImage{
    func resized(to newSize: CGSize, scale: CGFloat = 1) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let image = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
        return image
    }
}
