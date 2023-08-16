//
//  File.swift
//  
//
//  Created by Malcolm Anderson on 8/16/23.
//

import Foundation

public class Tag: Object, CustomStringConvertible {
    private(set) var text: String
    
    public init(text: String) {
        self.text = text
        super.init()
    }
    
    public var description: String {
        "# \(text)"
    }
}
