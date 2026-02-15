//
//  BoardView.swift
//  chessaipractice
//
//  Created by Riley Koo on 2/14/26.
//

import SwiftUI

// MARK: - Board View

struct BoardView: View {
    @ObservedObject var vm: GameViewModel

    private var isFlipped: Bool {
        if case .vsAI(let playerColor) = vm.gameMode { return playerColor == .black }
        return false
    }

    // When flipped: rank 0 is at top, file 7 is at left
    private var ranks: [Int] { isFlipped ? Array(0..<8) : Array(stride(from: 7, through: 0, by: -1)) }
    private var files: [Int] { isFlipped ? Array(stride(from: 7, through: 0, by: -1)) : Array(0..<8) }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let sq = size / 8

            VStack(spacing: 0) {
                ForEach(ranks, id: \.self) { rank in
                    HStack(spacing: 0) {
                        ForEach(files, id: \.self) { file in
                            let pos = Position(rank, file)
                            SquareView(
                                position: pos,
                                piece: vm.board.piece(at: pos),
                                isSelected: vm.selectedSquare == pos,
                                isLegalTarget: vm.legalTargets.contains(pos),
                                isLastMove: vm.lastMove?.from == pos || vm.lastMove?.to == pos,
                                rankLabel: file == files.first ? "\(rank + 1)" : nil,
                                fileLabel: rank == ranks.last  ? ["a","b","c","d","e","f","g","h"][file] : nil,
                                squareSize: sq
                            )
                            .onTapGesture { vm.tapped(square: pos) }
                        }
                    }
                }
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Square View

struct SquareView: View {
    let position: Position
    let piece: ChessPiece?
    let isSelected: Bool
    let isLegalTarget: Bool
    let isLastMove: Bool
    let rankLabel: String?
    let fileLabel: String?
    let squareSize: CGFloat

    private var baseColor: Color {
        (position.rank + position.file) % 2 == 0
            ? Color(red: 0.47, green: 0.60, blue: 0.34)   // dark green
            : Color(red: 0.93, green: 0.85, blue: 0.73)   // cream
    }

    private var labelColor: Color {
        (position.rank + position.file) % 2 == 0
            ? Color(red: 0.93, green: 0.85, blue: 0.73)
            : Color(red: 0.47, green: 0.60, blue: 0.34)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            baseColor

            if isLastMove  { Color.yellow.opacity(0.45) }
            if isSelected  { Color.green.opacity(0.55) }

            if isLegalTarget {
                if piece != nil {
                    Circle()
                        .strokeBorder(Color.black.opacity(0.3), lineWidth: squareSize * 0.1)
                } else {
                    Circle()
                        .fill(Color.black.opacity(0.22))
                        .padding(squareSize * 0.28)
                }
            }

            if let piece {
                Text(piece.symbol)
                    .font(.system(size: squareSize * 0.72))
                    .foregroundColor(piece.color == .white ? .white : .black)
                    .shadow(color: .black.opacity(0.35), radius: 1, x: 0.5, y: 0.5)
                    .frame(width: squareSize, height: squareSize)
            }

            // Rank label — top-left corner
            if let label = rankLabel {
                Text(label)
                    .font(.system(size: squareSize * 0.22, weight: .semibold))
                    .foregroundColor(labelColor)
                    .padding(2)
            }

            // File label — bottom-right corner
            if let label = fileLabel {
                Text(label)
                    .font(.system(size: squareSize * 0.22, weight: .semibold))
                    .foregroundColor(labelColor)
                    .padding(2)
                    .frame(width: squareSize, height: squareSize, alignment: .bottomTrailing)
            }
        }
        .frame(width: squareSize, height: squareSize)
    }
}
