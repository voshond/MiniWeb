//
//  LinkCell.swift
//  PseudoWeb WatchKit Extension
//
//  Created by Will Bishop on 24/9/18.
//  Copyright © 2018 Will Bishop. All rights reserved.
//

import Foundation
import WatchKit

class LinkCell: NSObject{
    
    @IBOutlet weak var linkText: WKInterfaceLabel!
    var url: URL?
}
