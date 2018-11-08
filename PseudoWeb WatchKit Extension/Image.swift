//
//  Image.swift
//  PseudoWeb WatchKit Extension
//
//  Created by Will Bishop on 8/11/18.
//  Copyright © 2018 Will Bishop. All rights reserved.
//

import Foundation
import WatchKit
import SwiftSoup

struct Image{
    var image: UIImage? = nil
    var imageURL: URL? = nil
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    
    static func findImages(in element: Element, withSuperUrl superUrl: String?) -> Image?{
        guard let src = try? element.attr("src") else {return nil}
        let currentDevice = WKInterfaceDevice.current()
        let screenWidth = Int(currentDevice.screenBounds.width)
        var image = Image()
        if let imageWidth = try? element.attr("width"), let imageWidthInt = Int(imageWidth){
            let scale = CGFloat(screenWidth) / CGFloat(imageWidthInt)
            image.width = scale * CGFloat(imageWidthInt)
            if let imageHeight = try? element.attr("height"), let imageHeightInt = Int(imageHeight){
                image.height = scale * CGFloat(imageHeightInt)
            }
        }
        var preposition = (superUrl ?? "") + "/"
        if src.contains("http"){
            preposition = ""
        }
        image.imageURL = URL(string: preposition + src)
        return image
    }
}
