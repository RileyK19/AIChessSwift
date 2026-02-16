//
//  ChessMCTS.swift
//  chessaipractice
//
//  Created by Riley Koo on 2/15/26.
//

import Foundation

// MARK: - Monte Carlo Tree Search
//
// MCTS works completely differently from minimax:
//   • No hand-crafted evaluation function needed
//   • Instead, plays random games to the end ("rollouts") and learns from win/loss
//   • Balances exploring new moves vs exploiting known good ones (UCB1 formula)
//
// The four steps, repeated `iterations` times:
//
//   1. SELECTION   — walk the tree from root, picking children by UCB1 until
//                    you reach a node that hasn't been fully expanded
//
//   2. EXPANSION   — add one new child node (an unexplored move)
//
//   3. SIMULATION  — from the new node, play random moves until the game ends
//                    (this is the "rollout" or "playout")
//
//   4. BACKPROP    — walk back up to the root, updating each node's
//                    visit count and win count
//
// UCB1 formula (balances exploration vs exploitation):
//
//   UCB1 = (wins / visits) + C * sqrt(ln(parentVisits) / visits)
//
//   • wins/visits   = how good this node looks so far (exploitation)
//   • sqrt(...)     = how underexplored this node is (exploration)
//   • C             = exploration constant, typically sqrt(2) ≈ 1.414
//
// ─────────────────────────────────────────────────────────────────────────────

// MARK: - MCTS Node

class MCTSNode {
    let board: ChessBoard          // board state at this node
    let move: Move?                // move that led here (nil for root)
    weak var parent: MCTSNode?     // nil for root

    var children: [MCTSNode] = []
    var untriedMoves: [Move]       // moves not yet expanded

    var visits: Int = 0
    var wins: Double = 0.0         // use Double so you can give 0.5 for draws

    init(board: ChessBoard, move: Move? = nil, parent: MCTSNode? = nil) {
        self.board = board
        self.move = move
        self.parent = parent
        self.untriedMoves = board.legalMoves(for: board.currentTurn)
    }

    var isFullyExpanded: Bool { untriedMoves.isEmpty }
    var isTerminal: Bool {
        let s = board.gameStatus()
        if case .checkmate(_) = s { return true }
        if case .stalemate = s    { return true }
        if case .draw = s         { return true }
        return false
    }

    // ── UCB1 ─────────────────────────────────────────────────────────────────
    func ucb1(explorationConstant C: Double = 1.414) -> Double {
        guard visits > 0, let parent else { return Double.infinity }
        return (Double(wins)/Double(visits)) + C*sqrt(log(Double(parent.visits))/Double(visits))
    }

    // ── Best child by UCB1 ────────────────────────────────────────────────────
    func bestChild(explorationConstant C: Double = 1.414) -> MCTSNode? {
        children.max { $0.ucb1(explorationConstant: C) < $1.ucb1(explorationConstant: C) }
    }
}

// MARK: - MCTS AI

class ChessMCTS {

    let color: PieceColor
    var iterations: Int     // how many rollouts to run per move (more = stronger but slower)
    var maxSimulations: Int

    init(color: PieceColor, iterations: Int = 500, maxSimulations: Int = 50) {
        self.color = color
        self.iterations = iterations
        self.maxSimulations = maxSimulations
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Run `iterations` rounds of: selection → expansion → simulation → backprop
    // Then return the move from the root's child with the most visits.
    // (Most visits = most confidence, better than highest win rate for small samples)
    // ─────────────────────────────────────────────────────────────────────────
    func bestMove(on board: ChessBoard) -> Move? {
        let root = MCTSNode(board: board)
        for _ in 0..<iterations {
            let selection = select(from: root)
            backpropagate(from: selection, result: simulate(from: selection))
            
//            let node = select(from: root)
//            let result = simulate(from: node)
//            backpropagate(from: node, result: result)
        }
        return root.children.max{ Double($0.wins)/Double($0.visits) < Double($1.wins)/Double($1.visits) }?.move ?? board.legalMoves(for: color).randomElement()
    }
    
    // 1. Selection — walk tree using UCB1 until a non-fully-expanded node
     private func select(from root: MCTSNode) -> MCTSNode {
//         print("select\n")
//         var node: MCTSNode = root
//         var node2: MCTSNode? = root.bestChild()
//         while node2 != nil {
//             node = node2!
//             node2 = node.bestChild()
//         }
//         return node
         
//         let node = root.bestChild()
//         if node == nil {
//             return root
//         } else {
//             return select(from: node!)
//         }
         var node = root
         while !node.isTerminal {
             if !node.isFullyExpanded {
                 return expand(node)   // expand returns the new child
             }
             guard let best = node.bestChild() else { break }
             node = best
         }
         return node
     }

    // 2. Expansion — pick an untried move, create and attach a child node
     private func expand(_ node: MCTSNode) -> MCTSNode {
//         print("expand\n")
         let move = node.untriedMoves.randomElement()
         node.untriedMoves.removeAll { m in
             m == move
         }
         let board = ChessBoard(copying: node.board)
         board.applyMove(move!)
         let newNode = MCTSNode(board: board, move: move, parent: node)
         node.children.append(newNode)
         return newNode
     }

    // 3. Simulation — play random moves from node until game over, return result
    private func simulate(from node: MCTSNode, movesMade: Int = 0) -> Double {
//         print("simulate\n")
//         var n = node
//         while !n.isTerminal {
//             n = expand(n)
//         }
//         let status = n.board.gameStatus()
//         switch status {
//             case .checkmate(let loser):
//                 // whoever is checkmated lost — score from white's perspective
//                 return loser == .white ? 0 : 1
//             case .stalemate, .draw:
//                return 0.5
//             default:
//                return 0.5
//         }
        
//         let status = node.board.gameStatus()
//         if node.isTerminal {
//              switch status {
//                  case .checkmate(let loser):
//                      // whoever is checkmated lost — score from white's perspective
//                      return loser == color ? 0 : 1
//                  case .stalemate, .draw:
//                     return 0.5
//                  default:
//                     return 0.5
//              }
//         } else if movesMade >= maxSimulations {
//             return Double(evaluateBetter(on: node.board)) / 100
//         } else {
//             return simulate(from: expand(node), movesMade: movesMade+1)
//         }
        
//        let board = ChessBoard(copying: node.board)
//        var movesMade = 0
//        
//        while movesMade < maxSimulations {
//            let status = board.gameStatus()
//            switch status {
//            case .checkmate(let loser):
//                return loser == color ? 0 : 1
//            case .stalemate, .draw:
//                return 0.5
//            default:
//                break
//            }
//            let moves = board.legalMoves(for: board.currentTurn)
//            guard let move = moves.randomElement() else { return 0.5 }
//            board.applyMove(move)
//            movesMade += 1
//        }
//        // Hit move limit — use eval as tiebreak, normalized small
//        return 0.5 + Double(board.evaluate()) / 200_000
        
//        let b = node.board
//        let score = evaluateBetter(on: b)
////        let (_, score) = minimax(board: b, depth: 1, isMaximising: b.currentTurn == .white)
//        // normalize to 0-1 range, clamped
//        // eval is roughly -3000 to +3000 in normal positions
//        let normalized = (Double(score) / 6000.0) + 0.5
//        return min(max(normalized, 0), 1)
        
//        let score = node.board.evaluate()  // white-positive
//        let fromWhite = (Double(score) / 6000.0) + 0.5
//        // if it's black's turn at this node, flip it
//        return node.board.currentTurn == .white ? fromWhite : 1.0 - fromWhite
        
//        let score = node.board.evaluate()  // white-positive
//        let normalized = (Double(score) / 6000.0) + 0.5
//        let clamped = min(max(normalized, 0), 1)
//        // currentTurn is who moves NEXT, so the player who just moved is the opposite
//        // return score from the perspective of whoever just moved
//        let justMoved = node.board.currentTurn.opposite
//        return justMoved == .white ? clamped : 1.0 - clamped
        let board = ChessBoard(copying: node.board)
        // let opponent make one move before evaluating
        let opponentMoves = board.legalMoves(for: board.currentTurn)
        if let reply = opponentMoves.randomElement() {
            board.applyMove(reply)
        }
        let score = board.evaluate()
        let normalized = (Double(score) / 6000.0) + 0.5
        let clamped = min(max(normalized, 0), 1)
        let justMoved = node.board.currentTurn.opposite
        return justMoved == .white ? clamped : 1.0 - clamped
     }
    //   return 1.0 for win, 0.0 for loss, 0.5 for draw
    //   (win/loss is from self.color's perspective)

    // 4. Backpropagation — walk up from node to root updating visits and wins
     private func backpropagate(from node: MCTSNode, result: Double) {
//         print("backpropagate\n")
//         var n = node
//         while n.parent != nil {
//             n.wins += result
//             n.visits += 1
//             n = n.parent!
//         }
//         n.wins += result
//         n.visits += 1
         node.wins += result
         node.visits += 1
//         if node.parent != nil {
//             backpropagate(from: node.parent!, result: result)
//         }
         if let parent = node.parent {
             backpropagate(from: parent, result: 1.0 - result)  // flip for opponent
         }
     }
    
    // from other ai
//    private func minimax(board: ChessBoard, depth: Int, isMaximising: Bool, alpha: Int = Int.min, beta: Int = Int.max) -> (Move?, Int) {
//         // your code here
//         
//        var alpha2 = alpha
//        var beta2 = beta
//        
//        let status = board.gameStatus()
////         if status == .checkmate(isMaximising ? .white : .black) {
////             return (nil, !isMaximising ? Int.max : Int.min)
////         } else if status == .checkmate(!isMaximising ? .white : .black) {
////             return (nil, isMaximising ? Int.max : Int.min)
////         } else if status == .draw || status == .stalemate {
////             return (nil, 0)
////         }
//        switch status {
//            case .checkmate(let loser):
//                // whoever is checkmated lost — score from white's perspective
//                return (nil, loser == .white ? -1_000_000 : 1_000_000)
//            case .stalemate, .draw:
//                return (nil, 0)
//            default:
//                break
//        }
//        
//        if depth == 0 {
//            return (nil, evaluateBetter(on: board))
//        }
//        
//         let moves = board.legalMoves(for: isMaximising ? .white : .black)
//         var scores: [Move: Int] = [:]
//         let boardCopy = ChessBoard(copying: board)
//         for move in moves {
//             let cur = ChessBoard(copying: boardCopy)
//             cur.applyMove(move)
//             scores[move] = evaluateBetter(on: cur)
//         }
//         var sorted = scores.sorted { $0.value > $1.value }  // highest score first
//         if !isMaximising {
//             sorted = scores.sorted { $0.value < $1.value }  // lowest score first
//         }
//        var moveRet: Move? = moves[0]
//        var scoreRet: Int = isMaximising ? Int.min : Int.max
//         for entry in sorted {
//             let cur = ChessBoard(copying: boardCopy)
//             cur.applyMove(entry.key)
//             let (_, score) = minimax(board: cur, depth: depth - 1, isMaximising: !isMaximising, alpha: alpha2, beta: beta2)
//             scores[entry.key] = score
//             if (isMaximising && score > scoreRet) || (!isMaximising && score < scoreRet) {
//                 scoreRet = score
//                 moveRet = entry.key
//             }
//             if scoreRet >= beta && isMaximising {
//                 return (moveRet, scoreRet)
//             } else if scoreRet <= alpha && !isMaximising {
//                 return (moveRet, scoreRet)
//             }
//             if isMaximising {
//                 alpha2 = max(alpha2, scoreRet)
//             } else {
//                 beta2 = min(beta2, scoreRet)
//             }
//         }
//        return (moveRet, scoreRet)
////        sorted = scores.sorted { $0.value > $1.value }  // highest score first
////         if !isMaximising {
////             sorted = scores.sorted { $0.value < $1.value }  // lowest score first
////         }
////         return sorted[0]
//     }
}
