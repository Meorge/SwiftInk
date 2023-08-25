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
    
    public static func CallWithName(_ functionName: String) -> NativeFunctionCall {
        return NativeFunctionCall(functionName)
    }
    
    public static func CallExistsWithName(_ functionName: String) -> Bool {
        GenerateNativeFunctionsIfNecessary()
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
    
    public func Call(_ parameters: [Object]) throws -> Object? {
        if _prototype != nil {
            return try _prototype!.Call(parameters)
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
            return try CallBinaryListOperation(parameters) as? Object
        }
        
        var coercedParams = try CoerceValuesToSingleType(parameters)
        var coercedType = coercedParams[0].valueType
        
        switch coercedType {
        case .Int:
            return try Call(parametersOfSingleType: coercedParams, type: Int.self) as? Object
        case .Float:
            return try Call(parametersOfSingleType: coercedParams, type: Float.self) as? Object
        case .String:
            return try Call(parametersOfSingleType: coercedParams, type: String.self) as? Object
        case .DivertTarget:
            return try Call(parametersOfSingleType: coercedParams, type: Path.self) as? Object
        case .List:
            return try Call(parametersOfSingleType: coercedParams, type: InkList.self) as? Object
        default:
            return nil
        }
    }
    
    public func Call<T>(parametersOfSingleType: [any BaseValue], type: T.Type) throws -> (any BaseValue)? {
        let param1 = parametersOfSingleType[0]
        let valType = param1.valueType
        
        var paramCount = parametersOfSingleType.count
        
        if paramCount == 2 || paramCount == 1 {            
            guard let opForTypeObj = _operationFuncs[valType] else {
                throw StoryError.cannotPerformOperation(name: name, valType: valType)
            }
            
            // Binary
            if paramCount == 2 {
                let param2 = parametersOfSingleType[1]
                
                var opForType = opForTypeObj as! BinaryOp<T>
                
                // Return value unknown until it's evaluated
                var resultVal: Any? = opForType(param1.value as? T, param2.value as? T)
                return CreateValue(resultVal) as! (any BaseValue)
            }
            
            // Unary
            else {
                var opForType = opForTypeObj as! UnaryOp<T>
                var resultVal: Any? = opForType(param1.value as? T)
                return CreateValue(resultVal) as! (any BaseValue)
            }
        }
        
        else {
            throw StoryError.unexpectedNumberOfParametersToNativeFunctionCall(params: parametersOfSingleType.count)
        }
    }
    
    public func CallBinaryListOperation(_ parameters: [Object]) throws -> (any BaseValue)? {
        // List-Int addition/subtraction returns a List (e.g. "alpha" + 1 = "beta")
        if (name == NativeFunctionCall.Add || name == NativeFunctionCall.Subtract) && parameters[0] is ListValue && parameters[1] is IntValue {
            return CallListIncrementOperation(parameters)
        }
        
        var v1 = parameters[0] as! any BaseValue
        var v2 = parameters[1] as! any BaseValue
        if (name == NativeFunctionCall.And || name == NativeFunctionCall.Or) && (v1.valueType != .List || v2.valueType != .List) {
            var op = _operationFuncs[.Int] as! BinaryOp<Int>
            var result = op(v1.isTruthy ? 1 : 0, v2.isTruthy ? 1 : 0) as! Bool
            return BoolValue(result)
        }
        
        // Normal (list * list) operation
        if v1.valueType == .List && v2.valueType == .List {
            return try Call(parametersOfSingleType: [v1, v2], type: InkList.self)
        }
        
        throw StoryError.cannotPerformBinaryOperation(name: name, lhs: v1.valueType, rhs: v2.valueType)
    }
    
    func CallListIncrementOperation(_ listIntParams: [Object]) -> ListValue {
        let listVal = listIntParams[0] as? ListValue
        let intVal = listIntParams[1] as? IntValue
        
        let resultRawList = InkList()
        for listItemWithValue in listVal!.value!.internalDict {
            let listItem = listItemWithValue.key
            let listItemValue = listItemWithValue.value
            
            // Find + or - operation
            let intOp = _operationFuncs[.Int] as! BinaryOp<Int>
            
            // Return value unknown until evaluated
            let targetInt = intOp(listItemValue, intVal!.value!) as! Int
            
            // Find this item's origin (linear search should be ok, should be short haha)
            let itemOrigin = listVal?.value!.origins.first { $0.name == listItem.originName }
            
            if itemOrigin != nil {
                if let incrementedItem = itemOrigin!.TryGetItemWithValue(targetInt) {
                    resultRawList.internalDict[incrementedItem] = targetInt
                }
            }
        }
        
        return ListValue(resultRawList)
    }
    
    func CoerceValuesToSingleType(_ parametersIn: [Object]) throws -> [any BaseValue] {
        var valType = ValueType.Int
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
            
            if val.valueType == ValueType.List {
                specialCaseList = val as? ListValue
            }
        }
        
        // Coerce to this chosen type
        var parametersOut: [any BaseValue] = []
        
        // Special case: Coercing to Ints to Lists
        // We have to do it early when we have both parameters
        // to hand - so that we can make use of the List's origin
        if valType == .List {
            for val in parametersIn as! [any BaseValue] {
                if val.valueType == .List {
                    parametersOut.append(val)
                }
                else if let intValObj = val as? IntValue {
                    var intVal = intValObj.value!
                    var list = specialCaseList!.value!.originOfMaxItem
                    if let item = list?.TryGetItemWithValue(intVal) {
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
                parametersOut.append(try val.Cast(valType)!)
            }
        }
        
        return parametersOut
    }
    
    public init(_ name: String) {
        super.init()
        NativeFunctionCall.GenerateNativeFunctionsIfNecessary()
        self.name = name
    }

    public override init() {
        NativeFunctionCall.GenerateNativeFunctionsIfNecessary()
    }
    
    internal init(_ name: String, _ numberOfParameters: Int) {
        super.init()
        _isPrototype = true
        self.name = name
        self.numberOfParameters = numberOfParameters
    }
    
    static func Identity<T>(_ t: T) -> Any? {
        return t
    }
    
    static func GenerateNativeFunctionsIfNecessary() {
        // Why no bool operations?
        // Before evaluation, all bools are coerced to ints in
        // CoerceValuesToSingleType (see default value for valType at top).
        // So, no operations are ever directly done in bools themselves.
        // This also means that 1 == true works, since true is always converted
        // to 1 first.
        // However, many operations retunr a "native" bool (equals, etc).
        
        // Int operations
        AddIntBinaryOp(Add, { $0! + $1! })
        AddIntBinaryOp(Subtract, { $0! - $1! })
        AddIntBinaryOp(Multiply, { $0! * $1! })
        AddIntBinaryOp(Divide, { $0! / $1! })
        AddIntBinaryOp(Mod, { $0! % $1! })
        AddIntUnaryOp(Negate, { -$0! })
        
        AddIntBinaryOp(Equal, { $0! == $1! })
        AddIntBinaryOp(Greater, { $0! > $1! })
        AddIntBinaryOp(Less, { $0! < $1! })
        AddIntBinaryOp(GreaterThanOrEquals, { $0! >= $1! })
        AddIntBinaryOp(LessThanOrEquals, { $0! <= $1! })
        AddIntBinaryOp(NotEquals, { $0! != $1 })
        AddIntUnaryOp(Not, { $0! == 0 })
        
        AddIntBinaryOp(And, { $0! != 0 && $1! != 0 })
        AddIntBinaryOp(Or, { $0 != 0 || $1! != 0 })
        
        AddIntBinaryOp(Max, { max($0!, $1!) })
        AddIntBinaryOp(Min, { min($0!, $1!) })
        
        // Have to cast to float since you could do POW(2, -1)
        AddIntBinaryOp(Pow, { Float(powf(Float($0!), Float($1!))) })
        AddIntUnaryOp(Floor, Identity)
        AddIntUnaryOp(Ceiling, Identity)
        AddIntUnaryOp(IntName, Identity)
        AddIntUnaryOp(FloatName, { Float($0!) })
        
        // Float operations
        AddFloatBinaryOp(Add, { $0! + $1! })
        AddFloatBinaryOp(Subtract, { $0! - $1! })
        AddFloatBinaryOp(Multiply, { $0! * $1! })
        AddFloatBinaryOp(Divide, { $0! / $1! })
        AddFloatBinaryOp(Mod, { $0!.truncatingRemainder(dividingBy: $1!) })
        AddFloatUnaryOp(Negate, { -$0! })
        
        AddFloatBinaryOp(Equal, { $0! == $1! })
        AddFloatBinaryOp(Greater, { $0! > $1! })
        AddFloatBinaryOp(Less, { $0! < $1! })
        AddFloatBinaryOp(GreaterThanOrEquals, { $0! >= $1! })
        AddFloatBinaryOp(LessThanOrEquals, { $0! <= $1! })
        AddFloatBinaryOp(NotEquals, { $0! != $1 })
        AddFloatUnaryOp(Not, { $0! == 0.0 })
        
        AddFloatBinaryOp(And, { $0! != 0 && $1! != 0 })
        AddFloatBinaryOp(Or, { $0 != 0 || $1! != 0 })
        
        AddFloatBinaryOp(Max, { max($0!, $1!) })
        AddFloatBinaryOp(Min, { min($0!, $1!) })
        
        AddFloatBinaryOp(Pow, { powf($0!, $1!) })
        AddFloatUnaryOp(Floor, { floorf($0!) })
        AddFloatUnaryOp(Ceiling, { ceilf($0!) })
        AddFloatUnaryOp(IntName, { Int($0!) })
        AddFloatUnaryOp(FloatName, Identity)
        
        // String operations
        AddStringBinaryOp(Add, { $0! + $1! })
        AddStringBinaryOp(Equal, { $0! == $1! })
        AddStringBinaryOp(NotEquals, { $0! != $1! })
        AddStringBinaryOp(Has, { $0!.contains($1!) })
        AddStringBinaryOp(Hasnt, { !$0!.contains($1!) })
        
        // List operations
        AddListBinaryOp(Add, { $0!.Union($1!) })
        AddListBinaryOp(Subtract, { $0!.Without($1!) })
        AddListBinaryOp(Has, { $0!.Contains($1!) })
        AddListBinaryOp(Hasnt, { !$0!.Contains($1!) })
        AddListBinaryOp(Intersect, { $0!.Intersect($1!) })
        
        AddListBinaryOp(Equal, { $0! == $1! })
        AddListBinaryOp(Greater, { $0!.GreaterThan($1!) })
        AddListBinaryOp(Less, { $0!.LessThan($1!) })
        AddListBinaryOp(GreaterThanOrEquals, { $0!.GreaterThanOrEquals($1!) })
        AddListBinaryOp(LessThanOrEquals, { $0!.LessThanOrEquals($1!) })
        AddListBinaryOp(NotEquals, { $0! != $1! })
        
        AddListBinaryOp(And, { $0!.count > 0 && $1!.count > 0 })
        AddListBinaryOp(Or, { $0!.count > 0 || $1!.count > 0 })
        
        AddListUnaryOp(Not, { $0!.count == 0 ? 1 : 0 })
        
        // Placeholders to ensure that these special case functions can exist,
        // since these functions are never actually run, and are special cased in Call
        AddListUnaryOp(Invert, { $0!.inverse })
        AddListUnaryOp(All, { $0!.all })
        AddListUnaryOp(ListMin, { $0!.MinAsList() })
        AddListUnaryOp(ListMax, { $0!.MaxAsList() })
        AddListUnaryOp(Count, { $0!.count })
        AddListUnaryOp(ValueOfList, { $0!.maxItem.value })
        
        // Divert target operations
        AddOpToNativeFunc(Equal, 2, .DivertTarget, {(d1: Path, d2: Path) in d1 == d2 })
        AddOpToNativeFunc(NotEquals, 2, .DivertTarget, {(d1: Path, d2: Path) in d1 != d2 })
    }
    
    func AddOpFuncForType(_ valType: ValueType, _ op: Any?) {
        _operationFuncs[valType] = op
    }

    static func AddOpToNativeFunc(_ name: String, _ args: Int, _ valType: ValueType, _ op: Any?) {
        var nativeFunc: NativeFunctionCall? = nil
        
        if !_nativeFunctions.keys.contains(name) {
            nativeFunc = NativeFunctionCall(name, args)
            _nativeFunctions[name] = nativeFunc
        }
        else {
            nativeFunc = _nativeFunctions[name]
        }
        
        nativeFunc!.AddOpFuncForType(valType, op)
    }
    
    static func AddIntBinaryOp(_ name: String, _ op: @escaping BinaryOp<Int>) {
        AddOpToNativeFunc(name, 2, ValueType.Int, op)
    }
    
    static func AddIntUnaryOp(_ name: String, _ op: @escaping UnaryOp<Int>) {
        AddOpToNativeFunc(name, 1, ValueType.Int, op)
    }

    static func AddFloatBinaryOp(_ name: String, _ op: @escaping BinaryOp<Float>) {
        AddOpToNativeFunc(name, 2, ValueType.Float, op)
    }
    
    static func AddStringBinaryOp(_ name: String, _ op: @escaping BinaryOp<String>) {
        AddOpToNativeFunc(name, 2, ValueType.String, op)
    }
    
    static func AddListBinaryOp(_ name: String, _ op: @escaping BinaryOp<InkList>) {
        AddOpToNativeFunc(name, 2, ValueType.List, op)
    }
    
    static func AddListUnaryOp(_ name: String, _ op: @escaping UnaryOp<InkList>) {
        AddOpToNativeFunc(name, 1, ValueType.List, op)
    }
    
    static func AddFloatUnaryOp(_ name: String, _ op: @escaping UnaryOp<Float>) {
        AddOpToNativeFunc(name, 1, ValueType.Float, op)
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
