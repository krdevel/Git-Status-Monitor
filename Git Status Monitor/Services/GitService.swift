//
//  GitService.swift
//  Gitti
//
//  Created by Kristian Bredin on 2023-03-17.
//

import Foundation

struct GitResponse {
    var result: String?
    var error: GitError?
}

struct GitError {
    var message: String
}

class GitService {
    // Singleton?
//    static let shared = APIService()
    var delegate: AffectedFilesDelegate?

    // xcrun: error: cannot be used within an App Sandbox.
    func runGitCommand(_ currentDirectory: String, _ arguments: [String]) -> GitResponse {
        var response = GitResponse()
        
        let task = Process()
        task.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
        task.launchPath = "/usr/bin/git"
        task.arguments = arguments
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = errorPipe
        
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        if errorData.count > 0 {
            let errorOutput = String(data: errorData, encoding: String.Encoding.utf8)
            response.error = GitError(message: errorOutput!)
        } else {
            let output = String(data: data, encoding: String.Encoding.utf8)
            response.result = output
        }
        return response
    }
    
    func gitFetch(_ currentDirectory: String, caller: AffectedFilesDelegate, completion: @escaping (GitResponse) -> Void) {
        DispatchQueue.global().async {
            self.delegate = caller
            let response = self.runGitCommand(currentDirectory, ["fetch",])
            completion(response)
        }
    }
    
    func isGitRepo(_ currentDirectory: String) -> Bool {
        let response = runGitCommand(currentDirectory, ["status"])
        return response.error == nil
    }
    
    func gitStatus(_ currentDirectory: String, caller: AffectedFilesDelegate) {
        DispatchQueue.global().async {
            self.delegate = caller
            let response = self.runGitCommand(currentDirectory, ["status", "--porcelain", "-u",])
            if response.error != nil {
                return
            }
            guard let arr = response.result?.components(separatedBy: "\n") else {
                return
            }
            let resultArr = self.affectedFiles(array: arr)
 
            self.delegate?.affectedFilesfetched(affectedFiles: resultArr)
        }
    }
    
    func currentLocalBranch(_ currentDirectory: String, caller: AffectedFilesDelegate) {
        DispatchQueue.global().async {
            self.delegate = caller
            let branchNameResponse = self.runGitCommand(currentDirectory, ["symbolic-ref", "--short", "HEAD",])
            if branchNameResponse.error != nil {
                return
            }
            if let result =  branchNameResponse.result {
                self.delegate?.currentLocalBranchNameFetched(branchname: result)
            }
        }
    }
    
    func currentlyTrackedRemoteBranch(_ currentDirectory: String, caller: AffectedFilesDelegate) {
        DispatchQueue.global().async {
            self.delegate = caller
            var branchNameResponse = self.runGitCommand(currentDirectory, ["rev-parse", "--symbolic-full-name", "@{u}"])
            if let _ =  branchNameResponse.result {
                branchNameResponse.result = self.replaceOccurences(string: branchNameResponse.result!, find: "refs/remotes/", replaceWith: "")
            }
            self.delegate?.currentlyTrackedRemoteBranchNameFetched(response: branchNameResponse)
        }
    }
    
    // Yeah, this is a bit over the top...
    func localIsAheadBehind(_ currentDirectory: String, caller: AffectedFilesDelegate) {
        DispatchQueue.global().async {
            self.delegate = caller
            self.gitFetch(currentDirectory, caller: caller, completion: {gitFetchResponse in
                let response = self.runGitCommand(currentDirectory, ["status", "--porcelain", "-b"])
                
                if response.error != nil {
                    return
                }
                guard let resultString = response.result else {
                    return
                }
                guard let indexOfFirstOpeningBracket =  resultString.firstIndex(of: "["), let indexOFirstClosingBracket = resultString.firstIndex(of: "]") else {
                    //  print("DIDNT FIND")
                    self.delegate?.aheadBehindFetched(aheadBehind: AheadBehind(ahead: nil, behind: nil))
                    return
                }
                let startIndex = resultString.index(after: indexOfFirstOpeningBracket)
                let endIndex = indexOFirstClosingBracket
                let range = startIndex..<endIndex
                let cleanedString = String(resultString[range])
                var stringArray = cleanedString.components(separatedBy: ", ")
                guard let _ = (resultString.range(of: "[")?.upperBound), let _ = (resultString.range(of: "]")?.upperBound) else {
                    return
                }
                var aheadBehind = AheadBehind()
                
                stringArray = stringArray.map { string in
                    let cleanedStringArray = string.components(separatedBy: " ")
                    switch cleanedStringArray.first {
                    case "ahead": aheadBehind.ahead = Int(cleanedStringArray.last!)
                    case "behind": aheadBehind.behind = Int(cleanedStringArray.last!)
                    default: return ""
                    }
                    return self.replaceOccurences(string: string, find: "\n", replaceWith: "")
                }
                self.delegate?.aheadBehindFetched(aheadBehind: aheadBehind)
            })
        }
    }
    
    func affectedFiles(array: [String]) -> [AffectedFile] {
        var result: [AffectedFile] = []
        _ = array.map { string in
            if(string.count > 0) {
                let beginning = beginningOfString(string: string, end: 3)
                var fileName = endOfString(string: string, start: 3)
                fileName = trimFirstAndLast(string: fileName, first: "\"", last: "\"")
                fileName = replaceOccurences(string: fileName, find: "\\\"", replaceWith: "\"")
                
                switch beginning {
                case " D ": result.append(AffectedFile(variety: "Deleted", fileName: fileName))
                case "?? ": result.append(AffectedFile(variety: "Added", fileName: fileName))
                case " M ": result.append(AffectedFile(variety: "Modified", fileName: fileName))
                default:
                    let _ = 0
                }
            }
            return string
        }
        return result
    }
    
    func beginningOfString(string: String, end: Int) -> Substring {
        let endIndex = string.index(string.startIndex, offsetBy: end)
        let range: Range<String.Index> = string.startIndex..<endIndex
        
        return string[range]
    }
    
    func endOfString(string: String, start: Int) -> String {
        let startIndex = string.index(string.startIndex, offsetBy: start)
        let endIndex = string.index(string.startIndex, offsetBy: string.count)
        let range: Range<String.Index> = startIndex..<endIndex
        
        return String(string[range])
    }
    
    func trimFirstAndLast(string: String, first: String, last: String) -> String {
        if string.first == first.first && string.last == last.first {
            var returnString = string
            returnString.removeFirst()
            returnString.removeLast()
            
            return returnString
        }
        return string
    }
    
    func replaceOccurences(string: String, find stringToReplace: String, replaceWith replacement: String) -> String {
        return string.replacingOccurrences(of: stringToReplace, with: replacement, options: NSString.CompareOptions.literal)
    }

    
    
}

// Or GitStatusDelegate. That's better, I think
protocol AffectedFilesDelegate {
    func affectedFilesfetched(affectedFiles: [AffectedFile])
    func currentLocalBranchNameFetched(branchname: String)
    func currentlyTrackedRemoteBranchNameFetched(response: GitResponse)
    func aheadBehindFetched(aheadBehind: AheadBehind)


}
