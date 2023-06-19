//
//  AheadBehind.swift
//  Gitti
//
//  Created by Kristian Bredin on 2023-03-26.
//

import Foundation

struct AheadBehind: CustomStringConvertible {
    var ahead: Int?
    var behind: Int?
    
    var description: String {
        return "\n ahead:  \(String(describing: ahead)) behind: \(String(describing: behind))"
    }
    
}

