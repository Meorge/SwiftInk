import Foundation

public class VariablesState: Sequence {
    public typealias VariableChanged = (_ variableName: String, _ newValue: Object) -> Void
    public var variableChangedEvent: VariableChanged?
    
    public var patch: StatePatch?
    
    // TODO: Fill out
    public var batchObservingVariableChanges: Bool {
        get {
            
        }
        set {
            
        }
    }
    
    var _batchObservingVariableChanges: Bool = false
    
    // Allow StoryState to change the current callstack, e.g. for
    // temporary function evaluation.
    public var callStack: CallStack? {
        get {
            return _callStack
        }
        set {
            _callStack = newValue
        }
    }
    
    public subscript(_ variableName: String) -> Any? {
        get {
            if let varContents = patch!.globals[variableName] {
                if let varValue = varContents as? (any BaseValue) {
                    // TODO: what to do here???
                }
            }
//
//            // Search main dictionary first.
//            // If it's not found, it might be because the story content has changed,
//            // and the original default value hasn't be instantiated (???)
//            // Should really warn somehow, but it's difficult to see how...!
//            if let varContents = _globalVariables[variableName] {
//                return (varContents as! BaseValue).value
//            }
//            if let varContents = _defaultGlobalVariables[variableName] {
//                return (varContents as! BaseValue).value
//            }
            return nil
        }
    }
    
    public func SetGlobalVariable(_ variableName: String, _ newValue: Any?) throws {
        if !_defaultGlobalVariables.keys.contains(variableName) {
            throw StoryError.cannotAssignToUndeclaredVariable(name: variableName)
        }
        
        var val = CreateValue(newValue)
        if val == nil {
            if newValue == nil {
                throw StoryError.cannotPassNilToVariableState
            }
            else {
                throw StoryError.invalidValuePassedToVariableState(value: newValue)
            }
            
        }
        
        SetGlobal(variableName, val)
    }
    
    /// Iterator to allow iteration over all global variables by name.
    public func makeIterator() -> Dictionary<String, Object>.Keys.Iterator {
        return _globalVariables.keys.makeIterator()
    }
    
    // TODO: init
    
    // TODO: ApplyPatch
    
    // TODO: SetJsonToken
    
    // TODO: dontSaveDefaultValues
    
    // TODO: WriteJson
    
    // TODO: RuntimeObjectsEqual
    
    // TODO: GetVariableWithName
    
    // TODO: TryGetDefaultVariableValue
    
    // TODO: GlobalVariableExistsWithName
    
    // TODO: GetVariableWithName
    
    // TODO: GetRawVariableWithName
    
    // TODO: ValueAtVariablePointer
    
    // TODO: Assign
    
    // TODO: SnapshotDefaultGlobals
    
    // TODO: RetainListOriginsForAssignment
    
    // TODO: SetGlobal
    
    // TODO: ResolveVariablePointer
    
    // TODO: GetContextIndexOfVariableNamed
    
    var _globalVariables: [String: Object] = [:]
    
    var _defaultGlobalVariables: [String: Object] = [:]
    
    // Used for accessing temporary variables
    var _callStack: CallStack?
    var _changedVariablesForBatchObs: Set<String>?
    var _listDefsOrigin: ListDefinitionsOrigin?
}
