//
//  TestHtml.swift
//  PseudoWeb WatchKit Extension
//
//  Created by Will Bishop on 8/11/18.
//  Copyright © 2018 Will Bishop. All rights reserved.
//

import Foundation

class TestHtml{
    static let html = """
<!DOCTYPE html>
<html>
<head>
    <title>Title of webpage</title>
</head>
<body>
    <p>Regular text</p>
    <br>
    <br>
    <br>
    <br>
    <p>Test <a href="http://chirpapp.io/roadto100">with a link</a> in the middle</p>
    <a href="https://9to5mac.com">Link on its own</a>
    <q>This is a quote that should span multiple lines</q>
    <img src="http://chirpapp.io/roadto100/DraggedImage-3.png" width="1960" height="636">
    <figcaption>The above image shows an issue</figcaption>
    <b>Test Bold</b>
    <h>Header 1</h>
    <h2>Header 2</h2>
    <h3>Header 3</h3>
    <h4>Header 4</h4>
</body>
</html>
"""
}
