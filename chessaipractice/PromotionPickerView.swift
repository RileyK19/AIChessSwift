//
//  PromotionPickerView.swift
//  chessaipractice
//
//  Created by Riley Koo on 2/14/26.
//

import SwiftUI

// MARK: - Promotion Picker

struct PromotionPickerView: View {
    let color: PieceColor
    let onSelect: (PieceType) -> Void

    private let choices: [PieceType] = [.queen, .rook, .bishop, .knight]

    var body: some View {
        VStack(spacing: 16) {
            Text("Promote Pawn")
                .font(.title2.bold())
                .padding(.top)

            HStack(spacing: 24) {
                ForEach(choices, id: \.self) { pt in
                    let dummy = ChessPiece(type: pt, color: color)
                    Button {
                        onSelect(pt)
                    } label: {
                        Text(dummy.symbol)
                            .font(.system(size: 56))
                            .frame(width: 72, height: 72)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom)
        }
        .padding()
    }
}
