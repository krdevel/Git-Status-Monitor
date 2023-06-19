//
//  CommitsTableCellView.swift
//  Gitti
//
//  Created by Kristian Bredin on 2023-03-17.
//

import Cocoa

class FilesTableCellView: NSTableCellView {
    @IBOutlet weak var varietyLabel: NSTextField!
    @IBOutlet weak var fileNameLabel: NSTextField!

    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
}
