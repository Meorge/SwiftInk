import Foundation

public class StatePatch {
    public var globals: [String: Object] {
        _globals
    }
    
    public var changedVariables: Set<String> {
        _changedVariables
    }
    
    public var visitCounts: [Container: Int] {
        _visitCounts
    }
    
    public var turnIndices: [Container: Int] {
        _turnIndices
    }
    
    public init(_ toCopy: StatePatch?) {
        if toCopy != nil {
            _globals = toCopy!._globals
            _changedVariables = toCopy!._changedVariables
            _visitCounts = toCopy!._visitCounts
            _turnIndices = toCopy!._turnIndices
        }
        else {
            _globals = [:]
            _changedVariables = Set()
            _visitCounts = [:]
            _turnIndices = [:]
        }
    }
    
    public func SetGlobal(_ name: String, _ value: Object) {
        _globals[name] = value
    }
    
    var _globals: [String: Object] = [:]
    var _changedVariables: Set<String> = Set()
    var _visitCounts: [Container: Int] = [:]
    var _turnIndices: [Container: Int] = [:]
}
