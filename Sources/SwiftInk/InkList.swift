import Foundation

/**
 The underlying type for a list item in ink. It stores the original list definition
 name as well as the item name, but without the value of the item. When the value is
 stored, it's stored in a `KeyValuePair` of `InkListItem` and `int`.
 */
public struct InkListItem: CustomStringConvertible, Equatable, Hashable {
    
    /// The name of the list where the item was originally defined.
    private(set) var originName: String?
    
    /// The main name of the item as defined in ink.
    private(set) var itemName: String?
    
    /// Create an item with the given original list definition name, and the name of this item.
    public init(_ originName: String?, _ itemName: String?) {
        self.originName = originName
        self.itemName = itemName
    }
    
    /// Create an item from a dot-separated string of the form `listDefinitionName.listItemName`.
    public init(_ fullName: String) {
        let nameParts = fullName.components(separatedBy: ".")
        self.init(nameParts[0], nameParts[1])
    }
    
    public static var Null: InkListItem {
        InkListItem(nil, nil)
    }
    
    public var isNull: Bool {
        originName == nil && itemName == nil
    }
    
    /// Get the full dot-separated name of the item, in the form `listDefinitionName.itemName`.
    public var fullName: String {
        return "\(originName ?? "?").\(itemName ?? "nil")"
    }
    
    /// Get the full dot-separated name of the item, in the form `listDefinitionName.itemName`.
    /// Calls `fullName` internally.
    public var description: String {
        fullName
    }
}

public class InkList: Equatable, Hashable, CustomStringConvertible {
    internal var internalDict: [InkListItem: Int] = [:]
    
    /// Create a new empty ink list.
    public init() {}
    
    /// Create a new ink list that contains the same contents as another list.
    public init(_ otherList: InkList) {
        self.internalDict = otherList.internalDict
        
        var otherOriginNames = otherList.originNames
        if let otherOriginNames = otherList.originNames {
            _originNames = Array<String>(otherOriginNames)
        }
        
        if otherList.origins != nil {
            origins = Array<ListDefinition>(otherList.origins)
        }
    }
    
    /// Create a new empty ink list that's intended to hold items from a particular origin
    /// list definition. The origin Story is needed in order to be able to look up that definition.
    public init(_ singleOriginListName: String, _ originStory: Story) {
        SetInitialOriginName(singleOriginListName)
        
        var def: ListDefinition
        if originStory.listDefinitions.TryListGetDefinition(singleOriginListName, def) {
            origins = [def]
        }
        else {
            fatalError("InkList origin could not be found in story when constructing new list: \(singleOriginListName)")
        }
    }
    
    public init(_ singleElement: (key: InkListItem, value: Int)) {
        internalDict[singleElement.key] = singleElement.value
    }
    
    
    
    /// Converts a string to an ink list and returns for use in the story.
    /// - Parameters:
    ///   - myListItem: Item key. (From C# docs, that seems wrong???)
    ///   - originStory: Origin story.
    /// - Returns: `InkList` created from string list item
    public static func FromString(_ myListItem: String, _ originStory: Story) -> InkList {
        var listValue = originStory.listDefinitions.FindSingleItemListWithName(myListItem)
        if listValue != nil {
            return InkList(listValue.value)
        }
        else {
            fatalError("Could not find the InkListItem from the string \"\(myListItem)\" to create an InkList because it doesn't exist in the original list definition in ink.")
        }
    }
    
    /// Adds the given item to the ink list. Note that the item must come from a list definition that
    /// is already "known" to this list, so that the item's value can be looked up. By "known", we mean
    /// that it already has items in it from that source, or it did at one point - it can't be a
    /// completely fresh empty list, or a list that only contains items from a different list definition.
    /// - Parameter item: The item to add.
    public func AddItem(_ item: InkListItem) {
        if item.originName == nil {
            AddItem(item.itemName!)
            return
        }
        
        for origin in origins {
            if origin.name == item.originName {
                var intVal: Int
                if let intVal = origin.TryGetValueForItem(item) {
                    internalDict[item] = intVal
                    return
                }
                else {
                    fatalError("Could not add the item \(item) to this list because it doesn't exist in the original list definition in ink.")
                }
            }
        }
        
        fatalError("Failed to add item to list because the item was from a new list definition that wasn't previously known to this list. Only items from previously known lists can be used, so that the int value can be found.")
    }
    
    
    /// Adds the given item to the ink list, attempting to find the origin list definition that it belongs to.
    /// The item must therefore come from a list definition that is already "known" to this list, so that the
    /// item's value can be looked up. By "known", we mean that it already has items in it from that source, or
    /// it did at one point - it can't be a completely fresh empty list, or a list that only contains items from
    /// a different list definition
    /// - Parameter itemName: The name of the item to add(?)
    public func AddItem(_ itemName: String) {
        var foundListDef: ListDefinition? = nil
        
        for origin in origins {
            if origin.ContainsItemWithName(itemName) {
                if foundListDef != nil{
                    fatalError("Could not add the item \(itemName) to this list because it could come from either \(origin.name) or \(foundListDef!.name)")
                }
                else {
                    foundListDef = origin
                }
            }
        }
        
        if foundListDef == nil {
            fatalError("Could not add the item \(itemName)to this list because it isn't known to any list definitions previously associated with this list.")
        }
        
        var item = InkListItem(foundListDef!.name, itemName)
        var itemVal = foundListDef!.ValueForItem(item)
        internalDict[item] = itemVal
    }
    
    
    /// Returns `true` if this ink list contains an item with the given short name
    /// (ignoring the original list where it was defined).
    /// - Parameter itemName: The name of the item to check for.
    /// - Returns: `true` if this ink list contains an item named `itemName`, and `false` otherwise.
    public func ContainsItemNamed(_ itemName: String) -> Bool {
        for itemWithValue in internalDict {
            if itemWithValue.key.itemName == itemName {
                return true
            }
        }
        return false
    }
    
    /// Story has to set this so that the value knows its origin,
    /// necessary for certain operations (e.g. interacting with ints).
    /// Only the story has access to the full set of lists, so that
    /// the origin can be resolved from the `originListName`.
    public var origins: [ListDefinition] = []
    public var originOfMaxItem: ListDefinition? {
        if origins == nil {
            return nil
        }
        
        var maxOriginName = maxItem.key.originName
        for origin in origins {
            if origin.name == maxOriginName {
                return origin
            }
        }
        
        return nil
    }
    
    /// Origin name needs to be serialised when content is empty,
    /// assuming a name is available, for list definitions with variable
    /// that is currently empty.
    public var originNames: [String]? {
        if internalDict.count > 0 {
            _originNames = []
            
            for itemAndValue in internalDict {
                _originNames!.append(itemAndValue.key.originName!)
            }
        }
        
        return _originNames
    }
    private var _originNames: [String]? = []
    
    public func SetInitialOriginName(_ initialOriginName: String) {
        _originNames = [initialOriginName]
    }
    
    public func SetInitialOriginNames(_ initialOriginNames: [String]?) {
        if initialOriginNames == nil {
            _originNames = nil
        }
        else {
            _originNames = Array<String>(initialOriginNames!)
        }
    }
    
    /// Get the maximum item in the list, equivalent to calling `LIST_MAX(list)` in ink.
    public var maxItem: (key: InkListItem, value: Int) {
        var max: (key: InkListItem?, value: Int?) = (nil, nil)
        for kv in internalDict {
            if max.key == nil || kv.value > max.value! {
                max = kv
            }
        }
        return (max.key!, max.value!)
    }
    
    /// Get the minimum item in the list, equivalent to calling `LIST_MIN(list)` in ink.
    public var minItem: (key: InkListItem, value: Int) {
        var min: (key: InkListItem?, value: Int?) = (nil, nil)
        for kv in internalDict {
            if min.key == nil || kv.value < min.value! {
                min = kv
            }
        }
        return (min.key!, min.value!)
    }
    
    /// The inverse of the list, equivalent to calling `LIST_INVERSE(list)` in ink.
    public var inverse: InkList {
        var list = InkList()
        if origins != nil {
            for origin in origins {
                for itemAndValue in origin.items {
                    if !internalDict.keys.contains(itemAndValue.key) {
                        list.internalDict[itemAndValue.key] = itemAndValue.value
                    }
                }
            }
        }
        return list
    }
    
    /// The list of all items from the original list definition, equivalent to calling
    /// `LIST_ALL(list)` in ink.
    public var all: InkList {
        var list = InkList()
        if origins != nil {
            for origin in origins {
                for itemAndValue in origin.items {
                    list.internalDict[itemAndValue.key] = itemAndValue.value
                }
            }
        }
        return list
    }
    
    /// Returns a new list that is the combination of the current list and one that's
    /// passed in. Equivalent to calling `(list1 + list2)` in ink.
    public func Union(_ otherList: InkList) -> InkList {
        var union = InkList(self)
        for kv in otherList.internalDict {
            union.internalDict[kv.key] = kv.value
        }
        return union
    }
    
    /// Returns a new list that is the intersection of the current list with another
    /// list that's passed in - i.e. a list of the items that are shared between the
    /// two other lists. Equivalent to calling `(list1 ^ list2)` in ink.
    public func Intersect(_ otherList: InkList) -> InkList {
        var intersection = InkList()
        for kv in internalDict {
            if otherList.internalDict.keys.contains(kv.key) {
                intersection.internalDict[kv.key] = kv.value
            }
        }
        return intersection
    }
    
    /// Fast test for the existence of any intersection between the current list and another
    public func HasIntersection(_ otherList: InkList) -> Bool {
        for kv in internalDict {
            if otherList.internalDict.keys.contains(kv.key) {
                return true
            }
        }
        return false
    }
    
    /// Returns a new list that's the same as the current one, except with the given items
    /// removed that are in the passed-in list. Equivalent to calling `(list1 - list2)` in ink.
    /// - Parameter listToRemove: List to remove.
    public func Without(_ listToRemove: InkList) -> InkList {
        var result = InkList(self)
        for kv in listToRemove.internalDict {
            result.internalDict.removeValue(forKey: kv.key)
        }
        return result
    }
    
    /// Returns `true` if the current list contains all the items that are in the list that
    /// is passed in. Equivalent to calling `(list1 ? list2)` in ink.
    public func Contains(_ otherList: InkList) -> Bool {
        if otherList.internalDict.count == 0 || internalDict.count == 0 {
            return false
        }
        for kv in otherList.internalDict {
            if !internalDict.keys.contains(kv.key) {
                return false
            }
        }
        return true
    }
    
    /// Returns true if the current list contains an item matching the given name.
    public func Contains(_ listItemName: String) -> Bool {
        for kv in internalDict {
            if kv.key.itemName == listItemName {
                return true
            }
        }
        return false
    }
    
    /// Returns `true` if all the item values in the current list are greater than all the
    /// item values in the passed-in list. Equivalent to calling `(list1 > list2)` in ink.
    public func GreaterThan(_ otherList: InkList) -> Bool {
        if internalDict.count == 0 {
            return false
        }
        if otherList.internalDict.count == 0 {
            return true
        }
        
        // All greater
        return minItem.value > otherList.maxItem.value
    }
    
    /// Returns `true` if the item values in the current list overlap or are all greater than
    /// the item values in the passed-in list. None of the item values in the current list must
    /// fall below the item values in the passed-in list. Equivalent to `(list1 >= list2)` in ink,
    /// or `LIST_MIN(list1) >= LIST_MIN(list2) && LIST_MAX(list1) >= LIST_MAX(list2)`.
    public func GreaterThanOrEquals(_ otherList: InkList) -> Bool {
        if internalDict.count == 0 {
            return false
        }
        if otherList.internalDict.count == 0 {
            return true
        }
        
        return minItem.value >= otherList.minItem.value && maxItem.value >= otherList.maxItem.value
    }
    
    /// Returns `true` if all the item values in the current list are less than all the
    /// item values in the passed-in list. Equivalent to calling `(list1 < list2)` in ink.
    public func LessThan(_ otherList: InkList) -> Bool {
        if otherList.internalDict.count == 0 {
            return false
        }
        if internalDict.count == 0 {
            return true
        }
        
        return maxItem.value < otherList.minItem.value
    }
    
    /// Returns `true` if the item values in the current list overlap or are all less than
    /// the item values in the passed-in list. None of the item values in the current list must
    /// go above the item values in the passed-in list. Equivalent to `(list1 <= list2)` in ink,
    /// or `LIST_MAX(list1) <= LIST_MAX(list2) && LIST_MIN(list1) <= LIST_MIN(list2)`.
    public func LessThanOrEquals(_ otherList: InkList) -> Bool {
        if otherList.internalDict.count == 0 {
            return false
        }
        if internalDict.count == 0 {
            return true
        }
        
        return maxItem.value <= otherList.maxItem.value && minItem.value <= otherList.minItem.value
    }
    
    public func MaxAsList() -> InkList {
        if internalDict.count > 0 {
            return InkList(maxItem)
        }
        else {
            return InkList()
        }
    }
    
    public func MinAsList() -> InkList {
        if internalDict.count > 0 {
            return InkList(minItem)
        }
        else {
            return InkList()
        }
    }
    
    /// Returns a sublist with the elements given the minimum and maximum bounds.
    /// The bounds can either be `Int`s which are indices into the entire (sorted) list,
    /// or they can be `InkList`s themselves. These are intended to be single-item lists so
    /// you can specify the upper and lower bounds. If you pass in multi-item lists, it'll
    /// use the minimum and maximum items in those lists respectively.
    /// WARNING: Calling this method requires a full sort of all the elements in the list.
    public func ListWithSubrange(_ minBound: Any?, _ maxBound: Any?) -> InkList {
        if internalDict.count == 0 {
            return InkList()
        }
        
        var ordered = orderedItems
        
        var minValue = 0
        var maxValue = Int.max
        
        if minBound is Int {
            minValue = minBound as! Int
        }
        else {
            if minBound is InkList && (minBound as! InkList).internalDict.count > 0 {
                minValue = (minBound as! InkList).minItem.value
            }
        }
        
        if maxBound is Int {
            maxValue = maxBound as! Int
        }
        else {
            // TODO: This was translated straight from the C# source but I think it's a bug!
            // This if statement should be using maxBound instead of minBound I think!!
            if minBound is InkList && (minBound as! InkList).internalDict.count > 0 {
                maxValue = (maxBound as! InkList).maxItem.value
            }
        }
        
        var subList = InkList()
        subList.SetInitialOriginNames(originNames)
        for item in ordered {
            if item.value >= minValue && item.value <= maxValue {
                subList.internalDict[item.key] = item.value
            }
        }
        
        return subList
    }
    
    /// Returns `true` if the passed object is also an ink list that contains
    /// the same items as the current list, `false` otherwise.
    public static func == (lhs: InkList, rhs: InkList) -> Bool {
        if lhs.internalDict.count != rhs.internalDict.count {
            return false
        }
        
        for kv in lhs.internalDict {
            // TODO: Does this also need to be checked the other way around?
            // (i.e., this just verifies that `rhs` is a subset of `lhs` I think??)
            if !rhs.internalDict.keys.contains(kv.key) {
                return false
            }
        }
        
        return true
    }
    
    public func hash(into hasher: inout Hasher) {
        for kv in internalDict {
            hasher.combine(kv.key.hashValue)
        }
    }
    
    public var orderedItems: [(key: InkListItem, value: Int)] {
        // TODO: Make sure that the sorting is correct, since Swift doesn't have CompareTo()
        var ordered: [(key: InkListItem, value: Int)] = []
        ordered.append(contentsOf: internalDict)
        ordered.sort { x, y in
            if x.value == y.value {
                return x.key.originName! < y.key.originName!
            }
            else {
                return x.value < y.value
            }
        }
        return ordered
    }
    
    /// Returns a `String` in the form "a, b, c" with the names of the items in the list, without
    /// the origin list definition names. Equivalent to writing `{list}` in ink.
    public var description: String {
        var ordered = orderedItems
        
        var sb = ""
        for i in 0 ..< ordered.count {
            if i > 0 {
                sb += ", "
            }
            
            var item = ordered[i].key
            sb += item.itemName ?? ""
        }
        
        return sb
    }
    
    
    public var count: Int {
        internalDict.count
    }
}
