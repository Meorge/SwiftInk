import Foundation
import SwiftyJSON

public class VariablesState: Sequence {
    public typealias VariableChanged = (_ variableName: String, _ newValue: Object?) throws -> Swift.Void
    
    public class VariablesStateChangeHandler: Equatable, Hashable {
        public static func == (lhs: VariablesStateChangeHandler, rhs: VariablesStateChangeHandler) -> Bool {
            lhs.id == rhs.id
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        let id: UUID
        var onVariableChanged: VariableChanged? = nil
        
        public init(_ onVariableChanged: VariableChanged?) {
            self.id = UUID()
            self.onVariableChanged = onVariableChanged
        }
    }
    
    public var variableChangedEvent: VariableChanged? = nil
    
    
    
    public var patch: StatePatch?
    
    public var batchObservingVariableChanges: Bool {
        _batchObservingVariableChanges
    }
    
    public func startBatchObservingVariableChanges() {
        _changedVariablesForBatchObs = Set<String>()
    }
    
    public func stopBatchObservingVariableChanges() throws {
        _batchObservingVariableChanges = false
        if _changedVariablesForBatchObs != nil {
            for variableName in _changedVariablesForBatchObs! {
                let currentValue = _globalVariables[variableName]!
                try variableChangedEvent?(variableName, currentValue)
            }
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
                    return varValue.valueObject
                }
            }

            // Search main dictionary first.
            // If it's not found, it might be because the story content has changed,
            // and the original default value hasn't be instantiated (???)
            // Should really warn somehow, but it's difficult to see how...!
            if let varContents = _globalVariables[variableName] {
                return (varContents as! (any BaseValue)).valueObject
            }
            if let varContents = _defaultGlobalVariables[variableName] {
                return (varContents as! (any BaseValue)).valueObject
            }
            return nil
        }
    }
    
    public func setGlobalVariable(named variableName: String, to newValue: Any?) throws {
        if !_defaultGlobalVariables.keys.contains(variableName) {
            throw StoryError.cannotAssignToUndeclaredVariable(name: variableName)
        }
        
        let val = createValue(fromAny: newValue)
        if val == nil {
            if newValue == nil {
                throw StoryError.cannotPassNilToVariableState
            }
            else {
                throw StoryError.invalidValuePassedToVariableState(value: newValue)
            }
            
        }
        
        setGlobal(named: variableName, to: val!)
    }
    
    /// Iterator to allow iteration over all global variables by name.
    public func makeIterator() -> Dictionary<String, Object>.Keys.Iterator {
        return _globalVariables.keys.makeIterator()
    }
    
    public init(withCallstack callStack: CallStack, listDefsOrigin: ListDefinitionsOrigin) {
        _globalVariables = [:]
        _callStack = callStack
        _listDefsOrigin = listDefsOrigin
    }
    
    public func applyPatch() {
        if patch == nil {
            return
        }
        
        for namedVar in patch!.globals {
            _globalVariables[namedVar.key] = namedVar.value
        }
        
        if _changedVariablesForBatchObs != nil {
            for name in patch!.changedVariables {
                _changedVariablesForBatchObs?.insert(name)
            }
        }
        
        patch = nil
    }
    
    public func setJSONToken(_ jToken: JSON) throws {
        _globalVariables.removeAll()

        for varVal in _defaultGlobalVariables {
            let loadedToken = jToken[varVal.key]
            if loadedToken.exists() {
                _globalVariables[varVal.key] = try jsonTokenToRuntimeObject(jsonToken: loadedToken)
            }
            else {
                _globalVariables[varVal.key] = varVal.value
            }
        }
    }
    
    /// When saving out JSON state, we can skip saving global values that
    /// remain equal to the initial values that were declared in ink.
    /// This makes the save file (potentially) much smaller assuming that
    /// at least a portion of the globals haven't changed. However, it
    /// can also take marginally longer to save in thecase that the
    /// majority HAVE changed, since it has to compare all globals.
    /// It may also be useful to turn this off for testing worst case
    /// save timing.
    public static var dontSaveDefaultValues = true
    
    public func writeJSON() throws -> JSON {
        var obj = JSON()
        for keyVal in _globalVariables {
            let name = keyVal.key
            let val = keyVal.value
            
            if VariablesState.dontSaveDefaultValues {
                // Don't write out values that are the same as the default global values
                if let defaultVal = _defaultGlobalVariables[name] {
                    if try runtimeObjectsEqual(val, defaultVal) {
                        continue
                    }
                }
            }
            
            obj[name] = writeRuntimeObject(val)
        }
        
        return obj
    }
    
    public func runtimeObjectsEqual(_ obj1: Object, _ obj2: Object) throws -> Bool {
        if type(of: obj1) != type(of: obj2) {
            return false
        }
        
        // Perform equality on int/float/bool manually to avoid boxing
        if let boolVal = obj1 as? BoolValue {
            return boolVal.value == (obj2 as? BoolValue)?.value
        }
        
        if let intVal = obj1 as? IntValue {
            return intVal.value == (obj2 as? IntValue)?.value
        }
        
        if let floatVal = obj1 as? FloatValue {
            return floatVal.value == (obj2 as? FloatValue)?.value
        }
        
        // Other value type (using proper Equals: list, string, divert path)
        if let listVal = obj1 as? ListValue {
            return listVal.value == (obj2 as? ListValue)?.value
        }
        
        if let stringVal = obj1 as? StringValue {
            return stringVal.value == (obj2 as? StringValue)?.value
        }
        
        if let divertVal = obj1 as? DivertTargetValue {
            return divertVal.value == (obj2 as? DivertTargetValue)?.value
        }
        
        throw StoryError.unsupportedRuntimeObjectType(valType: String(describing: type(of: obj1)))
    }
    
    public func getVariable(named name: String?) -> Object? {
        getVariable(named: name!, withContextIndex: -1)
    }
    
    public func globalVariableExists(named name: String) -> Bool {
        return _globalVariables.keys.contains(name) || _defaultGlobalVariables.keys.contains(name)
    }
    
    func getVariable(named name: String, withContextIndex contextIndex: Int) -> Object? {
        var varValue = getRawVariable(named: name, withContextIndex: contextIndex)
        
        // Get value from pointer?
        if let varPointer = varValue as? VariablePointerValue {
            varValue = value(atVariablePointer: varPointer)
        }
        
        return varValue
    }
    
    func getRawVariable(named name: String?, withContextIndex contextIndex: Int) -> Object? {
        // I added this just in case, seems like it would make sense. -- Malcolm
        if name == nil {
            return nil
        }
        
        // 0 context = global
        if contextIndex == 0 || contextIndex == -1 {
            if let varValue = patch?.globals[name!] {
                return varValue
            }
            
            if let varValue = _globalVariables[name!] {
                return varValue
            }
            
            // Getting variables can actually happen during globals set up since you can do
            //   VAR x = A_LIST_ITEM
            // So _defaultGlobalVariables may be nil.
            // We need to do this check though in case a new global is added, so we need to
            // revert to the default globals dictionary since an initial value hasn't yet been set.
            if let varValue = _defaultGlobalVariables[name!] {
                return varValue
            }
            
            if let listItemValue = _listDefsOrigin?.findSingleItemList(withName: name!) {
                return listItemValue
            }
            
        }
        
        // Temporary
        return _callStack?.temporaryVariable(named: name!, atContextIndex: contextIndex)
    }
    
    public func value(atVariablePointer pointer: VariablePointerValue) -> Object? {
        return getVariable(named: pointer.variableName, withContextIndex: pointer.contextIndex)
    }
    
    public func assign(_ varAss: VariableAssignment, value: Object?) {
        var finalValue = value
        var name = varAss.variableName
        var contextIndex = -1
        
        // Are we assigning to a global variable?
        var shouldSetGlobal = varAss.isNewDeclaration ? varAss.isGlobal : globalVariableExists(named: name!)
        
        // Constructing new variable pointer reference
        if varAss.isNewDeclaration {
            if let varPointer = finalValue as? VariablePointerValue {
                finalValue = resolveVariablePointer(varPointer)
                
            }
        }
        
        // Assign to existing variable pointer?
        // Then assign to the variable that the pointer is pointing to by name.
        else {
            // Dereference variable reference to point to
            var existingPointer: VariablePointerValue? = nil
            repeat {
                existingPointer = getRawVariable(named: name!, withContextIndex: contextIndex) as? VariablePointerValue
                if existingPointer != nil {
                    name = existingPointer!.variableName
                    contextIndex = existingPointer!.contextIndex
                    shouldSetGlobal = (contextIndex == 0)
                }
            } while existingPointer != nil
        }
        
        if shouldSetGlobal {
            setGlobal(named: name!, to: value!)
        }
        else {
            _callStack!.setTemporaryVariable(named: name!, to: value, varAss.isNewDeclaration, withContextIndex: contextIndex)
        }
    }
    
    public func snapshotDefaultGlobals() {
        _defaultGlobalVariables = _globalVariables
    }
    
    func retainListOriginsForAssignment(old oldValue: Object?, new newValue: Object?) {
        let oldList = oldValue as? ListValue
        let newList = newValue as? ListValue
        if oldList != nil && newList != nil && newList!.value!.count == 0 {
            newList!.value?.setInitialOriginNames(oldList!.value!.originNames)
        }
    }
    
    public func setGlobal(named variableName: String, to value: Object) {
        var oldValue: Object? = nil
        if let valueFromPatch = patch?.globals[variableName] {
            oldValue = valueFromPatch
        }
        else if let valueFromGlobals = _globalVariables[variableName] {
            oldValue = valueFromGlobals
        }
        
        ListValue.retainListOriginsForAssignment(old: oldValue!, new: value)
        
        if patch != nil {
            patch!.setGlobal(named: variableName, to: value)
        }
        else {
            _globalVariables[variableName] = value
        }
        
        if variableChangedEvent != nil && value == oldValue {
            
        }
    }
    
    // Given a variable pointer with just the name of the target known, resolve to a variable
    // pointer that more specifically points to the exact instance: whether it's global,
    // or the exact position of a temporary on the callstack.
    func resolveVariablePointer(_ varPointer: VariablePointerValue) -> VariablePointerValue {
        var contextIndex = varPointer.contextIndex
        
        if contextIndex == -1 {
            contextIndex = getContextIndexOfVariable(named: varPointer.variableName)
        }
        
        let valueOfVariablePointedTo = getRawVariable(named: varPointer.variableName, withContextIndex: contextIndex)
        
        // Extra layer of indirection:
        // When accessing a pointer to a pointer (e.g. when calling nested or
        // recursive functions that take variable references, ensure we don't create
        // a chain of indirection by just returning the final target
        if let doubleRedirectionPointer = valueOfVariablePointedTo as? VariablePointerValue {
            return doubleRedirectionPointer
        }
        
        // Make copy of the variable pointer so we're not using the value direct from
        // the runtime. Temporary must be local to the current scope.
        else {
            return VariablePointerValue(varPointer.variableName, contextIndex)
        }
    }
    
    // 0 if named variable is global
    // 1+ if named variable is a temporary in a particular call stack element
    func getContextIndexOfVariable(named varName: String) -> Int {
        if globalVariableExists(named: varName) {
            return 0
        }
        
        return _callStack!.currentElementIndex
    }
    
    var _globalVariables: [String: Object] = [:]
    
    var _defaultGlobalVariables: [String: Object] = [:]
    
    // Used for accessing temporary variables
    var _callStack: CallStack?
    var _changedVariablesForBatchObs: Set<String>?
    var _listDefsOrigin: ListDefinitionsOrigin?
}
