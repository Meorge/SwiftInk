import Foundation

public class NativeFunctionCall: Object {
    public let Add = "+"
    public let Subtract = "-"
    public let Divide = "/"
    public let Multiply = "*"
    public let Mod = "%"
    public let Negate = "_"
    
    public let Equal = "=="
    public let Greater = ">"
    public let Less = "<"
    public let GreaterThanOrEquals = ">="
    public let LessThanOrEquals = "<="
    public let NotEquals = "!="
    public let Not = "!"
    
    public let And = "&&"
    public let Or = "||"
    
    public let Min = "MIN"
    public let Max = "MAX"
    
    public let Pow = "POW"
    public let Floor = "FLOOR"
    public let Ceiling = "CEILING"
    public let Int = "INT"
    public let Float = "FLOAT"
    
    public let Has = "?"
    public let Hasnt = "!?"
    public let Intersect = "^"
    
    public let ListMin = "LIST_MIN"
    public let ListMax = "LIST_MAX"
    public let All = "LIST_ALL"
    public let Count = "LIST_COUNT"
    public let ValueOfList = "LIST_VALUE"
    public let Invert = "LIST_INVERT"
    
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
                _prototype = _nativeFunctions[_name]
            }
        }
    }
    private var _name: String
    
    var numberOfParameters: Int {
        get {
            if _prototype {
                return _prototype.numberOfParameters
            }
            else {
                return _numberOfParameters
            }
        }
        set {
            _numberOfParameters = newValue
        }
    }
    private var _numberOfParameters: Int
    
    public func Call(_ parameters: [Object]) throws -> Object? {
        if _prototype {
            return _prototype.Call(parameters)
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
            return CallBinaryListOperation(parameters)
        }
        
        var coercedParams = CoerceValuesToSingleType(parameters)
        var coercedType = coercedParams[0].valueType
        
        switch coercedType {
        case .Int:
            return Call<Int>(coercedParams)
        case .Float:
            return Call<Float>(coercedParams)
        case .String:
            return Call<String>(coercedParams)
        case .DivertTarget:
            return Call<Path>(coercedParams)
        case .List:
            return Call<InkList>(coercedParams)
        default:
            return nil
        }
    }
    
    public func Call<T: Any>(_ parametersOfSingleType: [any BaseValue]) throws -> (any BaseValue)? {
        let param1 = parametersOfSingleType[0]
        let valType = param1.valueType
        
        var paramCount = parametersOfSingleType.count
        
        if paramCount == 2 || paramCount == 1 {
            var opForTypeObj: Any? = nil
            
            guard let opForTypeObj = _operationFuncs[valType] else {
                throw StoryError.cannotPerformOperation(name: name, valType: valType)
            }
            
            // Binary
            if paramCount == 2 {
                let param2 = parametersOfSingleType[1]
                
                var opForType = opForTypeObj as BinaryOp<T>
                
                // Return value unknown until it's evaluated
                var resultVal: Any? = opForType(param1.value, param2.value)
                return BaseValue.Create(resultVal)
            }
            
            // Unary
            else {
                var opForType = opForTypeObj as UnaryOp<T>
                var resultVal: Any? = opForType(param1.value)
                return BaseValue.Create(resultVal)
            }
        }
        
        else {
            throw StoryError.unexpectedNumberOfParametersToNativeFunctionCall(params: parametersOfSingleType.count)
        }
    }
    
    // TODO: CallBinaryListOperation and onwards!
    
}
