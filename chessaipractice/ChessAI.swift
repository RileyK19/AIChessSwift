//
//  ChessAI.swift
//  chessaipractice
//
//  Created by Riley Koo on 2/14/26.
//

import Foundation

// MARK: - Chess AI — YOUR MINIMAX IMPLEMENTATION GOES HERE
//
// This file is intentionally left as a stub.
// The app wires everything up for you — you just need to implement bestMove().
//
// How the app calls your AI:
//   1. User picks "vs Robot" mode and chooses their colour
//   2. When it's the AI's turn, GameViewModel calls:
//          let move = ai.bestMove(on: board)
//   3. The app applies that move and updates the UI
//
// The ChessBoard object passed to you has everything you need:
//   • board.legalMoves(for: color)   → [Move]   all legal moves for a side
//   • board.applyMove(_ move)         → mutates the board (use a copy!)
//   • board.evaluate()                → Int      material score, white-positive
//   • board.gameStatus()              → GameStatus (.playing / .check / .checkmate / .stalemate)
//   • ChessBoard(copying: board)      → deep copy for tree search
//
// ─────────────────────────────────────────────────────────────────────────────
//  MINIMAX PSEUDOCODE (implement below):
//
//  function minimax(board, depth, isMaximising):
//      if depth == 0 or game is over:
//          return board.evaluate()
//
//      if isMaximising:
//          bestScore = -∞
//          for each move in board.legalMoves(for: .white):
//              copy = ChessBoard(copying: board)
//              copy.applyMove(move)
//              score = minimax(copy, depth - 1, false)
//              bestScore = max(bestScore, score)
//          return bestScore
//      else:
//          bestScore = +∞
//          for each move in board.legalMoves(for: .black):
//              copy = ChessBoard(copying: board)
//              copy.applyMove(move)
//              score = minimax(copy, depth - 1, true)
//              bestScore = min(bestScore, score)
//          return bestScore
//
//  Once minimax works, try adding Alpha-Beta pruning:
//      • Pass alpha and beta through every recursive call
//      • After each child, prune if beta <= alpha
// ─────────────────────────────────────────────────────────────────────────────

class ChessAI {

    let color: PieceColor   // The colour this AI plays as
    var depth: Int          // How many plies (half-moves) to search

    init(color: PieceColor, depth: Int = 3) {
        self.color = color
        self.depth = depth
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TODO: Implement this method!
    //
    // Return the best Move for `self.color` on the given board.
    // Return nil only if there are literally no legal moves (should not happen
    // in normal play — the app handles checkmate/stalemate before calling this).
    // ─────────────────────────────────────────────────────────────────────────
    func bestMove(on board: ChessBoard) -> Move? {

        // ── Starter code: picks a random legal move so the app runs ──────────
        // Delete this and replace with your minimax search!
//        let moves = board.legalMoves(for: color)
//        return moves.randomElement()
        let (move, _) = minimax(board: board, depth: depth, isMaximising: (color == .white))
        return move
        // ─────────────────────────────────────────────────────────────────────
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TODO: Implement minimax here (and optionally alpha-beta below)
    // ─────────────────────────────────────────────────────────────────────────
    
    private func attackedSquares(on board: ChessBoard, by color: PieceColor) -> Set<Position> {
        var attacked = Set<Position>()
        for rank in 0..<8 {
            for file in 0..<8 {
                let pos = Position(rank, file)
                guard let p = board.piece(at: pos), p.color == color else { continue }
                for move in board.attackMoves(for: p, at: pos) {
                    attacked.insert(move.to)
                }
            }
        }
        return attacked
    }
    private func tension(on board: ChessBoard) -> Int {
        var score = 0
        let whiteAttacks = attackedSquares(on: board, by: .white)
        let blackAttacks = attackedSquares(on: board, by: .black)

        for rank in 0..<8 {
            for file in 0..<8 {
                let pos = Position(rank, file)
                guard let p = board.piece(at: pos) else { continue }

                let isAttacked  = p.color == .white ? blackAttacks.contains(pos) : whiteAttacks.contains(pos)
                let isDefended  = p.color == .white ? whiteAttacks.contains(pos) : blackAttacks.contains(pos)

                if isAttacked && !isDefended {
                    // Hanging piece — big tension, bad for the side that owns it
                    let sign = p.color == .white ? -1 : 1
                    score += sign * p.type.materialValue/10
                } else if isAttacked && isDefended {
                    // Contested square — smaller tension bonus
                    let sign = p.color == .white ? -1 : 1
                    score += sign * (p.type.materialValue / 100)
                }
            }
        }
        return score
    }
    
    private func activity(on board: ChessBoard) -> Int {
        var score = 0
        for rank in 0..<8 {
            for file in 0..<8 {
                let pos = Position(rank, file)
                guard let p = board.piece(at: pos) else { continue }
                let sign = p.color == .white ? 1 : -1
                for move in board.attackMoves(for: p, at: pos) {
                    if let target = board.piece(at: move.to), target.color != p.color {
                        score += sign * target.type.materialValue
                    }
                }
            }
        }
        return score / 20
    }
    
    private func positionalScore(on board: ChessBoard) -> Int {
        // Tables are from white's perspective, rank 0 = white back rank.
        // For black pieces the table is mirrored (rank 7 - rank).
        
        let pawnTable = [
            [ 0,  0,  0,  0,  0,  0,  0,  0],
            [50, 50, 50, 50, 50, 50, 50, 50],
            [10, 10, 20, 30, 30, 20, 10, 10],
            [ 5,  5, 10, 25, 25, 10,  5,  5],
            [ 0,  0,  0, 20, 20,  0,  0,  0],
            [ 5, -5,-10,  0,  0,-10, -5,  5],
            [ 5, 10, 10,-20,-20, 10, 10,  5],
            [ 0,  0,  0,  0,  0,  0,  0,  0]
        ]
        let knightTable = [
            [-50,-40,-30,-30,-30,-30,-40,-50],
            [-40,-20,  0,  0,  0,  0,-20,-40],
            [-30,  0, 10, 15, 15, 10,  0,-30],
            [-30,  5, 15, 20, 20, 15,  5,-30],
            [-30,  0, 15, 20, 20, 15,  0,-30],
            [-30,  5, 10, 15, 15, 10,  5,-30],
            [-40,-20,  0,  5,  5,  0,-20,-40],
            [-50,-40,-30,-30,-30,-30,-40,-50]
        ]
        let bishopTable = [
            [-20,-10,-10,-10,-10,-10,-10,-20],
            [-10,  0,  0,  0,  0,  0,  0,-10],
            [-10,  0,  5, 10, 10,  5,  0,-10],
            [-10,  5,  5, 10, 10,  5,  5,-10],
            [-10,  0, 10, 10, 10, 10,  0,-10],
            [-10, 10, 10, 10, 10, 10, 10,-10],
            [-10,  5,  0,  0,  0,  0,  5,-10],
            [-20,-10,-10,-10,-10,-10,-10,-20]
        ]
        let rookTable = [
            [ 0,  0,  0,  0,  0,  0,  0,  0],
            [ 5, 10, 10, 10, 10, 10, 10,  5],
            [-5,  0,  0,  0,  0,  0,  0, -5],
            [-5,  0,  0,  0,  0,  0,  0, -5],
            [-5,  0,  0,  0,  0,  0,  0, -5],
            [-5,  0,  0,  0,  0,  0,  0, -5],
            [-5,  0,  0,  0,  0,  0,  0, -5],
            [ 0,  0,  0,  5,  5,  0,  0,  0]
        ]
        let queenTable = [
            [-20,-10,-10, -5, -5,-10,-10,-20],
            [-10,  0,  0,  0,  0,  0,  0,-10],
            [-10,  0,  5,  5,  5,  5,  0,-10],
            [ -5,  0,  5,  5,  5,  5,  0, -5],
            [  0,  0,  5,  5,  5,  5,  0, -5],
            [-10,  5,  5,  5,  5,  5,  0,-10],
            [-10,  0,  5,  0,  0,  0,  0,-10],
            [-20,-10,-10, -5, -5,-10,-10,-20]
        ]
        let kingTable = [
            [-30,-40,-40,-50,-50,-40,-40,-30],
            [-30,-40,-40,-50,-50,-40,-40,-30],
            [-30,-40,-40,-50,-50,-40,-40,-30],
            [-30,-40,-40,-50,-50,-40,-40,-30],
            [-20,-30,-30,-40,-40,-30,-30,-20],
            [-10,-20,-20,-20,-20,-20,-20,-10],
            [ 20, 20,  0,  0,  0,  0, 20, 20],
            [ 20, 30, 10,  0,  0, 10, 30, 20]
        ]

        var score = 0
        for rank in 0..<8 {
            for file in 0..<8 {
                guard let p = board.piece(at: Position(rank, file)) else { continue }
                let sign = p.color == .white ? 1 : -1
                // Mirror rank for black so the table always reads from that side's perspective
                let r = p.color == .white ? rank : (7 - rank)
                let table: [[Int]]
                switch p.type {
                case .pawn:   table = pawnTable
                case .knight: table = knightTable
                case .bishop: table = bishopTable
                case .rook:   table = rookTable
                case .queen:  table = queenTable
                case .king:   table = kingTable
                }
                score += sign * table[7 - r][file]
            }
        }
        return score
    }
    
    private func evaluateBetter(on board: ChessBoard) -> Int {
        return board.evaluate() + tension(on: board) + activity(on: board) + positionalScore(on: board)
    }

    private func minimax(board: ChessBoard, depth: Int, isMaximising: Bool, alpha: Int = Int.min, beta: Int = Int.max) -> (Move?, Int) {
         // your code here
         
        var alpha2 = alpha
        var beta2 = beta
        
        let status = board.gameStatus()
//         if status == .checkmate(isMaximising ? .white : .black) {
//             return (nil, !isMaximising ? Int.max : Int.min)
//         } else if status == .checkmate(!isMaximising ? .white : .black) {
//             return (nil, isMaximising ? Int.max : Int.min)
//         } else if status == .draw || status == .stalemate {
//             return (nil, 0)
//         }
        switch status {
            case .checkmate(let loser):
                // whoever is checkmated lost — score from white's perspective
                return (nil, loser == .white ? -1_000_000 : 1_000_000)
            case .stalemate, .draw:
                return (nil, 0)
            default:
                break
        }
        
        if depth == 0 {
            return (nil, evaluateBetter(on: board))
        }
        
         let moves = board.legalMoves(for: isMaximising ? .white : .black)
         var scores: [Move: Int] = [:]
         let boardCopy = ChessBoard(copying: board)
         for move in moves {
             let cur = ChessBoard(copying: boardCopy)
             cur.applyMove(move)
             scores[move] = evaluateBetter(on: cur)
         }
         var sorted = scores.sorted { $0.value > $1.value }  // highest score first
         if !isMaximising {
             sorted = scores.sorted { $0.value < $1.value }  // lowest score first
         }
        var moveRet: Move? = moves[0]
        var scoreRet: Int = isMaximising ? Int.min : Int.max
         for entry in sorted {
             let cur = ChessBoard(copying: boardCopy)
             cur.applyMove(entry.key)
             let (_, score) = minimax(board: cur, depth: depth - 1, isMaximising: !isMaximising, alpha: alpha2, beta: beta2)
             scores[entry.key] = score
             if (isMaximising && score > scoreRet) || (!isMaximising && score < scoreRet) {
                 scoreRet = score
                 moveRet = entry.key
             }
             if scoreRet >= beta && isMaximising {
                 return (moveRet, scoreRet)
             } else if scoreRet <= alpha && !isMaximising {
                 return (moveRet, scoreRet)
             }
             if isMaximising {
                 alpha2 = max(alpha2, scoreRet)
             } else {
                 beta2 = min(beta2, scoreRet)
             }
         }
        return (moveRet, scoreRet)
//        sorted = scores.sorted { $0.value > $1.value }  // highest score first
//         if !isMaximising {
//             sorted = scores.sorted { $0.value < $1.value }  // lowest score first
//         }
//         return sorted[0]
     }

    // private func alphaBeta(board: ChessBoard, depth: Int, alpha: Int, beta: Int, isMaximising: Bool) -> Int {
    //     // your code here
    // }
}
