import Foundation
import SwiftyJSON

public class Choice : Object, CustomStringConvertible {
    /// The main text to present to the player.
    public var text: String?
    
    public var pathStringOnChoice: String {
        get {
            return targetPath!.description
        }
        set {
            targetPath = Path(fromComponentsString: newValue)
        }
    }
    
    public func writeJSON() -> JSON {
        return [
            "text": text!,
            "index": index!,
            "originalChoicePath": sourcePath!,
            "originalThreadIndex": originalThreadIndex!,
            "targetPath": pathStringOnChoice
        ]
    }
    
    /// Get the path to the original choice point - where was this choice defined in the story?
    public var sourcePath: String?
    
    /// The original index into the `currentChoices` list on the `Story` when this `Choice` was generated, for convenience.
    public var index: Int?
    
    public var targetPath: Path?
    
    public var threadAtGeneration: CallStack.Thread?
    public var originalThreadIndex: Int?
    
    public var isInvisibleDefault: Bool?
    
    public var tags: [String]?
    
    public override init() {
    }
    
    public var description: String {
        "Choice(text: \"\(text ?? "nil")\") -> \(pathStringOnChoice)"
    }
}
