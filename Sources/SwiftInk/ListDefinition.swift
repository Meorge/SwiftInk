import Foundation

public class ListDefinition: Equatable {
    public static func == (lhs: ListDefinition, rhs: ListDefinition) -> Bool {
        return lhs.name == rhs.name && lhs._itemNameToValues == rhs._itemNameToValues
    }
    
    private(set) var name: String = ""
    
    private var _itemNameToValues: [String: Int] = [:]
    
    public var items: [InkListItem: Int] {
        if _items.count == 0 {
            _items = [:]
            for itemNameAndValue in _itemNameToValues {
                let item = InkListItem(name, itemNameAndValue.key)
                _items[item] = itemNameAndValue.value
            }
        }
        return _items
    }
    private var _items: [InkListItem: Int] = [:]
    
    public func value(forItem item: InkListItem) -> Int {
        return _itemNameToValues[item.itemName!] ?? 0
    }
    
    public func contains(_ item: InkListItem) -> Bool {
        if item.originName != name {
            return false
        }
        
        return _itemNameToValues.keys.contains(item.itemName!)
    }
    
    public func contains(named itemName: String) -> Bool {
        return _itemNameToValues.keys.contains(itemName)
    }
    
    public func tryGetItem(withValue val: Int) -> InkListItem? {
        for namedItem in _itemNameToValues {
            if namedItem.value == val {
                return InkListItem(name, namedItem.key)
            }
        }
        return nil
    }
    
    public func tryGetValue(forItem item: InkListItem) -> Int? {
        return _itemNameToValues[item.itemName!]
    }
    
    public init(named name: String, withItems items: [String: Int]) {
        self.name = name
        _itemNameToValues = items
    }
}
