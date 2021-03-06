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


enum NetworkStatus{
    case loading
    case loaded
    case failed(_ reason: String?)
    case unknown
}

class MiniWebController: WKInterfaceController {
    
    //Yeah I spelt 'table' wrong, so what?
    @IBOutlet weak var WebsiteTabel: WKInterfaceTable!
    @IBOutlet weak var loadingIndicator: WKInterfaceImage!
    @IBOutlet weak var loadFailedLabel: WKInterfaceLabel!
    @IBOutlet weak var indicatorGroup: WKInterfaceGroup!
    
    //List of row types
    var rowTypes: [String] = ["TitleCell", "SeperatorCell", "ImageCell", "LinebreakCell", "CaptionCell", "QuoteCell", "Header", "Header2", "Header3", "Header4", "LinkCell", "BoldCell"]
    
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
    
    //Lets '#something' adresses work
    var addressLookup: [String: Int] = [:]
    
    //Contents before fancy article detection
    var originalContents = Elements()
    var originalHtml: String? = nil
    
    
    var networkStatus: NetworkStatus = .unknown {
        didSet{
            switch networkStatus{
            case .loading:
                self.indicatorGroup.setHidden(false)
                self.loadingIndicator.setImageNamed("Activity")
                self.loadingIndicator.setHeight(35)
                self.loadingIndicator.setWidth(35)
                self.loadingIndicator.startAnimating()
                self.loadFailedLabel.setHidden(true)
            case .failed(let reason):
                self.indicatorGroup.setHidden(false)
                self.loadFailedLabel.setText(reason)
                self.loadingIndicator.setImageNamed("Error")
                self.loadingIndicator.setHeight(50)
                self.loadingIndicator.setWidth(50)
                self.loadFailedLabel.setHidden(false)
                
                
            case .loaded:
                self.indicatorGroup.setHidden(true)
                self.loadingIndicator.stopAnimating()
                self.WebsiteTabel.setHidden(false)
                
                self.loadFailedLabel.setHidden(true)
            case .unknown:
                print()
            }
        }
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        //If the Interface Controller was instantiated with a URL
        if let url = context as? URL{
            self.fetchWebsite(fromUrl: url)
            self.parentUrl =  (url.absoluteString.starts(with: "http") ? "" : "http://") + (url.absoluteString)
            self.setTitle(url.host)
            
        }
        
        //Or if it was passed a string
        if let url = context as? String{
            if url == "localTest"{
                let testUrl = URL(string: "https://9to5mac.com/2018/12/04/directv-hulu-pause-ads/")!
                self.fetchWebsite(fromUrl: testUrl)
                self.setTitle(testUrl.host)
                self.parentUrl =  (testUrl.absoluteString.starts(with: "http") ? "" : "http://") + (testUrl.absoluteString)
//                                guard let htmlFile = Bundle.main.path(forResource: "TestHtml", ofType: "html") else {return}
//
//                                if let htmlContents = try? String(contentsOf: URL(fileURLWithPath: htmlFile), encoding: String.Encoding.utf8){
//                                    self.processHtml(html: htmlContents)
//
//                                }
            }
        }
        
        
    }
    
    /*
     Article Detector
     This function takes an element and attmepts to determine whether or not the element contains an article
     2. Ensures it is a <div>
     3. See if the character count is above 2000 (roughly 400 word article)
     4. See if the <div> class is forbidden or not
     5. Checks if the <div> contains a header
     */
    func isValidArticle(element: Element) -> Bool{
        
        if (try? element.className()) == "article" || element.tagName() == "article"{
            return true
        }
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
        guard let allElements = try? element.children() else {return false}
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
        self.originalHtml = html
        guard let html = try? SwiftSoup.parse(html) else {return}
        //If a title exists, create a ElementObject of type title, and then add a seperator
        if let title = try? html.title() {
            elements.append(ElementObject(type: .title, text: title))
            elements.append(ElementObject(type: .seperator))
            
        }
        //Get all elements on the page
        guard var children = try? html.getAllElements() else {return}
        self.originalContents = children
        //Checks for an article
        
        if let article = children.first(where: {isValidArticle(element: $0)}){
            self.addMenuItem(with: WKMenuItemIcon.resume, title: "View Entire Page", action: #selector(viewWithoutDetection))
            //If an article is found, get all the elements
            if let allElemnents = try? article.getAllElements(){
                //Overwrite the list of elements with only the articles contents
                children = allElemnents
            }
        }
        
        //Iterate over every element and process it
        self.processObjects(objects: children)
        self.setupPage(withElements: self.elements)
        
        
    }
    @objc func viewAsArticle(){
        guard let html = self.originalHtml else {return}
        self.clearAllMenuItems()
        self.processedElements.removeAll()
        self.elements.removeAll()
        self.addressLookup.removeAll()
        self.removeAllRows()
        self.processHtml(html: html)
        
    }
    func removeAllRows(){
        for type in rowTypes{
            self.WebsiteTabel.setNumberOfRows(0, withRowType: type)
        }
    }
    @objc func viewWithoutDetection(){
        self.clearAllMenuItems()
        self.addMenuItem(with: .repeat, title: "View As Article" , action: #selector(viewAsArticle))
        self.processedElements.removeAll()
        self.elements.removeAll()
        self.addressLookup.removeAll()
        self.removeAllRows()
        self.processObjects(objects: self.originalContents)
        self.setupPage(withElements: self.elements)
    }
    func processObjects(objects: Elements){
        var nextId: String? = nil
        for element in objects{
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
                self.elements.append(ElementObject(type: .image, image: image, id: nextId))
                nextId = nil
            case "b":
                let text = element.ownText()
                //Find any links in the element
                let objects = self.findLinksIn(element: element, withText: text, withType: .bold)
                //Process the response. If the element contains a link, it'll be converted to a regular text object with a link, otherwise it will remain as its type.
                self.processObjects(objects: objects, withParentType: .bold, nextId: nextId)
                nextId = nil
            case "br":
                self.elements.append(ElementObject(type: .lineBreak))
            case "q", "blockquote":
                self.elements.append(ElementObject(type: .quote, text: element.ownText(), id: nextId))
                nextId = nil
            case "caption", "figcaption":
                self.elements.append(ElementObject(type: .caption, text: element.ownText(), id: nextId))
                
                nextId = nil
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
                    if linkHref.contains("http") || linkHref.starts(with: "#"){
                        preposition = ""
                    }
                    //If the link is a Javascript link, ignore it.
                    if linkHref == "#"{
                        continue
                    }
                    let linkUrl = URL(string: preposition + linkHref)
                    let link = LinkType(startText: "", startIndex: startIndex, linkText: linkText, endText: "", endIndex: endIndex, url: linkUrl)
                    self.elements.append(ElementObject(type: .link, Link: link, id: nextId))
                    nextId = nil
                }
            case "hr":
                self.elements.append(ElementObject(type: .seperator, id: nextId))
                nextId = nil
            case "p":
                guard let text = try? element.text() else {continue}
                if ((try? element.className()) ?? "").contains("caption") ||
                    element.parent()?.tagName().contains("caption") ?? false { //If the class (or parent tag) contains "caption", treat it like a caption and not text
                    self.elements.append(ElementObject(type: .caption, text: element.ownText()))
                    continue
                }
                if element.parent()?.tagName().contains("quote") ?? false{
                    self.elements.append(ElementObject(type: .quote, text: text))
                    continue
                }
                let objects = self.findLinksIn(element: element, withText: text, withType: .text)
                self.processObjects(objects: objects, withParentType: .text, nextId: nextId)
                
                
            case "h", "h1":
                let text = element.ownText()
                let objects = self.findLinksIn(element: element, withText: text, withType: .header)
                self.processObjects(objects: objects, withParentType: .header, nextId: nextId)
                nextId = nil
            case "h2":
                let text = element.ownText()
                let objects = self.findLinksIn(element: element, withText: text, withType: .header2)
                self.processObjects(objects: objects, withParentType: .header2, nextId: nextId)
                nextId = nil
            case "h3":
                let text = element.ownText()
                let objects = self.findLinksIn(element: element, withText: text, withType: .header3)
                self.processObjects(objects: objects, withParentType: .header3, nextId: nextId)
                nextId = nil
            case "h4":
                let text = element.ownText()
                let objects = self.findLinksIn(element: element, withText: text, withType: .header4)
                self.processObjects(objects: objects, withParentType: .header4, nextId: nextId)
                nextId = nil
            case "pre":
                guard let text = try? element.text() else {continue}
                let object = ElementObject(type: .code, text: text)
                self.processObjects(objects: [object], withParentType: .code, nextId: nextId)
                nextId = nil
            case "div":
                let id = element.id()
                if id.count > 0{
                    nextId = id
                }
                
            default:
                print()
            }
            
            
        }
    }
    func setupPage(withElements elements: [ElementObject]){
        for (index, element) in elements.enumerated(){
            if let id = element.id{
                self.addressLookup["#" + id] = index
            }
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
                            row.cellImage?.setHeight(imageHeight)
                        }
                        //If the URL is a GIF, treat it as such
                        if imageURL.absoluteString.hasSuffix(".gif"){
                            let gif = UIImage.gifImageWithURL(imageURL.absoluteString)
                            row.cellImage?.setImage(gif)
                            row.cellImage?.startAnimating()
                        } else { //Otherwise
                            URLSession.shared.dataTask(with: imageURL, completionHandler: {data, _, _ in
                                row.cellImage?.setImageData(data)
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
                    
                    //Set the entire text part to white, so it still appears as a link in the storyboard
                    mutedText.addAttributes([
                        NSAttributedString.Key.foregroundColor: UIColor.white
                        ], range:
                        NSRange(location: 0, length: (startText + linkText + endtext).count)
                    )
                    //Set the actual link part of the 'link' to blue.
                    mutedText.addAttributes([
                        NSAttributedString.Key.foregroundColor: UIColor(red:0.11, green:0.63, blue:0.95, alpha:1.0)
                    ], range:
                        NSRange(location: link.startIndex!, length: linkText.count)
                    )
                    //Create a link row
                    self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "LinkCell")
                    if let row = self.WebsiteTabel.rowController(at: index) as? LinkCellWeb{
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
            case .code:
                if let text = element.text{
                    self.WebsiteTabel.insertRows(at: IndexSet(index ... index), withRowType: "CodeCell")
                    if let row = self.WebsiteTabel.rowController(at: index) as? TextCell{
                        row.cellText.setText(text)
                    }
                }
            }
        }
        self.networkStatus = .loaded
    }
    func findLinksIn(element: Element, withText text: String, withType type: ElementType) -> [ElementObject]{
        var objects = [ElementObject]()
        //Attempt to find any links
        if let links = try? element.getElementsByTag("a").array(){
            if links.count == 0{
                //if there is none, take the text that was passed in and create a object of the passed type
                objects.append(ElementObject(type: type, text: text))
            }
            for (index, link) in links.enumerated(){
                
                //Add the link to the process elements array to prevent duplicates
                self.processedElements.append(link)
                if let linkText = try? link.text(), let linkHref = try? link.attr("href"){
                    //Take the index that the linkText starts at in the regular text
                    if var startIndex = text.index(of: linkText){
                        //Find where it finishes
                        let endIndex = startIndex + linkText.count
                        //Take all the text from before the link begins
                        var beforeLink = text[0 ..< startIndex]
                        var afterLink = ""
                        if !(linkText.count == endIndex){
                            //Checks is the upper bound (text.count - 1) is greater than the lower bound (endIndex), if it is return "", else return the difference
                            //Take all the text from after the link ends
                            
                            afterLink = (text.count - 1) > endIndex ? text[endIndex ... (text.count - 1)] : ""
                        }
                        if index == links.endIndex - 1{
                            if let previousLink = objects.last?.Link{
                                if let oldEndIndex = previousLink.endIndex{
                                    beforeLink = text[oldEndIndex ... startIndex - 1].replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
                                    if let newStartIndex = text.index(of: linkText){
                                        startIndex = beforeLink.count
                                    }
                                }
                                
                            }
                        } else if links.startIndex != index{
                            beforeLink = ""
                            afterLink = ""
                            if let previousLink = objects.last?.Link{
                                if let oldEndIndex = previousLink.endIndex{
                                    beforeLink = text[oldEndIndex ... startIndex - 1].replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
                                    if let newStartIndex = text.index(of: linkText){
                                        startIndex = beforeLink.count
                                    }
                                }
                                
                            } else {
                                beforeLink = ""
                                startIndex = 0
                                
                            }
                        } else {
                            afterLink = ""
                        }
                        //Create a link object
                        let link = LinkType(startText: beforeLink, startIndex: startIndex, linkText: linkText, endText: afterLink, endIndex: endIndex, url: URL(string: linkHref)!)
                        objects.append(ElementObject(type: .link, Link: link))
                        
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
    func processObjects(objects: [ElementObject], withParentType type: ElementType, nextId: String?){
        for element in objects{
            if element.type == type{
                guard let concatenatedText = element.text else {return}
                self.elements.append(ElementObject(type: type, text: concatenatedText, id: nextId))
            }
            if element.type == .link{
                guard let startIndex = element.Link?.startIndex, let endIndex = element.Link?.endIndex else {return}
                let startText = element.Link?.startText ?? ""
                let linkText = element.Link?.linkText ?? ""
                let endText = element.Link?.endText ?? ""
                let concatenatedText = startText + linkText + endText
                guard let url = element.Link?.url else {return}
                let link = LinkType(startText: startText, startIndex: startIndex, linkText: linkText, endText: endText, endIndex: endIndex, url: url)
                self.elements.append(ElementObject(type: .link, Link: link, id: nextId))
            }
        }
    }
    func fetchWebsite(fromUrl url: URL){
        self.networkStatus = .loading
        NetworkManager.fetchWebsite(fromUrl: url, returnString: {html in
            self.processHtml(html: html)
        }, handleError: { error in
            switch error{
            case .failed(let reason):
                self.networkStatus = .failed(reason)
            }
        })
        
    }
    
    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        if let row = self.WebsiteTabel.rowController(at: rowIndex) as? LinkCellWeb{
            //If a URL can be found in the row, load the linkViewer (self) and begin loading the URL
            if let url = row.url{
                if url.absoluteString.starts(with: "#"){
                    if let index = self.addressLookup[url.absoluteString]{
                        self.WebsiteTabel.scrollToRow(at: index)
                        
                    }
                    
                }   else {
                    self.pushController(withName: "linkViewer", context: url)
                }
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
        guard let bundleURL:URL = URL(string: gifUrl)
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

