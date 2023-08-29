import Foundation

public class Path: Equatable, CustomStringConvertible {
    public var description: String {
        componentsString
    }
    
    static var parentId = "^"
    
    private var components: [Component]
    
    public class Component: Equatable, CustomStringConvertible {
        public var description: String {
            return isIndex ? index.description : name!
        }
        
        private(set) var index: Int
        private(set) var name: String?
        var isIndex: Bool {
            index >= 0
        }
        
        var isParent: Bool {
            name == Path.parentId
        }
        
        init(_ index: Int) {
            self.index = index
            self.name = nil
        }
        
        init(_ name: String) {
            self.name = name
            self.index = -1
        }
        
        public static func ToParent() -> Component {
            return Component(parentId)
        }
        
        public static func == (lhs: Path.Component, rhs: Path.Component) -> Bool {
            if lhs.isIndex == rhs.isIndex {
                return lhs.index == rhs.index
            }
            else {
                return lhs.name == rhs.name
            }
        }
    }
    
    public func GetComponent(_ index: Int) -> Component {
        return components[index]
    }
    
    private(set) var isRelative: Bool = false
    
    public var head: Component? {
        return components.first
    }
    
    public var tail: Path? {
        if components.count >= 2 {
            let tailComps = Array(components[1 ..< components.count])
            return Path(tailComps)
        }
        else {
            return Path.selfPath
        }
    }
    
    public var length: Int {
        components.count
    }
    
    public var lastComponent: Component? {
        components.last
    }
    
    public var containsNamedComponent: Bool {
        return components.contains { comp in
            !comp.isIndex
        }
    }
    
    init() {
        components = []
    }
    
    init(_ head: Component, _ tail: Path) {
        components = []
        components.append(head)
        components.append(contentsOf: tail.components)
    }
    
    init(_ components: [Component], _ relative: Bool = false) {
        self.components = []
        self.components.append(contentsOf: components)
        
        isRelative = relative
        
    }
    
    init(_ componentsString: String) {
        components = []
        self.componentsString = componentsString
    }
    
    public static var selfPath: Path {
        /// NOTE: Defined as `self` in original C# code, but
        /// `selfPath` is used here to avoid name conflicts
        var path = Path()
        path.isRelative = true
        return path
    }
    
    public func PathByAppendingPath(_ pathToAppend: Path) -> Path {
        let p = Path()
        
        var upwardMoves = 0
        for i in 0 ..< pathToAppend.components.count {
            if pathToAppend.components[i].isParent {
                upwardMoves += 1
            }
            else {
                break
            }
        }
        
        for i in 0 ..< (components.count - upwardMoves) {
            p.components.append(components[i])
        }
        
        for i in upwardMoves ..< pathToAppend.components.count {
            p.components.append(pathToAppend.components[i])
        }
        
        return p
    }
    
    public func PathByAppendingComponent(_ c: Component) -> Path {
        let p = Path()
        p.components.append(contentsOf: components)
        p.components.append(c)
        return p
    }
    
    private var _componentsString: String? = nil
    
    private(set) var componentsString: String {
        get {
            if _componentsString == nil {
                _componentsString = components.map({ c in
                    c.description
                }).joined(separator: ".")
                if isRelative {
                    _componentsString = "." + _componentsString!
                }
            }
            return _componentsString!
        }
        
        set {
            components.removeAll()
            _componentsString = newValue
            
            // Empty path, empty components
            // (path is root)
            if _componentsString == nil || _componentsString!.isEmpty {
                return
            }
            
            // Components starting with "." have a relative path, e.g.
            //      .^.^.hello.5
            // is equivalent to file system style path:
            //      ../../hello/5
            if _componentsString![_componentsString!.index(_componentsString!.startIndex, offsetBy: 0)] == "." {
                isRelative = true
                _componentsString!.remove(at: _componentsString!.startIndex)
            }
            else {
                isRelative = false
            }
            
            let componentStrings = _componentsString!.components(separatedBy: ".")
            for str in componentStrings {
                if let index = Int(str) {
                    components.append(Component(index))
                }
                else {
                    components.append(Component(str))
                }
            }
        }
    }
    
    public static func == (lhs: Path, rhs: Path) -> Bool {
        if lhs.components.count != rhs.components.count {
            return false
        }
        
        if lhs.isRelative != rhs.isRelative {
            return false
        }
        
        return lhs.components.elementsEqual(rhs.components)
    }
    
    
}
