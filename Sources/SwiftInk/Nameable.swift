//
//  File.swift
//  
//
//  Created by Malcolm Anderson on 8/14/23.
//

import Foundation

public protocol Nameable {
    var name: String? { get }
    var hasValidName: Bool { get }
}
