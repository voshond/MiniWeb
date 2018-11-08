//
//  InterfaceController.swift
//  PseudoWeb WatchKit Extension
//
//  Created by Will Bishop on 24/9/18.
//  Copyright © 2018 Will Bishop. All rights reserved.
//

import WatchKit
import Foundation
import SwiftSoup
import ImageIO




class InterfaceController: WKInterfaceController {
    
    @IBOutlet weak var WebsiteTabel: WKInterfaceTable!
    var forbiddenClasses: [String] = ["header-module__inner", "brand brand--9News"]
    var superUrl: String? = nil
    var processedElements: [Element] = []
    var html = TestHtml.html
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        if let url = context as? URL{
            self.superUrl = url.absoluteString
            self.fetchWebsite(fromUrl: url)
            self.superUrl = url.host ?? ""
        }
        if let url = context as? String{
            if url == "localTest"{
                let testUrl = URL(string: "https://www.abc.net.au/news/2018-11-08/eurydice-dixon-jaymes-todd-guilty-plea-rape-murder/10475992")!
                self.fetchWebsite(fromUrl: testUrl)
                self.superUrl = testUrl.host ?? ""
                //self.processHtml(html: html)
            }
        }
        // Configure interface objects here.
        // self.fetchWebsite(fromUrl: URL(string: superUrl)!)
        
    }
    var elements: [ElementObject] = []
    func isValidDiv(element: Element) -> Bool{
        if !(element.tagName() == "div"){
            return false
        }
        
        if !(((try? element.text()) ?? "").count > 2000){
            return false
        }
        if forbiddenClasses.contains((try? element.className()) ?? ""){
            return false
        }
        guard let allElements = try? element.getAllElements() else {return false}
        return allElements.contains(where: {
            $0.tagName() == "h"  ||
                $0.tagName() == "h1" ||
                $0.tagName() == "h2" ||
                $0.tagName() == "h3" ||
                $0.tagName() == "h4" ||
                $0.tagName() == "h5" ||
                $0.tagName() == "h6"
        })
        return false
    }
    func processHtml(html: String){
        guard let html = try? SwiftSoup.parse(html) else {return}
        if let title = try? html.title() {
            elements.append(ElementObject(type: .title, text: title, image: nil))
            //elements.append(ElementObject(type: .seperator))
            
        }
        guard let body = try? html.body() else {return}
        guard var children = try? html.getAllElements() else {return}
        if let div = children.first(where: {isValidDiv(element: $0)}){
            if let allElemnents = try? div.getAllElements(){
                children = allElemnents
            }
        } else {
            print("Found no div")
        }
        for element in children{
            if self.processedElements.contains(element) {
                continue
            }
            self.processedElements.append(element)
            switch element.tagName(){
            case "img":
                let image = Image.findImages(in: element, withSuperUrl: self.superUrl)
                
                self.elements.append(ElementObject(type: .image, text: nil, image: image))
            case "b":
                guard let text = try? element.text() else {return}
                let objects = self.findLinksIn(element: element, withText: text, withType: .bold)
                self.processObjects(objects: objects, withParentType: .bold)
            case "br":
                self.elements.append(ElementObject(type: .lineBreak))
            case "q", "blockquote":
                self.elements.append(ElementObject(type: .quote, text: try? element.text(), image: nil))
            case "caption", "figcaption":
                self.elements.append(ElementObject(type: .caption, text: try? element.text(), image: nil))
            case "a":
                if let linkText = try? element.text(), let linkHref = try? element.attr("href"){
                    let startIndex = linkText.startIndex.encodedOffset
                    let endIndex = linkText.endIndex.encodedOffset
                    var preposition = (self.superUrl ?? "") + "/"
                    if linkHref.contains("http"){
                        preposition = ""
                    }
                    if linkHref == "#"{
                        continue
                    }
                    var linkUrl = URL(string: preposition + linkHref)
                    
                    var link = Link(startText: "", startIndex: startIndex, linkText: linkText, endText: "", endIndex: endIndex, url: linkUrl)
                    self.elements.append(ElementObject(type: .link, text: nil, image: nil, Link: link))
                }
                
            case "p":
                guard let text = try? element.text() else {return}
                let objects = self.findLinksIn(element: element, withText: text, withType: .text)
                self.processObjects(objects: objects, withParentType: .text)
            case "h", "h1":
                guard let text = try? element.text() else {return}
                let objects = self.findLinksIn(element: element, withText: text, withType: .header)
                self.processObjects(objects: objects, withParentType: .header)
            case "h2":
                guard let text = try? element.text() else {return}
                let objects = self.findLinksIn(element: element, withText: text, withType: .header2)
                self.processObjects(objects: objects, withParentType: .header2)
            case "h3":
                guard let text = try? element.text() else {return}
                let objects = self.findLinksIn(element: element, withText: text, withType: .header3)
                self.processObjects(objects: objects, withParentType: .header3)
            case "h4":
                guard let text = try? element.text() else {return}
                let objects = self.findLinksIn(element: element, withText: text, withType: .header4)
                self.processObjects(objects: objects, withParentType: .header4)
            case "hr":
                self.elements.append(ElementObject(type: .seperator))
            default:
                print()
            }
            
            
        }
        self.setupPage(withElements: self.elements)
        
        
    }
    func setupPage(withElements elements: [ElementObject]){
        for (index, element) in elements.enumerated(){
            print("///")
            print(index)
            print(element)
            print("///")
            switch element.type{
            case .title:
                if let text = element.text{
                    self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "TitleCell")
                    if let row = self.WebsiteTabel.rowController(at: index) as? TextCell{
                        row.cellText.setText(text)
                    }
                    
                }
                
            case .seperator:
                self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "SeperatorCell")
                
                
            case .image:
                if let image = element.image, let imageURL = image.imageURL{
                    self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "ImageCell")
                    if let row = self.WebsiteTabel.rowController(at: index) as? ImageCell{
                        if let imageHeight = image.height{
                            row.cellImage.setHeight(imageHeight)
                        }
                        
                        if imageURL.absoluteString.hasSuffix(".gif"){
                            let gif = UIImage.gifImageWithURL(imageURL.absoluteString)
                            row.cellImage.setImage(gif)
                            row.cellImage.startAnimating()
                        } else {
                            URLSession.shared.dataTask(with: imageURL, completionHandler: {data, _, _ in
                                guard let data = data else {return}
                                
                                row.cellImage.setImage(UIImage(data: data))
                            }).resume()
                        }
                    }
                }
            case .text:
                if let text = element.text{
                    self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "TextCell")
                    if let row = self.WebsiteTabel.rowController(at: index) as? TextCell{
                        row.cellText.setText(text)
                    }
                    
                }
            case .lineBreak:
                self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "LineBreakCell")
            case .caption:
                if let text = element.text{
                    self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "CaptionCell")
                    if let row = self.WebsiteTabel.rowController(at: index) as? TextCell{
                        row.cellText.setText(text)
                    }
                    
                }
            case .quote:
                if let text = element.text{
                    self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "QuoteCell")
                    if let row = self.WebsiteTabel.rowController(at: index) as? TextCell{
                        row.cellText.setText(text)
                    }
                    
                }
            case .unknown:
                print()
            case .header:
                if let text = element.text{
                    self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "HeaderCell")
                    if let row = self.WebsiteTabel.rowController(at: index) as? TextCell{
                        row.cellText.setText(text)
                    }
                }
            case .header2:
                if let text = element.text{
                    self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "Header2Cell")
                    if let row = self.WebsiteTabel.rowController(at: index) as? TextCell{
                        row.cellText.setText(text)
                    }
                }
            case .header3:
                if let text = element.text{
                    self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "Header3Cell")
                    if let row = self.WebsiteTabel.rowController(at: index) as? TextCell{
                        row.cellText.setText(text)
                    }
                }
            case .header4:
                if let text = element.text{
                    self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "Header4Cell")
                    if let row = self.WebsiteTabel.rowController(at: index) as? TextCell{
                        row.cellText.setText(text)
                    }
                }
            case .link:
                if let link = element.Link{
                    guard let startText = link.startText, let linkText = link.linkText, let endtext = link.endText else {return}
                    let mutedText = NSMutableAttributedString(string: startText + linkText + endtext)
                    mutedText.addAttributes([
                        NSAttributedString.Key.foregroundColor: UIColor(red:0.11, green:0.63, blue:0.95, alpha:1.0)], range: NSRange(location: link.startIndex!, length: linkText.count))
                    
                    self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "LinkCell")
                    if let row = self.WebsiteTabel.rowController(at: index) as? LinkCell{
                        row.linkText.setAttributedText(mutedText)
                        row.url = link.url
                    }
                }
            case .bold:
                if let text = element.text{
                    self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "BoldCell")
                    if let row = self.WebsiteTabel.rowController(at: index) as? TextCell{
                        row.cellText.setText(text)
                    }
                    
                }
            }
        }
    }
    func findLinksIn(element: Element, withText text: String, withType type: ElementType) -> [ElementObject]{
        var objects = [ElementObject]()
        if let links = try? element.getElementsByTag("a"){
            var asArray = links.array()
            if asArray.count == 0{
                objects.append(ElementObject(type: type, text: text, image: nil))
                
            }
            for link in asArray{
                self.processedElements.append(link)
                if let linkText = try? link.text(), let linkHref = try? link.attr("href"){
                    if let startIndex = text.index(of: linkText){
                        let endIndex = startIndex + linkText.count
                        var beforeLink = text[0 ..< startIndex]
                        var afterLink = ""
                        if linkText.count == endIndex{
                            
                        } else {
                            //Checks is the upper bound (text.count - 1) is greater than the lower bound (endIndex), if it is return "", else return the differenceli
                            afterLink = (text.count - 1) > endIndex ? text[endIndex ... (text.count - 1)] : ""
                            
                        }
                        print(beforeLink + "(" + linkText + ")" + afterLink)
                        var link = Link(startText: beforeLink, startIndex: startIndex, linkText: linkText, endText: afterLink, endIndex: (text.count - 1), url: URL(string: linkHref)!)
                        self.elements.append(ElementObject(type: .link, text: nil, image: nil, Link: link))
                        
                    }
                    
                    
                }
            }
        } else {
            objects.append(ElementObject(type: type, text: text, image: nil))
        }
        return objects
    }
    func processObjects(objects: [ElementObject], withParentType type: ElementType){
        for element in objects{
            if element.type == type{
                guard let concatenatedText = element.text else {return}
                self.elements.append(ElementObject(type: type, text: concatenatedText, image: nil))
            }
            if element.type == .link{
                guard let concatenatedText = element.text else {return}
                guard let url = element.image else {return}
                self.elements.append(ElementObject(type: .link, text: concatenatedText, image: url))
            }
        }
    }
    func fetchWebsite(fromUrl url: URL){
        URLSession.shared.dataTask(with: url, completionHandler: {data, response, error in
            guard let data = data else {return}
            guard let responseString = String(data: data, encoding: String.Encoding.utf8) else {return}
            
            self.processHtml(html: responseString)
            
        }).resume()
    }
    
    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        if let row = self.WebsiteTabel.rowController(at: rowIndex) as? LinkCell{
            if let url = row.url{
                self.pushController(withName: "linkViewer", context: url)
            }
        }
    }
    
}

extension String{
    func index(of target: String) -> Int? {
        if let range = self.range(of: target) {
            return characters.distance(from: startIndex, to: range.lowerBound)
        } else {
            return nil
        }
    }
    subscript (bounds: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start...end])
    }
    
    subscript (bounds: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start..<end])
    }
}
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

extension UIImage {
    
    public class func gifImageWithData(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("image doesn't exist")
            return nil
        }
        
        return UIImage.animatedImageWithSource(source)
    }
    
    public class func gifImageWithURL(_ gifUrl:String) -> UIImage? {
        guard let bundleURL:URL? = URL(string: gifUrl)
            else {
                print("image named \"\(gifUrl)\" doesn't exist")
                return nil
        }
        guard let imageData = try? Data(contentsOf: bundleURL!) else {
            print("image named \"\(gifUrl)\" into NSData")
            return nil
        }
        
        return gifImageWithData(imageData)
    }
    
    public class func gifImageWithName(_ name: String) -> UIImage? {
        guard let bundleURL = Bundle.main
            .url(forResource: name, withExtension: "gif") else {
                print("SwiftGif: This image named \"\(name)\" does not exist")
                return nil
        }
        guard let imageData = try? Data(contentsOf: bundleURL) else {
            print("SwiftGif: Cannot turn image named \"\(name)\" into NSData")
            return nil
        }
        
        return gifImageWithData(imageData)
    }
    
    class func delayForImageAtIndex(_ index: Int, source: CGImageSource!) -> Double {
        var delay = 0.1
        
        let cfProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
        let gifProperties: CFDictionary = unsafeBitCast(
            CFDictionaryGetValue(cfProperties,
                                 Unmanaged.passUnretained(kCGImagePropertyGIFDictionary).toOpaque()),
            to: CFDictionary.self)
        
        var delayObject: AnyObject = unsafeBitCast(
            CFDictionaryGetValue(gifProperties,
                                 Unmanaged.passUnretained(kCGImagePropertyGIFUnclampedDelayTime).toOpaque()),
            to: AnyObject.self)
        if delayObject.doubleValue == 0 {
            delayObject = unsafeBitCast(CFDictionaryGetValue(gifProperties,
                                                             Unmanaged.passUnretained(kCGImagePropertyGIFDelayTime).toOpaque()), to: AnyObject.self)
        }
        
        delay = delayObject as! Double
        
        if delay < 0.1 {
            delay = 0.1
        }
        
        return delay
    }
    
    class func gcdForPair(_ a: Int?, _ b: Int?) -> Int {
        var a = a
        var b = b
        if b == nil || a == nil {
            if b != nil {
                return b!
            } else if a != nil {
                return a!
            } else {
                return 0
            }
        }
        
        if a < b {
            let c = a
            a = b
            b = c
        }
        
        var rest: Int
        while true {
            rest = a! % b!
            
            if rest == 0 {
                return b!
            } else {
                a = b
                b = rest
            }
        }
    }
    
    class func gcdForArray(_ array: Array<Int>) -> Int {
        if array.isEmpty {
            return 1
        }
        
        var gcd = array[0]
        
        for val in array {
            gcd = UIImage.gcdForPair(val, gcd)
        }
        
        return gcd
    }
    
    class func animatedImageWithSource(_ source: CGImageSource) -> UIImage? {
        let count = CGImageSourceGetCount(source)
        var images = [CGImage]()
        var delays = [Int]()
        
        for i in 0..<count {
            if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(image)
            }
            
            let delaySeconds = UIImage.delayForImageAtIndex(Int(i),
                                                            source: source)
            delays.append(Int(delaySeconds * 1000.0)) // Seconds to ms
        }
        
        let duration: Int = {
            var sum = 0
            
            for val: Int in delays {
                sum += val
            }
            
            return sum
        }()
        
        let gcd = gcdForArray(delays)
        var frames = [UIImage]()
        
        var frame: UIImage
        var frameCount: Int
        for i in 0..<count {
            frame = UIImage(cgImage: images[Int(i)])
            frameCount = Int(delays[Int(i)] / gcd)
            
            for _ in 0..<frameCount {
                frames.append(frame)
            }
        }
        
        let animation = UIImage.animatedImage(with: frames,
                                              duration: Double(duration) / 1000.0)
        
        return animation
    }
}
