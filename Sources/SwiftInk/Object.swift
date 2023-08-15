//
//  File.swift
//  
//
//  Created by Malcolm Anderson on 8/14/23.
//

import Foundation

public class Object {
    public var parent: Object?
    
    private var _path: Path?
    
    // TODO: debugMetadata
    
    // TODO: ownDebugMetadata
    
    public func DebugLineNumberOfPath(path: Path?) -> Int? {
        if path == nil {
            return nil
        }
        
        let root = self.rootContentContainer
        if root != nil {
            let targetContent = root.ContentAtPath(path).obj
            if targetContent != nil {
                let dm = targetContent.debugMetadata
                if dm != nil {
                    return dm.startLineNumber
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
                let comps: [Path.Component] = []
                
                var child: Object? = self
                var container: Container? = child!.parent
                
                while container != nil {
                    var namedChild = child
                    if namedChild != nil && namedChild.hasValidName {
                        comps.append(Path.Component(namedChild.name))
                    }
                    else {
                        // TODO: fix this
                        comps.append(Path.Component(container.content.firstIndex(of: child)))
                    }
                    
                    child = container
                    container = container!.parent
                }
                
                _path = Path(comps)
            }
        }
        return _path!
    }
    
    public var rootContentContainer: Container {
        var ancestor: Object = self
        while ancestor.parent != nil {
            ancestor = ancestor.parent!
        }
        return ancestor
    }
}
