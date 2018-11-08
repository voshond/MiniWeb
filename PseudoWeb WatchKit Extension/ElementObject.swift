//
//  ElementObject.swift
//  PseudoWeb WatchKit Extension
//
//  Created by Will Bishop on 8/11/18.
//  Copyright © 2018 Will Bishop. All rights reserved.
//

import Foundation

struct ElementObject{
    var type: ElementType = .unknown
    var text: String? = nil
    var image: Image? = nil
    var Link: Link? = nil
    init(type: ElementType, text: String? = nil, image: Image? = nil, Link: Link? = nil) {
        self.type = type
        self.text = text
        self.image = image
        self.Link = Link
    }
}
