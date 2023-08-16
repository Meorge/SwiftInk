import Foundation

public class Object: Equatable {
    public var parent: Object?
    
    private var _path: Path?
    
    private var _debugMetadata: DebugMetadata?
    
    public var debugMetadata: DebugMetadata? {
        get {
            if _debugMetadata == nil {
                if parent != nil {
                    return parent!.debugMetadata
                }
            }
            
            return _debugMetadata
        }
        set {
            _debugMetadata = newValue
        }
    }
    
    public var ownDebugMetadata: DebugMetadata? {
        return _debugMetadata
    }
    
    public func DebugLineNumberOfPath(path: Path?) -> Int? {
        if path == nil {
            return nil
        }
        
        let root = self.rootContentContainer
        if root != nil {
            let targetContent = root!.ContentAtPath(path!).obj
            if targetContent != nil {
                let dm = targetContent!.debugMetadata
                if dm != nil {
                    return dm!.startLineNumber
                }
            }
        }
        return nil
    }
    
    public var path: Path {
        if _path == nil {
            if parent == nil {
                _path = Path()
            }
            else {
                var comps: [Path.Component] = []
                
                var child: Object? = self
                var container: Container? = child!.parent as? Container
                
                while container != nil {
                    var namedChild = child as? Nameable
                    if namedChild != nil && namedChild!.hasValidName {
                        comps.append(Path.Component(namedChild!.name!))
                    }
                    else {
                        // NOTE: funky, may be broken
                        comps.append(Path.Component(container!.content.firstIndex(where: { c in
                            c === child
                        })!))
                    }
                    
                    child = container
                    container = container!.parent as? Container
                }
                
                _path = Path(comps)
            }
        }
        return _path!
    }
    
    public func ResolvePath(_ path: Path) -> SearchResult? {
        var _path = path
        if _path.isRelative {
            var nearestContainer = self as? Container
            if nearestContainer == nil {
                assert(parent != nil, "Can't resolve relative path because we don't have a parent")
                nearestContainer = parent as? Container
                assert(nearestContainer != nil, "Expected parent to be a container")
                assert(path.GetComponent(0).isParent)
                _path = _path.tail!
            }
            
            return nearestContainer?.ContentAtPath(_path)
        }
        else {
            return rootContentContainer?.ContentAtPath(_path)
        }
    }
    
    public func ConvertPathToRelative(_ globalPath: Path) -> Path? {
        // 1. Find last shared ancestor
        // 2. Drill up using ".." style (actually represented as "^")
        // 3. Re-build downward chain from common ancestor
        
        var ownPath = path
        
        var minPathLength = min(globalPath.length, ownPath.length)
        var lastSharedPathCompIndex = -1
        
        for i in 0 ..< minPathLength {
            var ownComp = ownPath.GetComponent(i)
            var otherComp = globalPath.GetComponent(i)
            
            if ownComp == otherComp {
                lastSharedPathCompIndex = i
            }
            else {
                break
            }
        }
        
        // No shared path components, so just use global path
        if lastSharedPathCompIndex == -1 {
            return globalPath
        }
        
        var numUpwardsMoves = (ownPath.length - 1) - lastSharedPathCompIndex
        
        var newPathComps: [Path.Component] = []
        
        for _ in 0 ..< numUpwardsMoves {
            newPathComps.append(Path.Component.ToParent())
        }
        
        for down in (lastSharedPathCompIndex + 1) ..< globalPath.length {
            newPathComps.append(globalPath.GetComponent(down))
        }
        
        var relativePath = Path(newPathComps, true)
        return relativePath
    }
    
    public func CompactPathString(_ otherPath: Path) -> String {
        var globalPathStr: String? = nil
        var relativePathStr: String? = nil
        
        if otherPath.isRelative {
            relativePathStr = otherPath.componentsString
            globalPathStr = path.PathByAppendingPath(otherPath).componentsString
        }
        else {
            var relativePath = ConvertPathToRelative(otherPath)
            relativePathStr = relativePath?.componentsString
            globalPathStr = otherPath.componentsString
        }
        
        if relativePathStr!.count < globalPathStr!.count {
            return relativePathStr!
        }
        else {
            return globalPathStr!
        }
    }
    
    public var rootContentContainer: Container? {
        var ancestor: Object = self
        while ancestor.parent != nil {
            ancestor = ancestor.parent!
        }
        return ancestor as? Container
    }
    
    public init() {
        
    }
    
    public func SetChild<T: Object>(_ obj: inout T?, _ value: T?) {
        if obj != nil {
            obj!.parent = nil
        }
        
        obj = value
        
        if obj != nil {
            obj!.parent = self
        }
    }
    
    public static func == (lhs: Object, rhs: Object) -> Bool {
        return lhs === rhs
    }
}
