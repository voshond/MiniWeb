//
//  inputController.swift
//  PseudoWeb WatchKit Extension
//
//  Created by Will Bishop on 5/11/18.
//  Copyright © 2018 Will Bishop. All rights reserved.
//

import WatchKit
import Foundation


class inputController: WKInterfaceController {

    @IBOutlet weak var inputButton: WKInterfaceButton!
    var input: String? = nil
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
    }

    @IBAction func editInput() {
        self.presentTextInputController(withSuggestions: ["chirpapp.io"], allowedInputMode: .plain, completion: {result in
            guard let result = result else {return}
            guard let first = result.first else {return}
            guard let input = first as? String else {return}
            self.inputButton.setTitle("www.\(input)")
            self.input = "www.\(input)"
        })
    }

    @IBAction func visitLocalTest() {
        self.pushController(withName: "linkViewer", context: "localTest")
    }
    @IBAction func viewWebsite() {
        guard let input = input else {return}
        if let url = URL(string: "http://\(input)"){
            self.pushController(withName: "linkViewer", context: url)
        }
    }
   
}
