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
        
        SetGlobal(variableName, val!)
    }
    
    /// Iterator to allow iteration over all global variables by name.
    public func makeIterator() -> Dictionary<String, Object>.Keys.Iterator {
        return _globalVariables.keys.makeIterator()
    }
    
    public init(_ callStack: CallStack, _ listDefsOrigin: ListDefinitionsOrigin) {
        _globalVariables = [:]
        _callStack = callStack
        _listDefsOrigin = listDefsOrigin
    }
    
    public func ApplyPatch() {
        if patch == nil {
            print("ApplyPatch() was called, but patch was nil")
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
    
    public func SetJsonToken(_ jToken: [String: Any?]) {
        _globalVariables.removeAll()
        
        for varVal in _defaultGlobalVariables {
            if let loadedToken = jToken[varVal.key] {
                _globalVariables[varVal.key] = Json.JTokenToRuntimeObject(loadedToken)
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
    
    // TODO: WriteJson
    
    public func RuntimeObjectsEqual(_ obj1: Object, _ obj2: Object) throws -> Bool {
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
    
    public func GetVariableWithName(_ name: String?) -> Object? {
        GetVariableWithName(name!, -1)
    }
    
    public func GlobalVariableExistsWithName(_ name: String) -> Bool {
        return _globalVariables.keys.contains(name) || _defaultGlobalVariables.keys.contains(name)
    }
    
    func GetVariableWithName(_ name: String, _ contextIndex: Int) -> Object? {
        var varValue = GetRawVariableWithName(name, contextIndex)
        
        // Get value from pointer?
        if let varPointer = varValue as? VariablePointerValue {
            varValue = ValueAtVariablePointer(varPointer)
        }
        
        return varValue
    }
    
    func GetRawVariableWithName(_ name: String?, _ contextIndex: Int) -> Object? {
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
            
            if let listItemValue = _listDefsOrigin?.FindSingleItemListWithName(name!) {
                return listItemValue
            }
            
        }
        
        // Temporary
        return _callStack?.GetTemporaryVariableWithName(name!, contextIndex)
    }
    
    public func ValueAtVariablePointer(_ pointer: VariablePointerValue) -> Object? {
        return GetVariableWithName(pointer.variableName, pointer.contextIndex)
    }
    
    public func Assign(_ varAss: VariableAssignment, _ value: Object?) {
        var finalValue = value
        var name = varAss.variableName
        var contextIndex = -1
        
        // Are we assigning to a global variable?
        var setGlobal = varAss.isNewDeclaration ? varAss.isGlobal : GlobalVariableExistsWithName(name!)
        
        // Constructing new variable pointer reference
        if varAss.isNewDeclaration {
            if let varPointer = finalValue as? VariablePointerValue {
                finalValue = ResolveVariablePointer(varPointer)
                
            }
        }
        
        // Assign to existing variable pointer?
        // Then assign to the variable that the pointer is pointing to by name.
        else {
            // Dereference variable reference to point to
            var existingPointer: VariablePointerValue? = nil
            repeat {
                existingPointer = GetRawVariableWithName(name!, contextIndex) as? VariablePointerValue
                if existingPointer != nil {
                    name = existingPointer!.variableName
                    contextIndex = existingPointer!.contextIndex
                    setGlobal = (contextIndex == 0)
                }
            } while existingPointer != nil
        }
        
        if setGlobal {
            SetGlobal(name!, value!)
        }
        else {
            _callStack!.SetTemporaryVariable(name!, value, varAss.isNewDeclaration, contextIndex)
        }
    }
    
    public func SnapshotDefaultGlobals() {
        _defaultGlobalVariables = _globalVariables
    }
    
    func RetainListOriginsForAssignment(_ oldValue: Object?, _ newValue: Object?) {
        var oldList = oldValue as? ListValue
        var newList = newValue as? ListValue
        if oldList != nil && newList != nil && newList!.value!.count == 0 {
            newList!.value?.SetInitialOriginNames(oldList!.value!.originNames)
        }
    }
    
    public func SetGlobal(_ variableName: String, _ value: Object) {
        var oldValue: Object? = nil
        if let valueFromPatch = patch?.globals[variableName] {
            oldValue = valueFromPatch
        }
        else if let valueFromGlobals = _globalVariables[variableName] {
            oldValue = valueFromGlobals
        }
        
        ListValue.RetainListOriginsForAssignment(oldValue!, value)
        
        if patch != nil {
            patch!.SetGlobal(variableName, value)
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
    func ResolveVariablePointer(_ varPointer: VariablePointerValue) -> VariablePointerValue {
        var contextIndex = varPointer.contextIndex
        
        if contextIndex == -1 {
            contextIndex = GetContextIndexOfVariableNamed(varPointer.variableName)
        }
        
        var valueOfVariablePointedTo = GetRawVariableWithName(varPointer.variableName, contextIndex)
        
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
    func GetContextIndexOfVariableNamed(_ varName: String) -> Int {
        if GlobalVariableExistsWithName(varName) {
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
