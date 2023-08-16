import Foundation

public class ListDefinition {
    private(set) var name: String = ""
    
    private var _itemNameToValues: [String: Int] = [:]
    
    public var items: [InkListItem: Int] {
        if _items.count == 0 {
            _items = [:]
            for itemNameAndValue in _itemNameToValues {
                var item = InkListItem(name, itemNameAndValue.key)
                _items[item] = itemNameAndValue.value
            }
        }
        return _items
    }
    private var _items: [InkListItem: Int] = [:]
    
    public func ValueForItem(_ item: InkListItem) -> Int {
        return _itemNameToValues[item.itemName!] ?? 0
    }
    
    public func ContainsItem(_ item: InkListItem) -> Bool {
        if item.originName != name {
            return false
        }
        
        return _itemNameToValues.keys.contains(item.itemName!)
    }
    
    public func ContainsItemWithName(_ itemName: String) -> Bool {
        return _itemNameToValues.keys.contains(itemName)
    }
    
    public func TryGetItemWithValue(_ val: Int, _ item: inout InkListItem) -> Bool {
        for namedItem in _itemNameToValues {
            if namedItem.value == val {
                item = InkListItem(name, namedItem.key)
                return true
            }
        }
        
        item = InkListItem.Null
        return false
    }
    
    public func TryGetValueForItem(_ item: InkListItem) -> Int? {
        return _itemNameToValues[item.itemName!]
    }
    
    public init(_ name: String, _ items: [String: Int]) {
        self.name = name
        _itemNameToValues = items
    }
}
