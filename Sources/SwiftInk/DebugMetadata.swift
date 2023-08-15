//
//  File.swift
//  
//
//  Created by Malcolm Anderson on 8/15/23.
//

import Foundation

public class DebugMetadata: CustomStringConvertible {
    public var startLineNumber = 0
    public var endLineNumber = 0
    public var startCharacterNumber = 0
    public var endCharacterNumber = 0
    public var fileName: String? = nil
    public var sourceName: String? = nil
    
    public init() {
        
    }
    
    public func Merge(_ dm: DebugMetadata) -> DebugMetadata {
        var newDebugMetadata = DebugMetadata()
        
        // These are not supposed to differ between 'self' and 'dm'
        newDebugMetadata.fileName = fileName
        newDebugMetadata.sourceName = sourceName
        
        if startLineNumber < dm.startLineNumber {
            newDebugMetadata.startLineNumber = startLineNumber
            newDebugMetadata.startCharacterNumber = startCharacterNumber
        }
        else if startLineNumber > dm.startLineNumber {
            newDebugMetadata.startLineNumber = dm.startLineNumber
            newDebugMetadata.startCharacterNumber = dm.startCharacterNumber
        }
        else {
            newDebugMetadata.startLineNumber = startLineNumber
            newDebugMetadata.startCharacterNumber = min(startCharacterNumber, dm.startCharacterNumber)
        }
        
        
        if endLineNumber > dm.endLineNumber {
            newDebugMetadata.endLineNumber = endLineNumber
            newDebugMetadata.endCharacterNumber = endCharacterNumber
        }
        else if endLineNumber < dm.endLineNumber {
            newDebugMetadata.endLineNumber = dm.endLineNumber
            newDebugMetadata.endCharacterNumber = dm.endCharacterNumber
        }
        else {
            newDebugMetadata.endLineNumber = endLineNumber
            newDebugMetadata.endCharacterNumber = max(endCharacterNumber, dm.endCharacterNumber)
        }
        
        return newDebugMetadata
    }
    
    public var description: String {
        if fileName != nil {
            return "line \(startLineNumber) of \(fileName!)"
        }
        
        return "line \(startLineNumber)"
    }
}
