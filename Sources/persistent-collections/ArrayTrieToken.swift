import Foundation

public enum ArrayTrieToken: Equatable {
    case open, close, comma, other(String)
}

public extension Array where Element == ArrayTrieToken {
    func combineCharacterTokens() -> [ArrayTrieToken] {
        return combine()
    }
    
    func combine() -> [ArrayTrieToken] {
        var s = ""
        var tokens: [ArrayTrieToken] = []
        for token in self {
            switch token {
            case .other(let char):
                s.append(char)
            default:
                if s != "" { tokens.append(.other(s)) }
                tokens.append(token)
            }
        }
        if s != "" {
            tokens.append(.other(s))
        }
        return tokens
    }
}
