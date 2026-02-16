//
//  GameViewModel.swift
//  chessaipractice
//
//  Created by Riley Koo on 2/14/26.
//

import SwiftUI
import Combine

// MARK: - AI Type

enum AIType {
    case minimax(depth: Int)
    case mcts(iterations: Int)
}

// MARK: - Game Mode

enum GameMode {
    case twoPlayer
    case vsAI(playerColor: PieceColor)
}

// MARK: - Game View Model

@MainActor
class GameViewModel: ObservableObject {

    @Published var board = ChessBoard()
    @Published var selectedSquare: Position? = nil
    @Published var legalTargets: [Position] = []
    @Published var status: GameStatus = .playing
    @Published var promotionPending: Move? = nil
    @Published var lastMove: Move? = nil
    @Published var aiThinking = false

    var gameMode: GameMode = .twoPlayer
    private var minimaxAI: ChessAI? = nil
    private var mctsAI: ChessMCTS? = nil
    private var aiTask: Task<Void, Never>? = nil

    let openingBook = ChessOpeningBook()
    @Published var currentOpeningName: String? = nil
    var selectedOpening: String? = nil   // nil = any book line, set to lock to a specific opening

    init() {
        if let url = Bundle.main.url(forResource: "eco_interpolated", withExtension: "json") {
            print("✅ Found json at: \(url)")
        } else {
            print("❌ Could not find eco_interpolated.json in bundle")
            // list everything in bundle to see what's there
            let paths = Bundle.main.paths(forResourcesOfType: "json", inDirectory: nil)
            print("JSON files in bundle: \(paths)")
        }
        openingBook.load()
    }

    // MARK: - Start / Reset

    func startTwoPlayer() {
        gameMode = .twoPlayer
        minimaxAI = nil
        mctsAI = nil
        resetBoard()
    }

    func startVsAI(playerColor: PieceColor, aiType: AIType) {
        gameMode = .vsAI(playerColor: playerColor)
        minimaxAI = nil
        mctsAI = nil
        switch aiType {
        case .minimax(let depth):
            minimaxAI = ChessAI(color: playerColor.opposite, depth: depth)
        case .mcts(let iterations):
            mctsAI = ChessMCTS(color: playerColor.opposite, iterations: iterations)
        }
        resetBoard()
        if playerColor == .black {
            triggerAIMove()
        }
    }

    private func resetBoard() {
        aiTask?.cancel()
        board = ChessBoard()
        selectedSquare = nil
        legalTargets = []
        status = .playing
        promotionPending = nil
        lastMove = nil
        aiThinking = false
    }

    // MARK: - Square Tap Handler

    func tapped(square: Position) {
        // Block input while AI is thinking or game is over
        guard !aiThinking, isGameActive else { return }

        // Block input if it's the AI's turn
        if case .vsAI(let playerColor) = gameMode, board.currentTurn != playerColor { return }

        if let selected = selectedSquare {
            // A piece was already selected — try to move
            if let move = legalTargets.contains(square) ? moveFrom(selected, to: square) : nil {
                handleMoveAttempt(move)
            } else if let p = board.piece(at: square), p.color == board.currentTurn {
                // Tapped a different friendly piece — re-select
                select(square)
            } else {
                // Tapped empty / enemy with no valid move — deselect
                deselect()
            }
        } else {
            // Nothing selected yet — select if friendly piece
            if let p = board.piece(at: square), p.color == board.currentTurn {
                select(square)
            }
        }
    }

    // MARK: - Promotion Picker

    func completePromotion(as pieceType: PieceType) {
        guard let pending = promotionPending else { return }
        let move = Move(from: pending.from, to: pending.to, promotion: pieceType)
        promotionPending = nil
        applyAndAdvance(move)
    }

    // MARK: - Helpers

    private func select(_ pos: Position) {
        selectedSquare = pos
        legalTargets = board.legalMoves(from: pos).map { $0.to }
    }

    private func deselect() {
        selectedSquare = nil
        legalTargets = []
    }

    private func moveFrom(_ from: Position, to: Position) -> Move? {
        board.legalMoves(from: from).first { $0.to == to }
    }

    private func handleMoveAttempt(_ move: Move) {
        deselect()

        // Pawn reaching promotion rank — surface picker if not already specified
        if let piece = board.piece(at: move.from),
           piece.type == .pawn,
           move.promotion == nil,
           (move.to.rank == 7 || move.to.rank == 0) {
            promotionPending = move
            return
        }

        applyAndAdvance(move)
    }

    private func applyAndAdvance(_ move: Move) {
        board.applyMove(move)
        lastMove = move
        status = board.gameStatus()

        guard isGameActive else { return }
        triggerAIMove()
    }

    private var isGameActive: Bool {
        status == .playing || { if case .check(_) = status { return true }; return false }()
    }

    // MARK: - AI Turn

    private func triggerAIMove() {
        guard case .vsAI(_) = gameMode else { return }
        let isMinimaxTurn = minimaxAI.map { $0.color == board.currentTurn } ?? false
        let isMCTSTurn    = mctsAI.map    { $0.color == board.currentTurn } ?? false
        // Also allow book-only mode (no AI set yet)
        guard isMinimaxTurn || isMCTSTurn || openingBook.isLoaded else { return }

        aiThinking = true

        aiTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let boardCopy = await ChessBoard(copying: self.board)
            let book      = await self.openingBook
            let opening   = await self.selectedOpening

            // 1. Try opening book first
            let bookMove: Move? = {
                if let name = opening {
                    return book.nextMove(for: boardCopy, opening: name)
                }
                return book.nextMove(for: boardCopy)
            }()

            let move: Move?
            if let bm = bookMove {
                move = bm
                let name = book.openingName(for: boardCopy)
                await MainActor.run { self.currentOpeningName = name }
            } else {
                await MainActor.run { self.currentOpeningName = nil }
                if let minimax = await self.minimaxAI {
                    move = minimax.bestMove(on: boardCopy)
                } else if let mcts = await self.mctsAI {
                    move = mcts.bestMove(on: boardCopy)
                } else {
                    move = nil
                }
            }

            await MainActor.run {
                self.aiThinking = false
                guard let move else { return }
                self.board.applyMove(move)
                print("AI (\(self.board.currentTurn.opposite == .white ? "White" : "Black")): \(move.from.algebraic)\(move.to.algebraic)")
                self.lastMove = move
                self.status = self.board.gameStatus()
            }
        }
    }
}
