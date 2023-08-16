import Foundation

// The value to be assigned is popped off the evaluation stack, so no need to keep it here
public class VariableAssignment: Object, CustomStringConvertible {
    var variableName: String?
    var isNewDeclaration: Bool
    public var isGlobal: Bool = false
    
    public init(_ variableName: String?, _ isNewDeclaration: Bool) {
        self.variableName = variableName
        self.isNewDeclaration = isNewDeclaration
    }
    
    // Require default constructor for serialisation
    public convenience override init() {
        self.init(nil, false)
    }
    
    public var description: String {
        "VarAssign to \(String(describing: variableName))"
    }
}
