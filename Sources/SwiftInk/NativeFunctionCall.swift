import Foundation

public class NativeFunctionCall: Object, CustomStringConvertible {
    public static let Add = "+"
    public static let Subtract = "-"
    public static let Divide = "/"
    public static let Multiply = "*"
    public static let Mod = "%"
    public static let Negate = "_"
    
    public static let Equal = "=="
    public static let Greater = ">"
    public static let Less = "<"
    public static let GreaterThanOrEquals = ">="
    public static let LessThanOrEquals = "<="
    public static let NotEquals = "!="
    public static let Not = "!"
    
    public static let And = "&&"
    public static let Or = "||"
    
    public static let Min = "MIN"
    public static let Max = "MAX"
    
    public static let Pow = "POW"
    public static let Floor = "FLOOR"
    public static let Ceiling = "CEILING"
    public static let IntName = "INT"
    public static let FloatName = "FLOAT"
    
    public static let Has = "?"
    public static let Hasnt = "!?"
    public static let Intersect = "^"
    
    public static let ListMin = "LIST_MIN"
    public static let ListMax = "LIST_MAX"
    public static let All = "LIST_ALL"
    public static let Count = "LIST_COUNT"
    public static let ValueOfList = "LIST_VALUE"
    public static let Invert = "LIST_INVERT"
    
    public static func callFunction(named functionName: String) -> NativeFunctionCall {
        return NativeFunctionCall(named: functionName)
    }
    
    public static func callExists(named functionName: String) -> Bool {
        generateNativeFunctionsIfNecessary()
        return _nativeFunctions.keys.contains(functionName)
    }
    
    var name: String {
        get {
            return _name
        }
        set {
            _name = newValue
            if !_isPrototype {
                _prototype = NativeFunctionCall._nativeFunctions[_name]
            }
        }
    }
    private var _name: String = ""
    
    var numberOfParameters: Int {
        get {
            if _prototype != nil {
                return _prototype!.numberOfParameters
            }
            else {
                return _numberOfParameters
            }
        }
        set {
            _numberOfParameters = newValue
        }
    }
    private var _numberOfParameters: Int = 0
    
    public func call(withParameters parameters: [Object]) throws -> Object? {
        if _prototype != nil {
            return try _prototype!.call(withParameters: parameters)
        }
        
        if numberOfParameters != parameters.count {
            throw StoryError.unexpectedNumberOfParameters
        }
        
        var hasList = false
        for p in parameters {
            if p is Void {
                throw StoryError.performOperationOnVoid
            }
            if p is ListValue {
                hasList = true
            }
        }
        
        // Binary operations on lists are treated outside of the standard coercion rules
        if parameters.count == 2 && hasList {
            return try callBinaryListOperation(withParameters: parameters) as? Object
        }
        
        let coercedParams = try coerceValuesToSingleType(parameters)
        let coercedType = coercedParams[0].valueType
        
        switch coercedType {
        case .int:
            return try call(parametersOfSingleType: coercedParams, type: Int.self) as? Object
        case .float:
            return try call(parametersOfSingleType: coercedParams, type: Float.self) as? Object
        case .string:
            return try call(parametersOfSingleType: coercedParams, type: String.self) as? Object
        case .divertTarget:
            return try call(parametersOfSingleType: coercedParams, type: Path.self) as? Object
        case .list:
            return try call(parametersOfSingleType: coercedParams, type: InkList.self) as? Object
        default:
            return nil
        }
    }
    
    public func call<T>(parametersOfSingleType: [any BaseValue], type: T.Type) throws -> (any BaseValue)? {
        let param1 = parametersOfSingleType[0]
        let valType = param1.valueType
        
        let paramCount = parametersOfSingleType.count
        
        if paramCount == 2 || paramCount == 1 {            
            guard let opForTypeObj = _operationFuncs[valType] else {
                throw StoryError.cannotPerformOperation(name: name, valType: valType)
            }
            
            // Binary
            if paramCount == 2 {
                let param2 = parametersOfSingleType[1]
                let opForType = opForTypeObj as! BinaryOp<T>
                
                // Return value unknown until it's evaluated
                let resultVal: Any? = opForType(param1.value as? T, param2.value as? T)
                return createValue(fromAny: resultVal) as? (any BaseValue)
            }
            
            // Unary
            else {
                let opForType = opForTypeObj as! UnaryOp<T>
                let resultVal: Any? = opForType(param1.value as? T)
                return createValue(fromAny: resultVal) as? (any BaseValue)
            }
        }
        
        else {
            throw StoryError.unexpectedNumberOfParametersToNativeFunctionCall(params: parametersOfSingleType.count)
        }
    }
    
    public func callBinaryListOperation(withParameters parameters: [Object]) throws -> (any BaseValue)? {
        // List-Int addition/subtraction returns a List (e.g. "alpha" + 1 = "beta")
        if (name == NativeFunctionCall.Add || name == NativeFunctionCall.Subtract) && parameters[0] is ListValue && parameters[1] is IntValue {
            return callListIncrementOperation(withParameters: parameters)
        }
        
        let v1 = parameters[0] as! any BaseValue
        let v2 = parameters[1] as! any BaseValue
        if (name == NativeFunctionCall.And || name == NativeFunctionCall.Or) && (v1.valueType != .list || v2.valueType != .list) {
            let op = _operationFuncs[.int] as! BinaryOp<Int>
            let result = op(v1.isTruthy ? 1 : 0, v2.isTruthy ? 1 : 0) as! Bool
            return BoolValue(result)
        }
        
        // Normal (list * list) operation
        if v1.valueType == .list && v2.valueType == .list {
            return try call(parametersOfSingleType: [v1, v2], type: InkList.self)
        }
        
        throw StoryError.cannotPerformBinaryOperation(name: name, lhs: v1.valueType, rhs: v2.valueType)
    }
    
    func callListIncrementOperation(withParameters listIntParams: [Object]) -> ListValue {
        let listVal = listIntParams[0] as? ListValue
        let intVal = listIntParams[1] as? IntValue
        
        let resultRawList = InkList()
        for listItemWithValue in listVal!.value!.internalDict {
            let listItem = listItemWithValue.key
            let listItemValue = listItemWithValue.value
            
            // Find + or - operation
            let intOp = _operationFuncs[.int] as! BinaryOp<Int>
            
            // Return value unknown until evaluated
            let targetInt = intOp(listItemValue, intVal!.value!) as! Int
            
            // Find this item's origin (linear search should be ok, should be short haha)
            let itemOrigin = listVal?.value!.origins.first { $0.name == listItem.originName }
            
            if itemOrigin != nil {
                if let incrementedItem = itemOrigin!.tryGetItem(withValue: targetInt) {
                    resultRawList.internalDict[incrementedItem] = targetInt
                }
            }
        }
        
        return ListValue(resultRawList)
    }
    
    func coerceValuesToSingleType(_ parametersIn: [Object]) throws -> [any BaseValue] {
        var valType = ValueType.int
        var specialCaseList: ListValue? = nil
        
        // Find out what the output type is
        // "Higher level" types infect both so that binary operations
        // use the same type on both sides. e.g. binary operation of
        // int and float causes the int to be casted to a float.
        for obj in parametersIn {
            let val = obj as! any BaseValue
            if val.valueType.rawValue > valType.rawValue {
                valType = val.valueType
            }
            
            if val.valueType == ValueType.list {
                specialCaseList = val as? ListValue
            }
        }
        
        // Coerce to this chosen type
        var parametersOut: [any BaseValue] = []
        
        // Special case: Coercing to Ints to Lists
        // We have to do it early when we have both parameters
        // to hand - so that we can make use of the List's origin
        if valType == .list {
            for val in parametersIn as! [any BaseValue] {
                if val.valueType == .list {
                    parametersOut.append(val)
                }
                else if let intValObj = val as? IntValue {
                    let intVal = intValObj.value!
                    let list = specialCaseList!.value!.originOfMaxItem
                    if let item = list?.tryGetItem(withValue: intVal) {
                        parametersOut.append(ListValue(item, intVal))
                    }
                    else {
                        throw StoryError.couldNotFindListItem(value: intVal, listName: list!.name)
                    }
                }
                else {
                    throw StoryError.couldNotMixListWithValueInOperation(valueType: val.valueType)
                }
            }
        }
        
        else {
            for val in parametersIn as! [any BaseValue] {
                parametersOut.append(try val.cast(to: valType)!)
            }
        }
        
        return parametersOut
    }
    
    public init(named name: String) {
        super.init()
        NativeFunctionCall.generateNativeFunctionsIfNecessary()
        self.name = name
    }

    public override init() {
        NativeFunctionCall.generateNativeFunctionsIfNecessary()
    }
    
    internal init(named name: String, withParameterCount numberOfParameters: Int) {
        super.init()
        _isPrototype = true
        self.name = name
        self.numberOfParameters = numberOfParameters
    }
    
    static func identity<T>(_ t: T) -> Any? {
        return t
    }
    
    static func generateNativeFunctionsIfNecessary() {
        // Why no bool operations?
        // Before evaluation, all bools are coerced to ints in
        // CoerceValuesToSingleType (see default value for valType at top).
        // So, no operations are ever directly done in bools themselves.
        // This also means that 1 == true works, since true is always converted
        // to 1 first.
        // However, many operations retunr a "native" bool (equals, etc).
        
        // Int operations
        addIntBinaryOp(named: Add, { $0! + $1! })
        addIntBinaryOp(named: Subtract, { $0! - $1! })
        addIntBinaryOp(named: Multiply, { $0! * $1! })
        addIntBinaryOp(named: Divide, { $0! / $1! })
        addIntBinaryOp(named: Mod, { $0! % $1! })
        addIntUnaryOp(named: Negate, { -$0! })
        
        addIntBinaryOp(named: Equal, { $0! == $1! })
        addIntBinaryOp(named: Greater, { $0! > $1! })
        addIntBinaryOp(named: Less, { $0! < $1! })
        addIntBinaryOp(named: GreaterThanOrEquals, { $0! >= $1! })
        addIntBinaryOp(named: LessThanOrEquals, { $0! <= $1! })
        addIntBinaryOp(named: NotEquals, { $0! != $1 })
        addIntUnaryOp(named: Not, { $0! == 0 })
        
        addIntBinaryOp(named: And, { $0! != 0 && $1! != 0 })
        addIntBinaryOp(named: Or, { $0 != 0 || $1! != 0 })
        
        addIntBinaryOp(named: Max, { max($0!, $1!) })
        addIntBinaryOp(named: Min, { min($0!, $1!) })
        
        // Have to cast to float since you could do POW(2, -1)
        addIntBinaryOp(named: Pow, { Float(powf(Float($0!), Float($1!))) })
        addIntUnaryOp(named: Floor, identity)
        addIntUnaryOp(named: Ceiling, identity)
        addIntUnaryOp(named: IntName, identity)
        addIntUnaryOp(named: FloatName, { Float($0!) })
        
        // Float operations
        addFloatBinaryOp(named: Add, { $0! + $1! })
        addFloatBinaryOp(named: Subtract, { $0! - $1! })
        addFloatBinaryOp(named: Multiply, { $0! * $1! })
        addFloatBinaryOp(named: Divide, { $0! / $1! })
        addFloatBinaryOp(named: Mod, { $0!.truncatingRemainder(dividingBy: $1!) })
        addFloatUnaryOp(named: Negate, { -$0! })
        
        addFloatBinaryOp(named: Equal, { $0! == $1! })
        addFloatBinaryOp(named: Greater, { $0! > $1! })
        addFloatBinaryOp(named: Less, { $0! < $1! })
        addFloatBinaryOp(named: GreaterThanOrEquals, { $0! >= $1! })
        addFloatBinaryOp(named: LessThanOrEquals, { $0! <= $1! })
        addFloatBinaryOp(named: NotEquals, { $0! != $1 })
        addFloatUnaryOp(named: Not, { $0! == 0.0 })
        
        addFloatBinaryOp(named: And, { $0! != 0 && $1! != 0 })
        addFloatBinaryOp(named: Or, { $0 != 0 || $1! != 0 })
        
        addFloatBinaryOp(named: Max, { max($0!, $1!) })
        addFloatBinaryOp(named: Min, { min($0!, $1!) })
        
        addFloatBinaryOp(named: Pow, { powf($0!, $1!) })
        addFloatUnaryOp(named: Floor, { floorf($0!) })
        addFloatUnaryOp(named: Ceiling, { ceilf($0!) })
        addFloatUnaryOp(named: IntName, { Int($0!) })
        addFloatUnaryOp(named: FloatName, identity)
        
        // String operations
        addStringBinaryOp(named: Add, { $0! + $1! })
        addStringBinaryOp(named: Equal, { $0! == $1! })
        addStringBinaryOp(named: NotEquals, { $0! != $1! })
        addStringBinaryOp(named: Has, { $0!.contains($1!) })
        addStringBinaryOp(named: Hasnt, { !$0!.contains($1!) })
        
        // List operations
        addListBinaryOp(named: Add, { $0!.union($1!) })
        addListBinaryOp(named: Subtract, { $0!.without($1!) })
        addListBinaryOp(named: Has, { $0!.contains($1!) })
        addListBinaryOp(named: Hasnt, { !$0!.contains($1!) })
        addListBinaryOp(named: Intersect, { $0!.intersect($1!) })
        
        addListBinaryOp(named: Equal, { $0! == $1! })
        addListBinaryOp(named: Greater, { $0!.isGreaterThan($1!) })
        addListBinaryOp(named: Less, { $0!.isLessThan($1!) })
        addListBinaryOp(named: GreaterThanOrEquals, { $0!.isGreaterThanOrEquals($1!) })
        addListBinaryOp(named: LessThanOrEquals, { $0!.isLessThanOrEquals($1!) })
        addListBinaryOp(named: NotEquals, { $0! != $1! })
        
        addListBinaryOp(named: And, { $0!.count > 0 && $1!.count > 0 })
        addListBinaryOp(named: Or, { $0!.count > 0 || $1!.count > 0 })
        
        addListUnaryOp(named: Not, { $0!.count == 0 ? 1 : 0 })
        
        // Placeholders to ensure that these special case functions can exist,
        // since these functions are never actually run, and are special cased in Call
        addListUnaryOp(named: Invert, { $0!.inverse })
        addListUnaryOp(named: All, { $0!.all })
        addListUnaryOp(named: ListMin, { $0!.minAsList() })
        addListUnaryOp(named: ListMax, { $0!.maxAsList() })
        addListUnaryOp(named: Count, { $0!.count })
        addListUnaryOp(named: ValueOfList, { $0!.maxItem.value })
        
        // Divert target operations
        addOpToNativeFunc(named: Equal, withArgumentCount: 2, withValueType: .divertTarget, {(d1: Path, d2: Path) in d1 == d2 })
        addOpToNativeFunc(named: NotEquals, withArgumentCount: 2, withValueType: .divertTarget, {(d1: Path, d2: Path) in d1 != d2 })
    }
    
    func addOpFunc(forType valType: ValueType, _ op: Any?) {
        _operationFuncs[valType] = op
    }

    static func addOpToNativeFunc(named name: String, withArgumentCount args: Int, withValueType valType: ValueType, _ op: Any?) {
        var nativeFunc: NativeFunctionCall? = nil
        
        if !_nativeFunctions.keys.contains(name) {
            nativeFunc = NativeFunctionCall(named: name, withParameterCount: args)
            _nativeFunctions[name] = nativeFunc
        }
        else {
            nativeFunc = _nativeFunctions[name]
        }
        
        nativeFunc!.addOpFunc(forType: valType, op)
    }
    
    static func addIntBinaryOp(named name: String, _ op: @escaping BinaryOp<Int>) {
        addOpToNativeFunc(named: name, withArgumentCount: 2, withValueType: ValueType.int, op)
    }
    
    static func addIntUnaryOp(named name: String, _ op: @escaping UnaryOp<Int>) {
        addOpToNativeFunc(named: name, withArgumentCount: 1, withValueType: ValueType.int, op)
    }

    static func addFloatBinaryOp(named name: String, _ op: @escaping BinaryOp<Float>) {
        addOpToNativeFunc(named: name, withArgumentCount: 2, withValueType: ValueType.float, op)
    }
    
    static func addStringBinaryOp(named name: String, _ op: @escaping BinaryOp<String>) {
        addOpToNativeFunc(named: name, withArgumentCount: 2, withValueType: ValueType.string, op)
    }
    
    static func addListBinaryOp(named name: String, _ op: @escaping BinaryOp<InkList>) {
        addOpToNativeFunc(named: name, withArgumentCount: 2, withValueType: ValueType.list, op)
    }
    
    static func addListUnaryOp(named name: String, _ op: @escaping UnaryOp<InkList>) {
        addOpToNativeFunc(named: name, withArgumentCount: 1, withValueType: ValueType.list, op)
    }
    
    static func addFloatUnaryOp(named name: String, _ op: @escaping UnaryOp<Float>) {
        addOpToNativeFunc(named: name, withArgumentCount: 1, withValueType: ValueType.float, op)
    }
    
    public var description: String {
        "Native '\(name)'"
    }
    
    typealias BinaryOp<T> = (_ left: T?, _ right: T?) -> Any?
    typealias UnaryOp<T> = (_ val: T?) -> Any?
    
    private var _prototype: NativeFunctionCall?
    private var _isPrototype: Bool = false
    
    // Operations for each data type, for a single operation (e.g. "+")
    private var _operationFuncs: [ValueType: Any?] = [:]
    private static var _nativeFunctions: [String: NativeFunctionCall] = [:]
}
