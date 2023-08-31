import Foundation

public class Object: Equatable, Hashable {
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
    
    public func debugLineNumber(ofPath path: Path?) -> Int? {
        if path == nil {
            return nil
        }
        
        let root = self.rootContentContainer
        if root != nil {
            let targetContent = root!.content(atPath: path!).obj
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
                    let namedChild = child as? Nameable
                    if namedChild != nil && namedChild!.hasValidName {
                        comps.append(Path.Component(namedChild!.name!))
                    }
                    else {
                        // TODO: funky, may be broken
                        comps.append(Path.Component(container!.content.firstIndex(where: { c in
                            c === child
                        })!))
                    }
                    
                    child = container
                    container = container!.parent as? Container
                }
                
                comps.reverse()
                _path = Path(withComponents: comps)
            }
        }
        return _path!
    }
    
    public func resolve(path: Path) -> SearchResult? {
        var _path = path
        if _path.isRelative {
            var nearestContainer = self as? Container
            if nearestContainer == nil {
                assert(parent != nil, "Can't resolve relative path because we don't have a parent")
                nearestContainer = parent as? Container
                assert(nearestContainer != nil, "Expected parent to be a container")
                assert(path.getComponent(atIndex: 0).isParent)
                _path = _path.tail!
            }
            
            return nearestContainer?.content(atPath: _path)
        }
        else {
            return rootContentContainer?.content(atPath: _path)
        }
    }
    
    public func convertPathToRelative(globalPath: Path) -> Path? {
        // 1. Find last shared ancestor
        // 2. Drill up using ".." style (actually represented as "^")
        // 3. Re-build downward chain from common ancestor
        
        let ownPath = path
        
        let minPathLength = min(globalPath.length, ownPath.length)
        var lastSharedPathCompIndex = -1
        
        for i in 0 ..< minPathLength {
            let ownComp = ownPath.getComponent(atIndex: i)
            let otherComp = globalPath.getComponent(atIndex: i)
            
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
        
        let numUpwardsMoves = (ownPath.length - 1) - lastSharedPathCompIndex
        
        var newPathComps: [Path.Component] = []
        
        for _ in 0 ..< numUpwardsMoves {
            newPathComps.append(Path.Component.toParent())
        }
        
        for down in (lastSharedPathCompIndex + 1) ..< globalPath.length {
            newPathComps.append(globalPath.getComponent(atIndex: down))
        }
        
        let relativePath = Path(withComponents: newPathComps, isRelative: true)
        return relativePath
    }
    
    public func compactString(forPath otherPath: Path) -> String {
        var globalPathStr: String? = nil
        var relativePathStr: String? = nil
        
        if otherPath.isRelative {
            relativePathStr = otherPath.componentsString
            globalPathStr = path.path(byAppendingPath: otherPath).componentsString
        }
        else {
            let relativePath = convertPathToRelative(globalPath: otherPath)
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
    
    public func setChild<T: Object>(_ obj: inout T?, _ value: T?) {
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
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
