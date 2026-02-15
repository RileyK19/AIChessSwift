//
//  GameViewModel.swift
//  chessaipractice
//
//  Created by Riley Koo on 2/14/26.
//

import SwiftUI
import Combine

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
    @Published var promotionPending: Move? = nil    // waiting for user to pick promotion piece
    @Published var lastMove: Move? = nil
    @Published var aiThinking = false

    var gameMode: GameMode = .twoPlayer
    private var ai: ChessAI? = nil
    private var aiTask: Task<Void, Never>? = nil

    // MARK: - Start / Reset

    func startTwoPlayer() {
        gameMode = .twoPlayer
        ai = nil
        resetBoard()
    }

    func startVsAI(playerColor: PieceColor, depth: Int = 3) {
        gameMode = .vsAI(playerColor: playerColor)
        ai = ChessAI(color: playerColor.opposite, depth: depth)
        resetBoard()
        // If player chose black, AI (white) moves first
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
        print("\(board.currentTurn.opposite == .white ? "White" : "Black"): \(move.from.algebraic)\(move.to.algebraic)")
        status = board.gameStatus()

        guard isGameActive else { return }
        triggerAIMove()
    }

    private var isGameActive: Bool {
        status == .playing || { if case .check(_) = status { return true }; return false }()
    }

    // MARK: - AI Turn

    private func triggerAIMove() {
        guard let ai else { return }
        guard case .vsAI(_) = gameMode else { return }
        guard board.currentTurn == ai.color else { return }

        aiThinking = true

        aiTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let boardCopy = await ChessBoard(copying: self.board)
            let move = ai.bestMove(on: boardCopy)

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
