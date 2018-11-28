//
//  NetworkManager.swift
//  MiniWeb
//
//  Created by Will Bishop on 26/11/18.
//  Copyright © 2018 Will Bishop. All rights reserved.
//

import Foundation

enum NetworkFailure: Error{
    case failed(_ reason: String)
}

class NetworkManager{
    
    //Custom User-Agent
    static var userAgent: String? = nil
    
    static func fetchWebsite(fromUrl url: URL, returnString: @escaping (_ result: String) -> Void, handleError: @escaping (_: NetworkFailure) -> Void){
        var request = URLRequest(url: url)
        if let customUserAgent = self.userAgent{
            request.setValue(customUserAgent, forHTTPHeaderField: "User-Agent")
        }
        
        URLSession.shared.dataTask(with: request, completionHandler: {data, response, error in
            if let error = error{
                handleError(NetworkFailure.failed(error.localizedDescription))
            }
            guard let data = data else {return}
            //Convert the returned data to a String
            guard let responseString = String(data: data, encoding: String.Encoding.utf8) else {return}
            
            //Begin processing it
            returnString(responseString)
        }).resume()
        
    }
}
