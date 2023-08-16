//
//  File.swift
//  
//
//  Created by Malcolm Anderson on 8/15/23.
//

import Foundation

public class Choice : Object {
    /// The main text to present to the player.
    public var text: String
    
    public var pathStringOnChoice: String {
        get {
            return String(describing: targetPath)
        }
        set {
            targetPath = Path(newValue)
        }
    }
    
    /// Get the path to the original choice point - where was this choice defined in the story?
    public var sourcePath: String
    
    /// The original index into the `currentChoices` list on the `Story` when this `Choice` was generated, for convenience.
    public var index: Int
    
    public var targetPath: Path
    
    public var threadAtGeneration: CallStack.Thread
    public var originalThreadIndex: Int
    
    public var isInvisibleDefault: Bool
    
    public var tags: [String]
    
    public override init() {
        
    }
}
