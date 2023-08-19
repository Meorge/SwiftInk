//
//  File.swift
//  
//
//  Created by Malcolm Anderson on 8/18/23.
//

import Foundation

/// Contains all story state information,
/// including global variables, read counts, the pointer to the current
/// point in the story, the call stack (for tunnels, functions, etc),
/// and a few other smaller bits and pieces. You can save the current
/// state using the JSON serialisation functions `ToJson` and `LoadJson`.
public class StoryState {
    
    // Backwards compatible changes since v8:
    // v10: dynamic tags
    // v9: multi-flows
    /// The current version of the state save file JSON-based format.
    public let kInkSaveStateVersion = 10
    let kMinCompatibleLoadVersion = 8
    
    /// Callback for when a state is loaded
    public var onDidLoadState: (() -> Void)?
    
    // TODO: ToJson()
    /// Exports the current state to JSON format, in order to save the game,
    /// and returns it as a string.
    /// - Returns: The save state in JSON format.
    public func ToJson() -> String {
        return ""
    }
    
    // TODO: ToJson()
    /// Exports the current state to JSON format, in order to save the game, and
    /// writes it to the provided stream.
    /// - Parameter stream: The stream to write the JSON string to.
    public func ToJson(_ stream: Stream) {
        
    }
    
    // TODO: LoadJson()
    /// Loads a previously saved state in JSON format.
    /// - Parameter json: The JSON string to load.
    public func LoadJson(_ json: String) {
        
    }
    
    // TODO: VisitCountAtPathString()
    /// Gets the visit/read count of a particular `Container` at the given path.
    ///
    /// For a knot or stitch, the path string will be in the form
    /// ```
    /// knot
    /// knot.stitch
    /// ```
    /// - Parameter pathString: The dot-separated path string of the specific knot or stitch.
    /// - Returns: The number of times the specific knot or stitch has been encountered by the ink engine.
    public func VisitCountAtPathString(_ pathString: String) -> Int {
        return 0
    }
    
    // TODO: VisitCountForContainer()
    public func VisitCountForContainer(_ container: Container) -> Int {
        return 0
    }
}
