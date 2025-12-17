//
//  CheatCodeParser.swift
//  Yearn
//
//  Parser for various cheat code formats (Game Genie, Action Replay, etc.)
//

import Foundation

// MARK: - Cheat Code

struct CheatCode: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var code: String
    var format: CheatFormat
    var isEnabled: Bool
    var gameId: UUID?
    
    // Parsed data
    var address: UInt32?
    var value: UInt8?
    var compare: UInt8?
    
    init(id: UUID = UUID(), name: String, code: String, format: CheatFormat, isEnabled: Bool = true, gameId: UUID? = nil) {
        self.id = id
        self.name = name
        self.code = code.uppercased().replacingOccurrences(of: " ", with: "")
        self.format = format
        self.isEnabled = isEnabled
        self.gameId = gameId
        
        // Parse the code
        let parsed = CheatCodeParser.parse(code: self.code, format: format)
        self.address = parsed.address
        self.value = parsed.value
        self.compare = parsed.compare
    }
    
    var isValid: Bool {
        address != nil && value != nil
    }
}

// MARK: - Cheat Format

enum CheatFormat: String, Codable, CaseIterable, Identifiable {
    case gameGenie = "Game Genie"
    case actionReplay = "Action Replay"
    case raw = "Raw (Address:Value)"
    case gameShark = "GameShark"
    case codeBreaker = "Code Breaker"
    
    var id: String { rawValue }
    
    var placeholder: String {
        switch self {
        case .gameGenie: return "AAAA-AAAA or AAAA-AAAA-AAAA"
        case .actionReplay: return "XXXXXXXX YYYY"
        case .raw: return "XXXX:YY"
        case .gameShark: return "XXXXXXXX YYYY"
        case .codeBreaker: return "XXXXXXXX YYYY"
        }
    }
    
    var description: String {
        switch self {
        case .gameGenie:
            return "6 or 8 character codes for NES/SNES/GB"
        case .actionReplay:
            return "8 digit address + 4 digit value"
        case .raw:
            return "Direct memory address and value"
        case .gameShark:
            return "8 digit code for N64/GBA/PS1"
        case .codeBreaker:
            return "8 digit code for GBA"
        }
    }
    
    var supportedSystems: [GameSystem] {
        switch self {
        case .gameGenie:
            return [.nes, .snes, .gbc, .genesis]
        case .actionReplay:
            return [.snes, .gbc, .gba, .nds]
        case .raw:
            return GameSystem.allCases
        case .gameShark:
            return [.n64, .gba, .ps1]
        case .codeBreaker:
            return [.gba]
        }
    }
}

// MARK: - Cheat Code Parser

struct CheatCodeParser {
    
    // MARK: - Parse Result
    
    struct ParseResult {
        let address: UInt32?
        let value: UInt8?
        let compare: UInt8?
        let error: String?
    }
    
    // MARK: - Main Parse Function
    
    static func parse(code: String, format: CheatFormat) -> ParseResult {
        let cleanCode = code.uppercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        
        switch format {
        case .gameGenie:
            return parseGameGenie(cleanCode)
        case .actionReplay:
            return parseActionReplay(cleanCode)
        case .raw:
            return parseRaw(code)
        case .gameShark:
            return parseGameShark(cleanCode)
        case .codeBreaker:
            return parseCodeBreaker(cleanCode)
        }
    }
    
    // MARK: - Game Genie Parser
    
    private static func parseGameGenie(_ code: String) -> ParseResult {
        // NES Game Genie: 6 or 8 characters
        // SNES Game Genie: 8 characters (XXXX-XXXX format)
        // GB Game Genie: 6 or 9 characters
        
        let letters = "APZLGITYEOXUKSVN"
        
        guard code.allSatisfy({ letters.contains($0) }) else {
            return ParseResult(address: nil, value: nil, compare: nil, error: "Invalid Game Genie character")
        }
        
        switch code.count {
        case 6:
            // NES 6-letter code
            return parseNESGameGenie6(code, letters: letters)
        case 8:
            // NES 8-letter code or SNES
            return parseNESGameGenie8(code, letters: letters)
        case 9:
            // GB 9-character code
            return parseGBGameGenie(code, letters: letters)
        default:
            return ParseResult(address: nil, value: nil, compare: nil, error: "Invalid code length")
        }
    }
    
    private static func parseNESGameGenie6(_ code: String, letters: String) -> ParseResult {
        let chars = Array(code)
        var values: [Int] = []
        
        for char in chars {
            guard let index = letters.firstIndex(of: char) else {
                return ParseResult(address: nil, value: nil, compare: nil, error: "Invalid character")
            }
            values.append(letters.distance(from: letters.startIndex, to: index))
        }
        
        // Decode NES Game Genie
        var addressInt = 0x8000
        addressInt += (values[3] & 7) << 12
        addressInt += (values[5] & 7) << 8
        addressInt += (values[4] & 8) << 8
        addressInt += (values[2] & 7) << 4
        addressInt += (values[1] & 8) << 4
        addressInt += (values[4] & 7)
        addressInt += (values[3] & 8)
        let address = UInt32(addressInt)
        
        var valueInt = 0
        valueInt += (values[1] & 7) << 4
        valueInt += (values[0] & 8) << 4
        valueInt += (values[0] & 7)
        valueInt += (values[5] & 8)
        let value = UInt8(valueInt)
        
        return ParseResult(address: address, value: value, compare: nil, error: nil)
    }
    
    private static func parseNESGameGenie8(_ code: String, letters: String) -> ParseResult {
        let chars = Array(code)
        var values: [Int] = []
        
        for char in chars {
            guard let index = letters.firstIndex(of: char) else {
                return ParseResult(address: nil, value: nil, compare: nil, error: "Invalid character")
            }
            values.append(letters.distance(from: letters.startIndex, to: index))
        }
        
        // Decode NES 8-letter Game Genie (with compare value)
        var addressInt = 0x8000
        addressInt += (values[3] & 7) << 12
        addressInt += (values[5] & 7) << 8
        addressInt += (values[4] & 8) << 8
        addressInt += (values[2] & 7) << 4
        addressInt += (values[1] & 8) << 4
        addressInt += (values[4] & 7)
        addressInt += (values[3] & 8)
        let address = UInt32(addressInt)
        
        var valueInt = 0
        valueInt += (values[1] & 7) << 4
        valueInt += (values[0] & 8) << 4
        valueInt += (values[0] & 7)
        valueInt += (values[7] & 8)
        let value = UInt8(valueInt)
        
        var compareInt = 0
        compareInt += (values[7] & 7) << 4
        compareInt += (values[6] & 8) << 4
        compareInt += (values[6] & 7)
        compareInt += (values[5] & 8)
        let compare = UInt8(compareInt)
        
        return ParseResult(address: address, value: value, compare: compare, error: nil)
    }
    
    private static func parseGBGameGenie(_ code: String, letters: String) -> ParseResult {
        // Simplified GB Game Genie parsing
        // Full implementation would be more complex
        return ParseResult(address: nil, value: nil, compare: nil, error: "GB Game Genie not fully implemented")
    }
    
    // MARK: - Action Replay Parser
    
    private static func parseActionReplay(_ code: String) -> ParseResult {
        // Format: XXXXXXXX YYYY (address + value)
        guard code.count >= 10 else {
            return ParseResult(address: nil, value: nil, compare: nil, error: "Code too short")
        }
        
        let addressPart = String(code.prefix(8))
        let valuePart = String(code.suffix(code.count - 8))
        
        guard let address = UInt32(addressPart, radix: 16),
              let value = UInt8(valuePart.prefix(2), radix: 16) else {
            return ParseResult(address: nil, value: nil, compare: nil, error: "Invalid hex value")
        }
        
        return ParseResult(address: address, value: value, compare: nil, error: nil)
    }
    
    // MARK: - Raw Parser
    
    private static func parseRaw(_ code: String) -> ParseResult {
        // Format: XXXX:YY (address:value)
        let parts = code.split(separator: ":")
        
        guard parts.count == 2 else {
            return ParseResult(address: nil, value: nil, compare: nil, error: "Invalid format (use XXXX:YY)")
        }
        
        guard let address = UInt32(parts[0], radix: 16),
              let value = UInt8(parts[1], radix: 16) else {
            return ParseResult(address: nil, value: nil, compare: nil, error: "Invalid hex value")
        }
        
        return ParseResult(address: address, value: value, compare: nil, error: nil)
    }
    
    // MARK: - GameShark Parser
    
    private static func parseGameShark(_ code: String) -> ParseResult {
        // Format varies by platform
        // N64: XXXXXXXX YYYY
        // GBA: XXXXXXXX YYYYYYYY
        
        guard code.count >= 12 else {
            return ParseResult(address: nil, value: nil, compare: nil, error: "Code too short")
        }
        
        let addressPart = String(code.prefix(8))
        let valuePart = String(code.suffix(code.count - 8))
        
        guard let address = UInt32(addressPart, radix: 16),
              let value = UInt8(valuePart.prefix(2), radix: 16) else {
            return ParseResult(address: nil, value: nil, compare: nil, error: "Invalid hex value")
        }
        
        return ParseResult(address: address, value: value, compare: nil, error: nil)
    }
    
    // MARK: - Code Breaker Parser
    
    private static func parseCodeBreaker(_ code: String) -> ParseResult {
        // Similar to GameShark for GBA
        return parseGameShark(code)
    }
    
    // MARK: - Validation
    
    static func validate(code: String, format: CheatFormat) -> (isValid: Bool, error: String?) {
        let result = parse(code: code, format: format)
        
        if let error = result.error {
            return (false, error)
        }
        
        if result.address == nil || result.value == nil {
            return (false, "Could not parse code")
        }
        
        return (true, nil)
    }
    
    // MARK: - Format Detection
    
    static func detectFormat(code: String) -> CheatFormat? {
        let cleanCode = code.uppercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        
        // Check for Game Genie (only letters APZLGITYEOXUKSVN)
        let ggLetters = "APZLGITYEOXUKSVN"
        if cleanCode.allSatisfy({ ggLetters.contains($0) }) && [6, 8, 9].contains(cleanCode.count) {
            return .gameGenie
        }
        
        // Check for Raw format (contains colon)
        if code.contains(":") {
            return .raw
        }
        
        // Check for hex codes
        if cleanCode.allSatisfy({ $0.isHexDigit }) {
            if cleanCode.count >= 12 {
                return .actionReplay
            }
        }
        
        return nil
    }
}

// MARK: - Cheat Manager Extension

extension CheatCode {
    /// Apply cheat to memory
    func apply(to memory: inout [UInt8]) {
        guard isEnabled, let address = address, let value = value else { return }
        
        let index = Int(address)
        guard index < memory.count else { return }
        
        // If compare value exists, only apply if current value matches
        if let compare = compare {
            guard memory[index] == compare else { return }
        }
        
        memory[index] = value
    }
}

// Preview moved to avoid import issues

