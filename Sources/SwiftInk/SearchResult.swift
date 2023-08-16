import Foundation

public struct SearchResult {
    public var obj: Object? = nil
    public var approximate: Bool = false
    
    public var correctObj: Object? {
        return approximate ? nil : obj!
    }
    
    public var container: Container? {
        return obj as? Container
    }
}
