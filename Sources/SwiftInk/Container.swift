import Foundation

public class Container: Object, Nameable {    
    public var name: String?
    
    public var content: [Object] {
        get {
            return _content
        }
        // NOTE: Setter disabled because it can throw and apparently
        // that's a no-no in Swift.
//        set {
//            AddContent(newValue)
//        }
    }
    
    public func SetContent(_ newValue: [Object]) throws {
        try AddContent(newValue)
    }
    
    private var _content: [Object]
    
    public var namedContent: [String: Nameable]
    
    public var namedOnlyContent: [String: Object]? {
        get {
            var namedOnlyContentDict: [String: Object] = [:]
            for kvPair in namedContent {
                namedOnlyContentDict[kvPair.key] = kvPair.value as? Object
            }
            
            for c in content {
                var named = c as? Nameable
                if named != nil && named!.hasValidName {
                    namedOnlyContentDict.removeValue(forKey: named!.name!)
                }
            }
            
            if namedOnlyContentDict.count == 0 {
                return nil
            }
            
            return namedOnlyContentDict
        }
        set {
            var existingNamedOnly = namedOnlyContent
            if existingNamedOnly != nil {
                for kvPair in existingNamedOnly! {
                    namedContent.removeValue(forKey: kvPair.key)
                }
            }
            
            if newValue == nil {
                return
            }
            
            for kvPair in newValue! {
                let named = kvPair.value as? Nameable
                if named != nil {
                    AddToNamedContentOnly(named!)
                }
            }
        }
    }
    
    public var visitsShouldBeCounted: Bool
    
    public var turnIndexShouldBeCounted: Bool
    
    public var countingAtStartOnly: Bool
    
    public struct CountFlags: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        static let visits = CountFlags(rawValue: 1)
        static let turns = CountFlags(rawValue: 2)
        static let countStartOnly = CountFlags(rawValue: 4)
    }
    
    public var countFlags: Int {
        get {
            var flags: CountFlags = []
            if visitsShouldBeCounted {
                flags.insert(.visits)
            }
            if turnIndexShouldBeCounted {
                flags.insert(.turns)
            }
            if countingAtStartOnly {
                flags.insert(.countStartOnly)
            }
            
            if flags == .countStartOnly {
                flags = []
            }
            
            return flags.rawValue
        }
        
        set {
            let flags = CountFlags(rawValue: newValue)
            visitsShouldBeCounted = flags.contains(.visits)
            turnIndexShouldBeCounted = flags.contains(.turns)
            countingAtStartOnly = flags.contains(.countStartOnly)
        }
    }
    
    public var hasValidName: Bool {
        name != nil && !(name!.isEmpty)
    }
    
    var _pathToFirstLeafContent: Path?
    public var pathToFirstLeafContent: Path {
        if _pathToFirstLeafContent == nil {
            _pathToFirstLeafContent = path.PathByAppendingPath(internalPathToFirstLeafContent)
        }
        return _pathToFirstLeafContent!
    }
    
    var internalPathToFirstLeafContent: Path {
        var components: [Path.Component] = []
        var container: Container? = self
        while container != nil {
            if container!.content.count > 0 {
                components.append(Path.Component(0))
                container = container!.content[0] as? Container
            }
        }
        return Path(components)
    }
    
    override init() {
        countingAtStartOnly = false
        turnIndexShouldBeCounted = false
        visitsShouldBeCounted = false
        _content = []
        namedContent = [:]
    }
    
    public func AddContent(_ contentObj: Object) throws {
        _content.append(contentObj)
        
        if contentObj.parent != nil {
            throw StoryError.contentAlreadyHasParent(parent: contentObj.parent!)
        }
        
        contentObj.parent = self
        
        TryAddNamedContent(contentObj)
    }
    
    public func AddContent(_ contentList: [Object]) throws {
        for c in contentList {
            try AddContent(c)
        }
    }
    
    public func InsertContent(_ contentObj: Object, _ index: Int) throws {
        _content.insert(contentObj, at: index)
        
        if contentObj.parent != nil {
            throw StoryError.contentAlreadyHasParent(parent: contentObj.parent!)
        }
        
        contentObj.parent = self
        
        TryAddNamedContent(contentObj)
    }
    
    public func TryAddNamedContent(_ contentObj: Object) {
        let namedContentObj = contentObj as? Nameable
        if namedContentObj != nil && namedContentObj!.hasValidName {
            AddToNamedContentOnly(namedContentObj!)
        }
    }
    
    public func AddToNamedContentOnly(_ namedContentObj: Nameable) {
        assert(namedContentObj is Object, "Can only add Objects to a Container")
        let runtimeObj = namedContentObj as! Object
        runtimeObj.parent = self
        namedContent[namedContentObj.name!] = namedContentObj
    }
    
    public func AddContentsOfContainer(_ otherContainer: Container) {
        _content.append(contentsOf: otherContainer.content)
        for obj in otherContainer.content {
            obj.parent = self
            TryAddNamedContent(obj)
        }
    }
    
    internal func ContentWithPathComponent(_ component: Path.Component) -> Object? {
        if component.isIndex {
            if component.index >= 0 && component.index < content.count {
                return content[component.index]
            }
            
            // When path is out of range, quietly return nil
            // (Useful as we step/increment forwards through content)
            else {
                return nil
            }
        }
        
        else if component.isParent {
            return self.parent
        }
        
        else {
            if component.name == nil {
                return nil
            }
            
            if let foundContent = namedContent[component.name!] {
                return foundContent as? Object
            }
            
            else {
                return nil
            }
        }
    }
    
    public func ContentAtPath(_ path: Path, partialPathStart: Int = 0, partialPathLength: Int = -1) -> SearchResult {
        var partialPathLength = partialPathLength
        if partialPathLength == -1 {
            partialPathLength = path.length
        }
        
        var result = SearchResult()
        result.approximate = false
        
        var currentContainer: Container? = self
        var currentObj: Object? = self
        
        for i in partialPathStart ..< partialPathLength {
            var comp = path.GetComponent(i)
            
            // Path component was wrong type
            if currentContainer == nil {
                result.approximate = true
                break
            }
            
            var foundObj = currentContainer!.ContentWithPathComponent(comp)
            
            // Couldn't resolve entire path?
            if foundObj == nil {
                result.approximate = true
                break
            }
            
            currentObj = foundObj
            currentContainer = foundObj as? Container
        }
        
        result.obj = currentObj
        
        return result
    }
    
    public func BuildStringOfHierarchy(_ initialSb: String, _ indentation: Int, _ pointedObj: Object?) -> String {
        var sb = initialSb
        var currentIndentation = indentation
        
        let appendIndentation = {
            let spacesPerIndent = 4
            for _ in 0 ..< spacesPerIndent * currentIndentation {
                sb.append(" ")
            }
        }
        
        appendIndentation()
        sb.append("[")
        
        if hasValidName {
            sb.append(" (\(String(describing: name)))")
        }
        
        if self === pointedObj {
            sb.append("  <---")
        }
        
        sb.append("\n")
        
        currentIndentation += 1
        
        for i in 0 ..< content.count {
            var obj = content[i]
            
            if let container = obj as? Container {
                sb = container.BuildStringOfHierarchy(sb, currentIndentation, pointedObj)
            }
            else {
                appendIndentation()
                if obj is StringValue {
                    sb.append("\"")
                    sb.append(String(describing: obj).replacingOccurrences(of: "\n", with: "\\n"))
                    sb.append("\"")
                }
                else {
                    sb.append(String(describing: obj))
                }
            }
            
            if i != content.count - 1 {
                sb.append(",")
            }
            
            if !(obj is Container) && obj === pointedObj {
                sb.append("  <---")
            }
            
            sb.append("\n")
        }
        
        var onlyNamed: [String: Nameable] = [:]
        
        for objKV in namedContent {
            let objAsObj = objKV.value as! Object
            if content.contains(where: {v in v === objAsObj}) {
                continue
            }
            else {
                onlyNamed[objKV.key] = objKV.value
            }
        }
        
        if onlyNamed.count > 0 {
            appendIndentation()
            sb.append("-- named: --\n")
            for objKV in onlyNamed {
                assert(objKV.value is Container, "Can only print out named Containers")
                var container = objKV.value as! Container
                sb = container.BuildStringOfHierarchy(sb, currentIndentation, pointedObj)
                sb.append("\n")
            }
        }
        
        currentIndentation -= 1
        appendIndentation()
        sb.append("]")
        return sb
    }
    
    public func BuildStringOfHierarchy() -> String {
        var sb = BuildStringOfHierarchy("", 0, nil)
        return sb
    }
}
