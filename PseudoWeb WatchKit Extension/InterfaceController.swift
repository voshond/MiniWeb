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

enum type{
    case image
    case text
    case unknown
    case header
    case header2
    case header3
    case header4
    case link
}
struct Link{
    var startText: String? = nil
    var startIndex: Int? = nil
    var linkText: String? = nil
    var endText: String? = nil
    var endIndex: Int? = nil
    var url: URL? = nil
}
struct ElementObject{
    var type: type = .unknown
    var text: String? = nil
    var image: URL? = nil
    var Link: Link? = nil
    init(type: type, text: String? = nil, image: URL? = nil, Link: Link? = nil) {
        self.type = type
        self.text = text
        self.image = image
        self.Link = Link
    }
}
class InterfaceController: WKInterfaceController {
    
    @IBOutlet weak var WebsiteTabel: WKInterfaceTable!
    var superUrl: String? = nil
    var links: [Element] = []
    let html = """
<!DOCTYPE html>
<html>
<head>
    <title>Title of webpage</title>
</head>
<body>
    <p>Test <a href="https://chirpapp.io/roadto100">with a link</a> in the middle</p>
    <p>Is this clickable?</p>
    <p>This should be, but <a href="https://9to5mac.com">seperately</a></p>
    <div>
        <p>Test</p>
    </div>
    <a href="https://9to5mac.com">test link</a>
</body>
</html>
"""
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        if let url = context as? URL{
            self.superUrl = url.absoluteString
        }
        // Configure interface objects here.
        // self.fetchWebsite(fromUrl: URL(string: superUrl)!)
        if let superUrl = superUrl{
            self.fetchWebsite(fromUrl: URL(string: superUrl)!)
        } else {
            //self.fetchWebsite(fromUrl: URL(string: "https://9to5mac.com/2018/09/22/top-20-iphone-xs-and-iphone-xs-max-features-video")!)
            self.processHtml(html: html)
        }
    }
    var elements: [ElementObject] = []
    func processHtml(html: String){
        guard let html = try? SwiftSoup.parse(html) else {return}
        
        guard let children = try? html.getAllElements() else {return}
        
        for element in children{
            switch element.tagName(){
            case "img":
                guard let src = try? element.attr("src") else {return}
                var preposition = (self.superUrl ?? "") + "/"
                if src.contains("http"){
                    preposition = ""
                }
                self.elements.append(ElementObject(type: .image, text: nil, image: URL(string: preposition + src)!))
                
            case "a":
                if self.links.contains(element) {
                    continue
                }
                if let linkText = try? element.text(), let linkHref = try? element.attr("href"){
                    let startIndex = linkText.startIndex.encodedOffset
                    let endIndex = linkText.endIndex.encodedOffset
                    var link = Link(startText: "", startIndex: startIndex, linkText: linkText, endText: "", endIndex: endIndex, url: URL(string: linkHref)!)
                    self.elements.append(ElementObject(type: .link, text: nil, image: nil, Link: link))
                }
                
            case "p":
                var objects: [ElementObject] = []
                guard var text = try? element.text() else {return}
                if let links = try? element.getElementsByTag("a"){
                    var asArray = links.array()
                    if asArray.count == 0{
                        objects.append(ElementObject(type: .text, text: text, image: nil))
                        
                    }
                    for link in asArray{
                        self.links.append(link)
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
                    objects.append(ElementObject(type: .text, text: text, image: nil))
                }
                for element in objects{
                    if element.type == .text{
                        guard let concatenatedText = element.text else {return}
                        self.elements.append(ElementObject(type: .text, text: concatenatedText, image: nil))
                    }
                    if element.type == .link{
                        guard let concatenatedText = element.text else {return}
                        guard let url = element.image else {return}
                        self.elements.append(ElementObject(type: .link, text: concatenatedText, image: url))
                    }
                }
            case "h1":
                guard let text = try? element.text() else {return}
                self.elements.append(ElementObject(type: .header, text: text, image: nil))
            case "h2":
                guard let text = try? element.text() else {return}
                self.elements.append(ElementObject(type: .header, text: text, image: nil))
            case "h3":
                guard let text = try? element.text() else {return}
                self.elements.append(ElementObject(type: .header, text: text, image: nil))
            case "h4":
                guard let text = try? element.text() else {return}
                self.elements.append(ElementObject(type: .header, text: text, image: nil))
            default:
                print()
            }
            
            
        }
        for (index, element) in self.elements.enumerated(){
            switch element.type{
            case .image:
                if let imgUrl = element.image{
                    self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "ImageCell")
                    if let row = self.WebsiteTabel.rowController(at: index) as? ImageCell{
                        if imgUrl.absoluteString.hasSuffix(".gif"){
                            let gif = UIImage.gifImageWithURL(imgUrl.absoluteString)
                            row.cellImage.setImage(gif)
                            row.cellImage.startAnimating()
                        } else {
                            URLSession.shared.dataTask(with: imgUrl, completionHandler: {data, _, _ in
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
