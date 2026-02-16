//
//  ChessOpeningBook.swift
//  chessaipractice
//
//  Created by Riley Koo on 2/15/26.
//

import Foundation

// MARK: - Opening Entry

private struct OpeningEntry: Decodable {
    let moves: String   // e.g. "1. e4 c6 2. d4 d5 3. f3"
    let name: String
    let eco: String
}

// MARK: - Opening Book

class ChessOpeningBook {

    // FEN string → opening entry
    private var book: [String: OpeningEntry] = [:]
    private(set) var isLoaded = false

    // All named openings available, keyed by display name
    // (populated after load so the UI can show a picker)
    private(set) var availableOpenings: [String] = []

    // MARK: Load

    func load() {
        let files = ["ecoA", "ecoB", "ecoC", "ecoD", "ecoE"]
        for filename in files {
            guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode([String: OpeningEntry].self, from: data) else {
                print("OpeningBook: could not load \(filename).json")
                continue
            }
//            book.merge(decoded) { existing, _ in existing }
            book.merge(decoded) { existing, new in
                existing.moves.count >= new.moves.count ? existing : new
            }
        }
        availableOpenings = Array(Set(book.values.map { $0.name })).sorted()
        isLoaded = true
        print("OpeningBook: loaded \(book.count) positions")
    }

    // MARK: Lookup

    /// Returns the next book move for the given board, or nil if out of book.
    func nextMove(for board: ChessBoard) -> Move? {
        let fen = board.toFEN()
        print("Looking up FEN: \(fen)")
        if let entry = book[fen] {
            print("✅ Found: \(entry.name)")
        } else {
            print("❌ Not found")
            // print a nearby key to compare
            print("Sample book key: \(book.keys.first ?? "none")")
        }
        guard let entry = book[fen] else { return nil }

        // Figure out which half-move (ply) we're on
        let ply = board.moveHistory.count
        // Parse all moves from the PGN string
        let sanMoves = parseSANMoves(from: entry.moves)
        guard ply < sanMoves.count else { return nil }

        let san = sanMoves[ply]
        return sanToMove(san, on: board)
    }

    /// Returns the next book move for a specific opening by name.
    func nextMove(for board: ChessBoard, opening: String) -> Move? {
        let fen = board.toFEN()
        guard let entry = book[fen], entry.name == opening else { return nil }
        let ply = board.moveHistory.count
        let sanMoves = parseSANMoves(from: entry.moves)
        guard ply < sanMoves.count else { return nil }
        return sanToMove(sanMoves[ply], on: board)
    }

    /// Opening name for the current position, if known.
    func openingName(for board: ChessBoard) -> String? {
        book[board.toFEN()]?.name
    }

    // MARK: - SAN Parser

    /// Strips move numbers and extracts individual SAN tokens.
    /// "1. e4 c6 2. d4 d5" → ["e4","c6","d4","d5"]
    private func parseSANMoves(from pgn: String) -> [String] {
        // Remove move numbers like "1." "12."
        let noNumbers = pgn.replacingOccurrences(of: #"\d+\.\s*"#, with: " ", options: .regularExpression)
        return noNumbers.split(separator: " ").map(String.init).filter { !$0.isEmpty }
    }

    // MARK: - SAN → Move conversion

    /// Converts a SAN string like "Nf3", "exd5", "O-O" to a Move on the given board.
    func sanToMove(_ san: String, on board: ChessBoard) -> Move? {
        let color = board.currentTurn
        let legal = board.legalMoves(for: color)

        // Castling
        if san == "O-O" || san == "0-0" {
            return legal.first { m in
                guard let p = board.piece(at: m.from) else { return false }
                return p.type == .king && m.to.file == 6
            }
        }
        if san == "O-O-O" || san == "0-0-0" {
            return legal.first { m in
                guard let p = board.piece(at: m.from) else { return false }
                return p.type == .king && m.to.file == 2
            }
        }

        // Strip check/checkmate symbols
        var s = san.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "#", with: "")

        // Promotion e.g. e8=Q
        var promotion: PieceType? = nil
        if let eqIdx = s.firstIndex(of: "=") {
            let promoChar = s[s.index(after: eqIdx)]
            promotion = pieceType(from: promoChar)
            s = String(s[..<eqIdx])
        }

        // Destination square is always the last 2 chars
        guard s.count >= 2 else { return nil }
        let toStr = String(s.suffix(2))
        guard let toPos = algebraicToPosition(toStr) else { return nil }

        // Determine piece type
        let firstChar = s.first!
        let pieceT: PieceType
        if firstChar.isUppercase && firstChar != "O" {
            pieceT = pieceType(from: firstChar) ?? .pawn
            s = String(s.dropFirst())   // remove piece letter
        } else {
            pieceT = .pawn
        }

        // Remove destination from s, leaving only disambiguation
        s = String(s.dropLast(2))
        // Remove capture symbol
        s = s.replacingOccurrences(of: "x", with: "")
        // s now contains optional disambiguation: file letter, rank digit, or both

        // Filter legal moves matching destination + piece type
        let candidates = legal.filter { m in
            guard let p = board.piece(at: m.from) else { return false }
            guard p.type == pieceT, m.to == toPos else { return false }
            if let promo = promotion { guard m.promotion == promo else { return false } }
            else if pieceT != .pawn { guard m.promotion == nil else { return false } }
            return true
        }

        if candidates.count == 1 { return candidates[0] }

        // Disambiguation
        return candidates.first { m in
            if s.count == 1 {
                if let c = s.first, c.isLetter {
                    // file disambiguation e.g. "N" already removed, s = "e" means e-file
                    return m.from.algebraic.first == c
                } else if let c = s.first, c.isNumber, let rankChar = c.wholeNumberValue {
                    return m.from.rank == rankChar - 1
                }
            } else if s.count == 2 {
                return m.from.algebraic == s
            }
            return false
        }
    }

    // MARK: - Helpers

    private func algebraicToPosition(_ s: String) -> Position? {
        guard s.count == 2,
              let fileChar = s.first,
              let rankChar = s.last,
              let rankInt  = rankChar.wholeNumberValue else { return nil }
        let fileMap = ["a":0,"b":1,"c":2,"d":3,"e":4,"f":5,"g":6,"h":7]
        guard let file = fileMap[String(fileChar)] else { return nil }
        let pos = Position(rankInt - 1, file)
        return pos.isValid ? pos : nil
    }

    private func pieceType(from char: Character) -> PieceType? {
        switch char {
        case "N": return .knight
        case "B": return .bishop
        case "R": return .rook
        case "Q": return .queen
        case "K": return .king
        default:  return nil
        }
    }
}

// MARK: - FEN Generation

extension ChessBoard {

    /// Generates the FEN string for the current board state.
    func toFEN() -> String {
        var fen = ""

        // Piece placement (rank 8 down to rank 1)
        for rank in stride(from: 7, through: 0, by: -1) {
            var empty = 0
            for file in 0..<8 {
                if let piece = squares[rank][file] {
                    if empty > 0 { fen += "\(empty)"; empty = 0 }
                    fen += fenChar(for: piece)
                } else {
                    empty += 1
                }
            }
            if empty > 0 { fen += "\(empty)" }
            if rank > 0 { fen += "/" }
        }

        // Active color
        fen += currentTurn == .white ? " w" : " b"

        // Castling availability
        var castling = ""
        if let king = squares[0][4], king.type == .king, !king.hasMoved {
            if let rook = squares[0][7], rook.type == .rook, !rook.hasMoved { castling += "K" }
            if let rook = squares[0][0], rook.type == .rook, !rook.hasMoved { castling += "Q" }
        }
        if let king = squares[7][4], king.type == .king, !king.hasMoved {
            if let rook = squares[7][7], rook.type == .rook, !rook.hasMoved { castling += "k" }
            if let rook = squares[7][0], rook.type == .rook, !rook.hasMoved { castling += "q" }
        }
        fen += " " + (castling.isEmpty ? "-" : castling)

        // En passant
        if let ep = enPassantTarget, canCaptureEnPassant(ep) {
            fen += " " + ep.algebraic
        } else {
            fen += " -"
        }

        // Halfmove clock and fullmove number (simplified)
        fen += " 0 \((moveHistory.count / 2) + 1)"

        return fen
    }

    private func fenChar(for piece: ChessPiece) -> String {
        let c: String
        switch piece.type {
        case .pawn:   c = "p"
        case .knight: c = "n"
        case .bishop: c = "b"
        case .rook:   c = "r"
        case .queen:  c = "q"
        case .king:   c = "k"
        }
        return piece.color == .white ? c.uppercased() : c
    }
    
    private func canCaptureEnPassant(_ ep: Position) -> Bool {
        let attackerColor = currentTurn  // the side that would capture
        let pawnDir = attackerColor == .white ? -1 : 1
        let captureRank = ep.rank + pawnDir
        for df in [-1, 1] {
            let from = Position(captureRank, ep.file + df)
            if let p = piece(at: from), p.type == .pawn, p.color == attackerColor {
                return true
            }
        }
        return false
    }
}
