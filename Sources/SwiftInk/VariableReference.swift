import Foundation

public class VariableReference: Object {
    // Normal named variable
    public var name: String?
    
    // Variable reference is actually a path for a visit (read) count
    public var pathForCount: Path?
    
    public var containerForCount: Container? {
        guard pathForCount != nil else {
            return nil
        }
        return ResolvePath(pathForCount!)?.container
    }
    
    public var pathStringForCount: String? {
        get {
            if pathForCount == nil {
                return nil
            }
            return CompactPathString(pathForCount!)
        }
        set {
            if newValue == nil {
                pathForCount = nil
            }
            else {
                pathForCount = Path(newValue!)
            }
        }
    }
    
    public init(_ name: String?) {
        self.name = name
    }
    
    // Require default constructor for serialisation
    // (will this be necessary for Swift version?)
    public override init() {
    }
    
    public var description: String {
        if name != nil {
            return "var(\(name!))"
        }
        else {
            return "read_count(\(pathStringForCount!))"
        }
    }
}
