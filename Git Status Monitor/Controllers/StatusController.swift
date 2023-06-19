//
//  CommitsController.swift
//  Gitti
//
//  Created by Kristian Bredin on 2023-03-17.
//

import Cocoa

class StatusController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, AffectedFilesDelegate {
        
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var pathLabel: NSTextField!
    
    @IBOutlet weak var gitRepoStatusImageView: NSImageView!
    
    @IBOutlet weak var localBranchLabel: NSTextField!
    @IBOutlet weak var localBranchNameLabel: NSTextField!
    @IBOutlet weak var localAheadImageView: NSImageView!
    @IBOutlet weak var aheadNumberLabel: NSTextField!
    
    @IBOutlet weak var remoteBranchLabel: NSTextField!
    @IBOutlet weak var remoteBranchNameLabel: NSTextField!
    @IBOutlet weak var remoteBehindImageView: NSImageView!
    @IBOutlet weak var behindNumberLabel: NSTextField!
    
    var changedFiles: [AffectedFile] = []
    
    var workingDiectoryPath = "" // Persist
    
    var timerForStatus: Timer?
    var timerForAheadBehind: Timer?
    
    var timerIntervalForStatus = 2.0
    var timerIntervalForAheadBehind = 10.0

    
    override func viewDidLoad() {
        readWorkingDiectoryPathFromDisk()
        pathLabel.stringValue = workingDiectoryPath
        self.hideAheadLabels()
        self.hideBehindLabels()
        tableView.selectionHighlightStyle = NSTableView.SelectionHighlightStyle.none
        if directoryExists(path: workingDiectoryPath) {
            gitStatus()
        } else {
            setStatusToRed()
        }
    }
    
    @objc  func writeWorkingDiectoryPathToDisk() {
        print("writeWorkingDiectoryPathToDisk")
        UserDefaults.standard.set(workingDiectoryPath, forKey: "workingDiectoryPath")
    }
    
    func readWorkingDiectoryPathFromDisk() {
        print("readWorkingDiectoryPathFromDisk")
        workingDiectoryPath = UserDefaults.standard.string(forKey: "workingDiectoryPath") ?? ""
    }
    
    @IBAction func setFolderAction(_ sender: Any) {
        let dialog = NSOpenPanel();
        dialog.title                   = "Choose a folder";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = true;
        dialog.allowsMultipleSelection = false;
        dialog.canChooseDirectories = true;
        dialog.canChooseFiles = false;

        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file
            
            if (result != nil) {
                stopTimers()
                
                let path: String = result!.path
                self.workingDiectoryPath = path
                pathLabel.stringValue = workingDiectoryPath
                self.hideAheadLabels()
                self.hideBehindLabels()

                if directoryExists(path: workingDiectoryPath) {
                    gitStatus()
                    writeWorkingDiectoryPathToDisk()
                }
            }
        } else {
            return
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return changedFiles.count
    }
        
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("commitsCell"), owner: self) as! FilesTableCellView
        let variety = "\(changedFiles[row].variety):"
        let fileName = changedFiles[row].fileName
        self.colorizeLabel(cell: cell, variety: variety)
        cell.varietyLabel.stringValue = "\(variety)" // " changedFiles[row].fileName
        cell.fileNameLabel.stringValue = "\(fileName)"

        return cell
    }
    
    func colorizeLabel(cell: FilesTableCellView, variety: String) {
        var color: NSColor

        switch variety {
        case "Modified:": color = NSColor(red: 0, green: 0.7, blue: 1, alpha: 1)
        case "Added:": color = NSColor(red: 0, green: 1, blue: 0, alpha: 1)
        case "Deleted:": color = NSColor(red: 1, green: 0, blue: 0, alpha: 1)
        default:
            color = cell.varietyLabel.textColor!
            print("CommitsController colorizeLabel switch default...")
        }
        cell.varietyLabel.textColor = color
    }
    
    func runGitStatusPeriodically(delay: Double, repeats: Bool) {
        self.timerForStatus = Timer.scheduledTimer(timeInterval: delay, target: self, selector: #selector(gitStatusInCurrentDirectory), userInfo: nil, repeats: repeats)
    }
    
    func runAheadBehindPeriodically(delay: Double, repeats: Bool) {
        self.timerForAheadBehind = Timer.scheduledTimer(timeInterval: delay, target: self, selector: #selector(gitAheadBehindInCurrentDirectory), userInfo: nil, repeats: repeats)
    }
    
    func stopTimers() {
        self.timerForStatus?.invalidate()
        self.timerForAheadBehind?.invalidate()
    }
    
    func gitStatus() {
        let git = GitService()

        if git.isGitRepo(workingDiectoryPath) {
            setStatusToGreen()
            self.localBranchLabel.isHidden = false
            self.remoteBranchLabel.isHidden = false
            gitAheadBehindInCurrentDirectory()
            gitStatusInCurrentDirectory()
            git.currentLocalBranch(workingDiectoryPath, caller: self)
            git.currentlyTrackedRemoteBranch(workingDiectoryPath, caller: self)
            
            runGitStatusPeriodically(delay: timerIntervalForStatus, repeats: true)
            runAheadBehindPeriodically(delay: timerIntervalForAheadBehind, repeats: true)
        } else {
            setStatusToRed()
            self.localBranchLabel.isHidden = true
            self.localBranchNameLabel.stringValue = ""
            self.remoteBranchLabel.isHidden = true
            self.remoteBranchNameLabel.stringValue = ""
            
            self.changedFiles = []
            self.tableView.reloadData()
        }
    }
    
    func directoryExists(path: String) -> Bool {
        var isDir : ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
    
    @objc func gitStatusInCurrentDirectory() {
        let git = GitService()
        git.gitStatus(workingDiectoryPath, caller: self)
        git.currentLocalBranch(workingDiectoryPath, caller: self)
        git.currentlyTrackedRemoteBranch(workingDiectoryPath, caller: self)
    }
    
    @objc func gitAheadBehindInCurrentDirectory() {
        let git = GitService()
        git.localIsAheadBehind(workingDiectoryPath, caller: self)
    }
    
    func setStatusToGreen() {
        gitRepoStatusImageView.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Yes")
        gitRepoStatusImageView.contentTintColor = NSColor.systemGreen
    }
    
    func setStatusToRed() {
        gitRepoStatusImageView.image = NSImage(systemSymbolName: "nosign", accessibilityDescription: "No")
        gitRepoStatusImageView.contentTintColor = NSColor.systemPink
    }
    
    func hideAheadLabels() {
        self.localAheadImageView.isHidden = true
        self.aheadNumberLabel.isHidden = true
    }
    
    func showAheadLabels() {
        self.localAheadImageView.isHidden = false
        self.aheadNumberLabel.isHidden = false
    }
    
    func hideBehindLabels() {
        self.remoteBehindImageView.isHidden = true
        self.behindNumberLabel.isHidden = true
    }
    
    func showBehindLabels() {
        self.remoteBehindImageView.isHidden = false
        self.behindNumberLabel.isHidden = false
    }

    func affectedFilesfetched(affectedFiles: [AffectedFile]) {
        DispatchQueue.main.async {
            self.changedFiles = affectedFiles
            self.tableView.reloadData()
        }
    }
    
    func currentLocalBranchNameFetched(branchname: String) {
        DispatchQueue.main.async {
            self.localBranchNameLabel.stringValue = branchname
        }
    }
    
    func currentlyTrackedRemoteBranchNameFetched(response: GitResponse) {
        DispatchQueue.main.async {
            if response.error != nil {
                self.remoteBranchNameLabel.isHidden = true
                self.remoteBranchNameLabel.stringValue = ""
            }  else {
                self.remoteBranchNameLabel.isHidden = false
                self.remoteBranchNameLabel.stringValue = response.result ?? ""
            }
        }
    }

    func aheadBehindFetched(aheadBehind: AheadBehind) {
        DispatchQueue.main.async {
            if aheadBehind.ahead != nil {
                self.aheadNumberLabel.stringValue = String(aheadBehind.ahead!)
                self.showAheadLabels()
            } else {
                self.aheadNumberLabel.stringValue = ""
                self.hideAheadLabels()
            }
            if aheadBehind.behind != nil {
                self.behindNumberLabel.stringValue = String(aheadBehind.behind!)
                self.showBehindLabels()
            } else {
                self.behindNumberLabel.stringValue = ""
                self.hideBehindLabels()
            }
        }
    }



    

}
