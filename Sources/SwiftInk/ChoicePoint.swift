import Foundation

public class ChoicePoint: Object, CustomStringConvertible {
    public var pathOnChoice: Path? {
        get {
            
            // Resolve any relative paths to global ones as we come across them
            if _pathOnChoice != nil && _pathOnChoice!.isRelative {
                let choiceTargetObj = choiceTarget
                if choiceTargetObj != nil {
                    _pathOnChoice = choiceTargetObj!.path
                }
            }
            return _pathOnChoice
        }
        set {
            _pathOnChoice = newValue
        }
    }
    private var _pathOnChoice: Path?
    
    public var choiceTarget: Container? {
        let thePath = resolve(path: _pathOnChoice!)
        let theContainer = thePath?.container
        return theContainer
    }
    
    public var pathStringOnChoice: String {
        get {
            compactString(forPath: pathOnChoice!)
        }
        set {
            pathOnChoice = Path(fromComponentsString: newValue)
        }
    }
    
    public var hasCondition: Bool = false
    public var hasStartContent: Bool = false
    public var hasChoiceOnlyContent: Bool = false
    public var onceOnly: Bool = false
    public var isInvisibleDefault: Bool = false
    
    public var flags: Int {
        get {
            var flags = 0
            if hasCondition {
                flags |= 1
            }
            if hasStartContent {
                flags |= 2
            }
            if hasChoiceOnlyContent {
                flags |= 4
            }
            if isInvisibleDefault {
                flags |= 8
            }
            if onceOnly {
                flags |= 16
            }
            return flags
        }
        set {
            hasCondition = (newValue & 1) > 0
            hasStartContent = (newValue & 2) > 0
            hasChoiceOnlyContent = (newValue & 4) > 0
            isInvisibleDefault = (newValue & 8) > 0
            onceOnly = (newValue & 16) > 0
        }
    }
    
    public init(_ onceOnly: Bool) {
        self.onceOnly = onceOnly
    }
    
    public convenience override init() {
        self.init(true)
    }
    
    public var description: String {
        let targetLineNum: Int? = debugLineNumber(ofPath: pathOnChoice)
        var targetString = String(describing: pathOnChoice!)
        
        if targetLineNum != nil {
            targetString = " line \(targetLineNum!)(\(targetString))"
        }
        
        return "Choice: -> \(targetString)"
    }
    
    
}
