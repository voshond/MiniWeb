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
    
    //Yeah I spelt 'table' wrong, so what?
    @IBOutlet weak var WebsiteTabel: WKInterfaceTable!
    
    //This array lists classes which the article detector will ignore
    var forbiddenClasses: [String] = ["header-module__inner", "brand brand--9News"]
    
    //The top most URL (useful for sites which links to images like '/image.png' and not 'thewebsite/image.png'
    var parentUrl: String? = nil
    
    //A string of all the text on the page so users with VoiceOver can still use it.
    var accessibilityWebsiteContents: String? = nil
    
    //A list of elements already processed. This is used to prevent duplicate elements.
    var processedElements: [Element] = []
    
    //All elements
    var elements: [ElementObject] = []
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        //If the Interface Controller was instantiated with a URL
        if let url = context as? URL{
            self.parentUrl = url.absoluteString
            self.fetchWebsite(fromUrl: url)
            self.parentUrl = url.host ?? ""
        }
        
        //Or if it was passed a string
        if let url = context as? String{
            if url == "localTest"{
                let testUrl = URL(string: "https://www.news.com.au/world/north-america/dramatic-firing-proof-trump-is-in-panic-mode-over-russia-probe/news-story/672ac00312e5ef2787c304fc8f9ebcbc")!
                self.fetchWebsite(fromUrl: testUrl)
            
                self.parentUrl = testUrl.host ?? ""
//                guard let htmlFile = Bundle.main.path(forResource: "TestHtml", ofType: "html") else {return}
//
//                if let htmlContents = try? String(contentsOf: URL(fileURLWithPath: htmlFile), encoding: String.Encoding.utf8){
//                    self.processHtml(html: htmlContents)
//
//                }
//            }
        }
        
        }
    }
    
    //Article Detector
    //This function takes an element and attmepts to determine whether or not the element contains an article
    //1. Eensures it is a <div>
    //2. See if the character count is above 2000 (roughly 400 word article)
    //3. See if the <div> class is forbidden or not
    //4. Checks if the <div> contains a header
    func isValidDiv(element: Element) -> Bool{
        //1
        if !(element.tagName() == "div"){
            return false
        }
        //2
        if !(((try? element.text()) ?? "").count > 2000){
            return false
        }
        //3
        if forbiddenClasses.contains((try? element.className()) ?? ""){
            return false
        }
        guard let allElements = try? element.getAllElements() else {return false}
        //4
        return allElements.contains(where: {
            $0.tagName() == "h"  ||
                $0.tagName() == "h1" ||
                $0.tagName() == "h2" ||
                $0.tagName() == "h3" ||
                $0.tagName() == "h4" ||
                $0.tagName() == "h5" ||
                $0.tagName() == "h6"
        })
    }
    func processHtml(html: String){
        //Convert the String into a Document
        guard let html = try? SwiftSoup.parse(html) else {return}

        //If a title exists, create a ElementObject of type title, and then add a seperator
        if let title = try? html.title() {
            elements.append(ElementObject(type: .title, text: title))
            elements.append(ElementObject(type: .seperator))
            
        }
        //Get all elements on the page
        guard var children = try? html.getAllElements() else {return}
        
        //Checks for an article
        if let div = children.first(where: {isValidDiv(element: $0)}){
            //If an article is found, get all the elements
            if let allElemnents = try? div.getAllElements(){
                //Overwrite the list of elements with only the articles contents
                children = allElemnents
            }
        }
        
        //Iterate over every element and process it
        for element in children{
            //If the element has already been processed, skip it
            if self.processedElements.contains(element) {
                continue
            }
            //Add the element to the processed elements array
            self.processedElements.append(element)
            switch element.tagName(){
            case "img":
                //Find the image in the element
                let image = Image.findImages(in: element, withSuperUrl: self.parentUrl)
                //Append the image to the elements array
                self.elements.append(ElementObject(type: .image, image: image))
            case "b":
                let text = element.ownText()
                //Find any links in the element
                let objects = self.findLinksIn(element: element, withText: text, withType: .bold)
                //Process the response. If the element contains a link, it'll be converted to a regular text object with a link, otherwise it will remain as its type.
                self.processObjects(objects: objects, withParentType: .bold)
            case "br":
                self.elements.append(ElementObject(type: .lineBreak))
            case "q", "blockquote":
                self.elements.append(ElementObject(type: .quote, text: element.ownText()))
            case "caption", "figcaption":
                self.elements.append(ElementObject(type: .caption, text: element.ownText()))
            case "a":
                //If a links text can be found as well as the href, begin processing it
                if let linkText = try? element.text(), let linkHref = try? element.attr("href"){
                    //Get the index of the start of the link (should always be 0)
                    let startIndex = linkText.startIndex.encodedOffset
                    //Get the end indx
                    let endIndex = linkText.endIndex.encodedOffset
                    //Set the URL preposition to the parentUrl with a trailing slash
                    var preposition = (self.parentUrl ?? "") + "/"
                    //If the link is a direct link (ie: contains http), use no preposition
                    if linkHref.contains("http"){
                        preposition = ""
                    }
                    //If the link is a Javascript link, ignore it.
                    if linkHref == "#"{
                        continue
                    }
                    let linkUrl = URL(string: preposition + linkHref)
                    let link = Link(startText: "", startIndex: startIndex, linkText: linkText, endText: "", endIndex: endIndex, url: linkUrl)
                    self.elements.append(ElementObject(type: .link, Link: link))
                }
            case "hr":
                self.elements.append(ElementObject(type: .seperator))
            case "p":
                let text = element.ownText()
                if ((try? element.className()) ?? "").contains("caption"){ //If the class contains "caption", treat it like a caption and not text
                    self.elements.append(ElementObject(type: .caption, text: element.ownText()))
                    continue
                }
                let objects = self.findLinksIn(element: element, withText: text, withType: .text)
                self.processObjects(objects: objects, withParentType: .text)
            
            case "h", "h1":
                 let text = element.ownText()
                let objects = self.findLinksIn(element: element, withText: text, withType: .header)
                self.processObjects(objects: objects, withParentType: .header)
            case "h2":
                 let text = element.ownText()
                let objects = self.findLinksIn(element: element, withText: text, withType: .header2)
                self.processObjects(objects: objects, withParentType: .header2)
            case "h3":
                 let text = element.ownText()
                let objects = self.findLinksIn(element: element, withText: text, withType: .header3)
                self.processObjects(objects: objects, withParentType: .header3)
            case "h4":
                 let text = element.ownText()
                let objects = self.findLinksIn(element: element, withText: text, withType: .header4)
                self.processObjects(objects: objects, withParentType: .header4)
            default:
                print()
            }
            
            
        }
        self.setupPage(withElements: self.elements)
        
        
    }
    func setupPage(withElements elements: [ElementObject]){
        for (index, element) in elements.enumerated(){
            switch element.type{
            case .title:
                if let text = element.text{
                    //Create a title row
                    self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "TitleCell")
                    if let row = self.WebsiteTabel.rowController(at: index) as? TextCell{
                        //Set the text
                        row.cellText.setText(text)
                    }
                }
                
            case .seperator:
                self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "SeperatorCell")
                
                
            case .image:
                if let image = element.image, let imageURL = image.imageURL{
                    //Create an image row
                    self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "ImageCell")
                    if let row = self.WebsiteTabel.rowController(at: index) as? ImageCell{
                        //If the height of the image is specified, set the height to prevent text jumping aorund
                        if let imageHeight = image.height{
                            row.cellImage.setHeight(imageHeight)
                        }
                        //If the URL is a GIF, treat it as such
                        if imageURL.absoluteString.hasSuffix(".gif"){
                            let gif = UIImage.gifImageWithURL(imageURL.absoluteString)
                            row.cellImage.setImage(gif)
                            row.cellImage.startAnimating()
                        } else { //Otherwise
                            URLSession.shared.dataTask(with: imageURL, completionHandler: {data, _, _ in
                                guard let data = data else {return}
                                //If the data returned is valid, create a UIImage from it and set the image in the row.
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
                    //If the link is part of a paragrah it may have text before and after it.
                    guard let startText = link.startText, let linkText = link.linkText, let endtext = link.endText else {return}
                    //Create a attributed string of the link as well as any leading or trailing text.
                    let mutedText = NSMutableAttributedString(string: startText + linkText + endtext)
                    //Set the actual link part of the 'link' to blue.
                    mutedText.addAttributes([
                        NSAttributedString.Key.foregroundColor: UIColor(red:0.11, green:0.63, blue:0.95, alpha:1.0)], range: NSRange(location: link.startIndex!, length: linkText.count))
                    //Create a link row
                    self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "LinkCell")
                    if let row = self.WebsiteTabel.rowController(at: index) as? LinkCell{
                        row.linkText.setAttributedText(mutedText)
                        //Assign the URL of the row so it can be tapped
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
        //Attempt to find any links
        if let links = try? element.getElementsByTag("a"){
            let asArray = links.array()
            if asArray.count == 0{
                //if there is none, take the text that was passed in and create a object of the passed type
                objects.append(ElementObject(type: type, text: text))
            }
            for link in asArray{
                //Add the link to the process elements array to prevent duplicates
                self.processedElements.append(link)
                if let linkText = try? link.text(), let linkHref = try? link.attr("href"){
                    //Take the index that the linkText starts at in the regular text
                    if let startIndex = text.index(of: linkText){
                        //Find where it finishes
                        let endIndex = startIndex + linkText.count
                        //Take all the text from before the link begins
                        let beforeLink = text[0 ..< startIndex]
                        var afterLink = ""
                        if linkText.count == endIndex{
                            
                        } else {
                            //Checks is the upper bound (text.count - 1) is greater than the lower bound (endIndex), if it is return "", else return the difference
                            //Take all the text from after the link ends
                            afterLink = (text.count - 1) > endIndex ? text[endIndex ... (text.count - 1)] : ""
                            
                            
                        }
                        //Create a link object
                        let link = Link(startText: beforeLink, startIndex: startIndex, linkText: linkText, endText: afterLink, endIndex: (text.count - 1), url: URL(string: linkHref)!)
                        self.elements.append(ElementObject(type: .link, Link: link))
                        
                    }
                    
                    
                }
            }
        } else {
            //No links were found, just create a ElementObject with the passed text and type.
            objects.append(ElementObject(type: type, text: text))
        }
        //Return all text and or link objects
        return objects
    }
    func processObjects(objects: [ElementObject], withParentType type: ElementType){
        for element in objects{
            if element.type == type{
                guard let concatenatedText = element.text else {return}
                self.elements.append(ElementObject(type: type, text: concatenatedText))
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
            //Convert the returned data to a String
            guard let responseString = String(data: data, encoding: String.Encoding.utf8) else {return}
            
            //Begin processing it
            self.processHtml(html: responseString)
            
        }).resume()
    }
    
    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        if let row = self.WebsiteTabel.rowController(at: rowIndex) as? LinkCell{
            //If a URL can be found in the row, load the linkViewer (self) and begin loading the URL
            if let url = row.url{
                self.pushController(withName: "linkViewer", context: url)
            }
        }
    }
    
}

//Here be dragons (aka code from StackOverflow)

extension String{
    func index(of target: String) -> Int? {
        if let range = self.range(of: target) {
            return self.distance(from: startIndex, to: range.lowerBound)
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
        guard let bundleURL: URL = URL(string: gifUrl)
            else {
                print("image named \"\(gifUrl)\" doesn't exist")
                return nil
        }
        guard let imageData = try? Data(contentsOf: bundleURL) else {
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
