//
//  ChessBoard.swift
//  chessaipractice
//
//  Created by Riley Koo on 2/14/26.
//

import Foundation

// MARK: - Chess Board
// Full rules engine: move generation, check detection, castling, en passant, promotion.
// The evaluate() method at the bottom is intentionally minimal — enhance it for your AI!

class ChessBoard {

    // MARK: State
    var squares: [[ChessPiece?]]   // squares[rank][file]
    var currentTurn: PieceColor = .white
    var enPassantTarget: Position? = nil    // square a pawn can capture into via en passant
    var moveHistory: [Move] = []
    var capturedByWhite: [ChessPiece] = []
    var capturedByBlack: [ChessPiece] = []

    // MARK: Init

    init() {
        squares = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        setupStartingPosition()
    }

    /// Deep copy — use this inside minimax to try moves without mutating the real board
    init(copying board: ChessBoard) {
        self.squares         = board.squares.map { $0 }
        self.currentTurn     = board.currentTurn
        self.enPassantTarget = board.enPassantTarget
        self.moveHistory     = board.moveHistory
        self.capturedByWhite = board.capturedByWhite
        self.capturedByBlack = board.capturedByBlack
    }

    // MARK: Setup

    func setupStartingPosition() {
        squares          = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        currentTurn      = .white
        enPassantTarget  = nil
        moveHistory      = []
        capturedByWhite  = []
        capturedByBlack  = []

        for f in 0..<8 {
            squares[1][f] = ChessPiece(type: .pawn, color: .white)
            squares[6][f] = ChessPiece(type: .pawn, color: .black)
        }
        let backRank: [PieceType] = [.rook,.knight,.bishop,.queen,.king,.bishop,.knight,.rook]
        for (f, pt) in backRank.enumerated() {
            squares[0][f] = ChessPiece(type: pt, color: .white)
            squares[7][f] = ChessPiece(type: pt, color: .black)
        }
    }

    // MARK: Accessors

    func piece(at pos: Position) -> ChessPiece? {
        guard pos.isValid else { return nil }
        return squares[pos.rank][pos.file]
    }

    func isEmpty(at pos: Position) -> Bool { piece(at: pos) == nil }

    func isEnemy(at pos: Position, for color: PieceColor) -> Bool {
        piece(at: pos)?.color == color.opposite
    }

    // MARK: Apply Move

    /// Executes a move unconditionally. Call legalMoves(for:) first to validate.
    @discardableResult
    func applyMove(_ move: Move) -> ChessPiece? {
        guard var movedPiece = piece(at: move.from) else { return nil }
        var captured: ChessPiece? = piece(at: move.to)
        movedPiece.hasMoved = true

        // En passant capture
        if movedPiece.type == .pawn, let ep = enPassantTarget, move.to == ep {
            let capRank = movedPiece.color == .white ? ep.rank - 1 : ep.rank + 1
            captured = squares[capRank][ep.file]
            squares[capRank][ep.file] = nil
        }

        if let cap = captured {
            movedPiece.color == .white ? capturedByWhite.append(cap) : capturedByBlack.append(cap)
        }

        // Castling — move the rook too
        if movedPiece.type == .king, abs(move.to.file - move.from.file) == 2 {
            let kingSide    = move.to.file > move.from.file
            let rookFromFile = kingSide ? 7 : 0
            let rookToFile   = kingSide ? 5 : 3
            var rook = squares[move.from.rank][rookFromFile]!
            rook.hasMoved = true
            squares[move.from.rank][rookToFile]   = rook
            squares[move.from.rank][rookFromFile]  = nil
        }

        // Update en passant target
        if movedPiece.type == .pawn, abs(move.to.rank - move.from.rank) == 2 {
            enPassantTarget = Position((move.from.rank + move.to.rank) / 2, move.from.file)
        } else {
            enPassantTarget = nil
        }

        // Promotion
        if let promo = move.promotion {
            movedPiece = ChessPiece(type: promo, color: movedPiece.color, hasMoved: true)
        }

        squares[move.to.rank][move.to.file]   = movedPiece
        squares[move.from.rank][move.from.file] = nil
        moveHistory.append(move)
        currentTurn = currentTurn.opposite

        return captured
    }

    // MARK: Legal Moves

    /// All legal moves for a colour (filters out moves that leave own king in check)
    func legalMoves(for color: PieceColor) -> [Move] {
        var legal: [Move] = []
        for rank in 0..<8 {
            for file in 0..<8 {
                let pos = Position(rank, file)
                guard let p = piece(at: pos), p.color == color else { continue }
                for move in pseudoLegalMoves(for: p, at: pos) {
                    let copy = ChessBoard(copying: self)
                    copy.applyMove(move)
                    if !copy.isInCheck(color) { legal.append(move) }
                }
            }
        }
        return legal
    }

    /// Legal moves originating from a specific square
    func legalMoves(from pos: Position) -> [Move] {
        guard let p = piece(at: pos) else { return [] }
        return legalMoves(for: p.color).filter { $0.from == pos }
    }

    // MARK: Check Detection

    func isInCheck(_ color: PieceColor) -> Bool {
        guard let kingPos = findKing(color) else { return false }
        return isSquareAttacked(kingPos, by: color.opposite)
    }

    func isSquareAttacked(_ pos: Position, by attacker: PieceColor) -> Bool {
        for rank in 0..<8 {
            for file in 0..<8 {
                let from = Position(rank, file)
                guard let p = piece(at: from), p.color == attacker else { continue }
                if attackMoves(for: p, at: from).contains(where: { $0.to == pos }) {
                    return true
                }
            }
        }
        return false
    }

    func findKing(_ color: PieceColor) -> Position? {
        for rank in 0..<8 {
            for file in 0..<8 {
                let pos = Position(rank, file)
                if let p = piece(at: pos), p.type == .king, p.color == color { return pos }
            }
        }
        return nil
    }

    // MARK: Game Status

    func gameStatus() -> GameStatus {
        let moves = legalMoves(for: currentTurn)
        if moves.isEmpty {
            return isInCheck(currentTurn) ? .checkmate(currentTurn) : .stalemate
        }
        if hasInsufficientMaterial() { return .draw }
        return isInCheck(currentTurn) ? .check(currentTurn) : .playing
    }

    private func hasInsufficientMaterial() -> Bool {
        var pieces: [(PieceType, PieceColor)] = []
        for rank in 0..<8 {
            for file in 0..<8 {
                if let p = squares[rank][file] { pieces.append((p.type, p.color)) }
            }
        }
        if pieces.count == 2 { return true }
        if pieces.count == 3, pieces.contains(where: { $0.0 == .bishop || $0.0 == .knight }) {
            return true
        }
        return false
    }

    // MARK: - Board Evaluation
    //
    // ╔══════════════════════════════════════════════════════════════════╗
    // ║  THIS IS WHERE YOUR MINIMAX WORK HAPPENS                        ║
    // ║                                                                  ║
    // ║  evaluate() returns a score from White's perspective:           ║
    // ║    • Positive  = good for White                                 ║
    // ║    • Negative  = good for Black                                 ║
    // ║    • 0         = equal position                                 ║
    // ║                                                                  ║
    // ║  Right now it only counts material. You can improve it by:      ║
    // ║    1. Adding piece-square tables (positional bonuses)           ║
    // ║    2. Rewarding mobility (number of legal moves)                ║
    // ║    3. Penalising doubled/isolated pawns                         ║
    // ║    4. Rewarding king safety                                      ║
    // ╚══════════════════════════════════════════════════════════════════╝

    func evaluate() -> Int {
        var score = 0
        for rank in 0..<8 {
            for file in 0..<8 {
                guard let p = squares[rank][file] else { continue }
                let sign = p.color == .white ? 1 : -1
                score += sign * p.type.materialValue
            }
        }
        return score
    }

    // MARK: - Pseudo-Legal Move Generators (internal)

    func pseudoLegalMoves(for piece: ChessPiece, at pos: Position) -> [Move] {
        switch piece.type {
        case .pawn:   return pawnMoves(piece, at: pos)
        case .knight: return knightMoves(piece, at: pos)
        case .bishop: return slidingMoves(piece, at: pos, dirs: [(1,1),(1,-1),(-1,1),(-1,-1)])
        case .rook:   return slidingMoves(piece, at: pos, dirs: [(1,0),(-1,0),(0,1),(0,-1)])
        case .queen:  return slidingMoves(piece, at: pos, dirs: [(1,1),(1,-1),(-1,1),(-1,-1),(1,0),(-1,0),(0,1),(0,-1)])
        case .king:   return kingMoves(piece, at: pos, includeCastling: true)
        }
    }

    /// Used by isSquareAttacked — skips castling to avoid infinite recursion.
    func attackMoves(for piece: ChessPiece, at pos: Position) -> [Move] {
        if piece.type == .king { return kingMoves(piece, at: pos, includeCastling: false) }
        return pseudoLegalMoves(for: piece, at: pos)
    }

    private func pawnMoves(_ piece: ChessPiece, at pos: Position) -> [Move] {
        var moves: [Move] = []
        let dir       = piece.color == .white ? 1 : -1
        let startRank = piece.color == .white ? 1 : 6
        let promoRank = piece.color == .white ? 7 : 0

        func addWithPromo(_ to: Position) {
            if to.rank == promoRank {
                for promo in [PieceType.queen, .rook, .bishop, .knight] {
                    moves.append(Move(from: pos, to: to, promotion: promo))
                }
            } else {
                moves.append(Move(from: pos, to: to))
            }
        }

        let oneStep = pos.offset(rankDelta: dir, fileDelta: 0)
        if oneStep.isValid && isEmpty(at: oneStep) {
            addWithPromo(oneStep)
            let twoStep = pos.offset(rankDelta: dir * 2, fileDelta: 0)
            if pos.rank == startRank, twoStep.isValid, isEmpty(at: twoStep) {
                moves.append(Move(from: pos, to: twoStep))
            }
        }

        for df in [-1, 1] {
            let cap = pos.offset(rankDelta: dir, fileDelta: df)
            guard cap.isValid else { continue }
            if isEnemy(at: cap, for: piece.color) || enPassantTarget == cap {
                addWithPromo(cap)
            }
        }
        return moves
    }

    private func knightMoves(_ knightPiece: ChessPiece, at pos: Position) -> [Move] {
        let offsets: [(Int, Int)] = [(2,1),(2,-1),(-2,1),(-2,-1),(1,2),(1,-2),(-1,2),(-1,-2)]
        return offsets.compactMap { (dr, df) in
            let to = pos.offset(rankDelta: dr, fileDelta: df)
            guard to.isValid, piece(at: to)?.color != knightPiece.color else { return nil }
            return Move(from: pos, to: to)
        }
    }

    private func slidingMoves(_ piece: ChessPiece, at pos: Position, dirs: [(Int,Int)]) -> [Move] {
        var moves: [Move] = []
        for (dr, df) in dirs {
            var cur = pos.offset(rankDelta: dr, fileDelta: df)
            while cur.isValid {
                if let target = self.piece(at: cur) {
                    if target.color != piece.color { moves.append(Move(from: pos, to: cur)) }
                    break
                }
                moves.append(Move(from: pos, to: cur))
                cur = cur.offset(rankDelta: dr, fileDelta: df)
            }
        }
        return moves
    }

    private func kingMoves(_ piece: ChessPiece, at pos: Position, includeCastling: Bool) -> [Move] {
        var moves: [Move] = []

        for dr in -1...1 {
            for df in -1...1 {
                guard (dr, df) != (0, 0) else { continue }
                let to = pos.offset(rankDelta: dr, fileDelta: df)
                guard to.isValid, self.piece(at: to)?.color != piece.color else { continue }
                moves.append(Move(from: pos, to: to))
            }
        }

        // Castling — skipped when called from attack detection to avoid infinite recursion
        guard includeCastling, !piece.hasMoved, !isInCheck(piece.color) else { return moves }
        let rank = pos.rank

        // Kingside
        if let rook = self.piece(at: Position(rank, 7)), rook.type == .rook, !rook.hasMoved,
           isEmpty(at: Position(rank, 5)), isEmpty(at: Position(rank, 6)),
           !isSquareAttacked(Position(rank, 5), by: piece.color.opposite),
           !isSquareAttacked(Position(rank, 6), by: piece.color.opposite) {
            moves.append(Move(from: pos, to: Position(rank, 6)))
        }

        // Queenside
        if let rook = self.piece(at: Position(rank, 0)), rook.type == .rook, !rook.hasMoved,
           isEmpty(at: Position(rank, 1)), isEmpty(at: Position(rank, 2)), isEmpty(at: Position(rank, 3)),
           !isSquareAttacked(Position(rank, 2), by: piece.color.opposite),
           !isSquareAttacked(Position(rank, 3), by: piece.color.opposite) {
            moves.append(Move(from: pos, to: Position(rank, 2)))
        }

        return moves
    }
}
