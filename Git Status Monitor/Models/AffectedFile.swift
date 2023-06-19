//
//  AffectedFile.swift
//  Gitti
//
//  Created by Kristian Bredin on 2023-03-19.
//

import Foundation

struct AffectedFile: CustomStringConvertible {
    
    var variety: String
    var fileName: String
    
    init(variety: String, fileName: String) {
        self.variety = variety
        self.fileName = fileName
    }
    
    var description: String {
        return "\n variety:  \(variety) fileName: \(fileName)"
    }
    
    
    
}
