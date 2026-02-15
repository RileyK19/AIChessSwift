//
//  Models.swift
//  chessaipractice
//
//  Created by Riley Koo on 2/14/26.
//

import Foundation

// MARK: - Piece Color

enum PieceColor: Int, Equatable, Codable {
    case white = 1
    case black = -1

    var opposite: PieceColor { self == .white ? .black : .white }
}

// MARK: - Piece Type

enum PieceType: CaseIterable, Equatable, Codable {
    case pawn, knight, bishop, rook, queen, king

    /// Classic centipawn material values — useful for your minimax evaluate() function
    var materialValue: Int {
        switch self {
        case .pawn:   return 100
        case .knight: return 320
        case .bishop: return 330
        case .rook:   return 500
        case .queen:  return 900
        case .king:   return 20_000
        }
    }
}

// MARK: - Position

struct Position: Hashable, Equatable, Codable {
    let rank: Int   // 0–7  (0 = rank 1 / white back rank)
    let file: Int   // 0–7  (0 = a-file)

    init(_ rank: Int, _ file: Int) {
        self.rank = rank
        self.file = file
    }

    var isValid: Bool { (0..<8).contains(rank) && (0..<8).contains(file) }

    func offset(rankDelta: Int, fileDelta: Int) -> Position {
        Position(rank + rankDelta, file + fileDelta)
    }

    /// Human-readable algebraic name e.g. "e4"
    var algebraic: String {
        let files = ["a","b","c","d","e","f","g","h"]
        guard isValid else { return "??" }
        return "\(files[file])\(rank + 1)"
    }
}

// MARK: - Chess Piece

struct ChessPiece: Equatable, Codable {
    let type: PieceType
    let color: PieceColor
    var hasMoved: Bool = false

    var symbol: String {
        switch (type, color) {
        case (.king,   .white): return "♔"
        case (.queen,  .white): return "♕"
        case (.rook,   .white): return "♖"
        case (.bishop, .white): return "♗"
        case (.knight, .white): return "♘"
        case (.pawn,   .white): return "♙"
        case (.king,   .black): return "♚"
        case (.queen,  .black): return "♛"
        case (.rook,   .black): return "♜"
        case (.bishop, .black): return "♝"
        case (.knight, .black): return "♞"
        case (.pawn,   .black): return "♟"
        }
    }
}

// MARK: - Move

struct Move: Equatable, Codable, Hashable {
    let from: Position
    let to: Position
    let promotion: PieceType?   // non-nil only for pawn promotion

    init(from: Position, to: Position, promotion: PieceType? = nil) {
        self.from = from
        self.to   = to
        self.promotion = promotion
    }
}

// MARK: - Game Status

enum GameStatus: Equatable {
    case playing
    case check(PieceColor)
    case checkmate(PieceColor)   // colour that is checkmated (they lost)
    case stalemate
    case draw                    // insufficient material
}
