import Foundation

public class Divert: Object, CustomStringConvertible {
    public var targetPath: Path? {
        get {
            if _targetPath != nil && _targetPath!.isRelative {
                let targetObj = targetPointer!.resolve()
                if targetObj != nil {
                    _targetPath = targetObj!.path
                }
            }
            return _targetPath
        }
        set {
            _targetPath = newValue
            _targetPointer = Pointer.null
        }
    }
    var _targetPath: Path?
    
    public var targetPointer: Pointer? {
        get {
            if _targetPointer == nil || _targetPointer!.isNull {
                let targetObj = resolve(path: _targetPath!)?.obj
                
                if (_targetPath?.lastComponent?.isIndex ?? false) {
                    _targetPointer?.container = targetObj?.parent as? Container
                    _targetPointer?.index = (_targetPath?.lastComponent!.index)!
                }
                else {
                    _targetPointer = Pointer.startOf(container: targetObj as? Container)
                }
            }
            return _targetPointer
        }
    }
    var _targetPointer: Pointer?
    
    
    public var targetPathString: String? {
        get {
            if targetPath == nil {
                return nil
            }
            
            return compactString(forPath: targetPath!)
        }
        set {
            if newValue == nil {
                targetPath = nil
            }
            else {
                targetPath = Path(fromComponentsString: newValue!)
            }
        }
    }
    
    public var variableDivertName: String?
    public var hasVariableTarget: Bool {
        variableDivertName != nil
    }
    public var pushesToStack: Bool = false
    public var stackPushType: PushPopType?
    
    public var isExternal: Bool = false
    public var externalArgs: Int = 0
    
    public var isConditional: Bool = false
    
    public init(_ stackPushType: PushPopType?) {
        self.stackPushType = stackPushType
        super.init()
    }
    
    public convenience override init() {
        self.init(nil)
        self.pushesToStack = false
    }
    
    // NOTE: Not sure if this will take effect, but I hope so?
    public static func ==(_ lhs: Divert, _ rhs: Divert) -> Bool {
        if lhs.hasVariableTarget == rhs.hasVariableTarget {
            if lhs.hasVariableTarget {
                return lhs.variableDivertName == rhs.variableDivertName
            }
            else {
                return lhs.targetPath == rhs.targetPath
            }
        }
        return false
    }
    
    public override func hash(into hasher: inout Hasher) {
        if hasVariableTarget {
            let variableTargetSalt = 12345
            hasher.combine(variableDivertName?.hashValue ?? 0 + variableTargetSalt)
        }
        else {
            let pathTargetSalt = 54321
            hasher.combine(variableDivertName?.hashValue ?? 0 + pathTargetSalt)
        }
    }
    
    
    
    public var description: String {
        if hasVariableTarget {
            return "Divert(variable: \(variableDivertName!))"
        }
        
        if targetPath == nil {
            return "Divert(nil)"
        }
        
        var sb = ""
        var targetStr = String(describing: targetPath!)
        let targetLineNum = debugLineNumber(ofPath: targetPath)
        if targetLineNum != nil {
            targetStr = "line \(targetLineNum!) "
        }
        
        sb += "Divert"
        
        if isConditional {
            sb += "?"
        }
        
        if pushesToStack {
            if stackPushType! == .function {
                sb += " function"
            }
            else {
                sb += " tunnel"
            }
        }
        
        sb += " -> \(targetPathString!) (\(targetStr))"
        
        return sb
    }
}
