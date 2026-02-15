//
//  ContentView.swift
//  chessaipractice
//
//  Created by Riley Koo on 2/14/26.
//

import SwiftUI

// MARK: - Root View

struct ContentView: View {
    @StateObject private var vm = GameViewModel()
    @State private var screen: Screen = .home
    @State private var pendingColor: PieceColor? = nil

    enum Screen { case home, depthPicker, game }

    var body: some View {
        switch screen {
        case .home:
            HomeView { mode in
                switch mode {
                case .twoPlayer:
                    vm.startTwoPlayer()
                    screen = .game
                case .vsAI(let playerColor):
                    pendingColor = playerColor
                    screen = .depthPicker
                }
            }
        case .depthPicker:
            DepthPickerView(playerColor: pendingColor ?? .white) { depth in
                vm.startVsAI(playerColor: pendingColor ?? .white, depth: depth)
                screen = .game
            } onBack: {
                screen = .home
            }
        case .game:
            GameView(vm: vm) { screen = .home }
        }
    }
}

// MARK: - Home View

struct HomeView: View {
    let onStart: (GameMode) -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 36) {
                VStack(spacing: 6) {
                    Text("♟")
                        .font(.system(size: 72))
                    Text("Chess")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                }

                VStack(spacing: 14) {
                    Text("Two Players")
                        .font(.headline)
                        .padding(.top, 6)
                        .foregroundColor(.secondary)

                    MenuButton("Play vs Friend", icon: "person.2.fill") {
                        onStart(.twoPlayer)
                    }

                    Divider().padding(.vertical, 4)

                    Text("vs AI Robot")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    MenuButton("Play as White  ♙", icon: "cpu") {
                        onStart(.vsAI(playerColor: .white))
                    }
                    MenuButton("Play as Black  ♟", icon: "cpu") {
                        onStart(.vsAI(playerColor: .black))
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Depth Picker View

struct DepthPickerView: View {
    let playerColor: PieceColor
    let onStart: (Int) -> Void
    let onBack: () -> Void

    @State private var selectedDepth = 3

    private func label(for depth: Int) -> String {
        switch depth {
        case 1: return "Depth 1 — Instant"
        case 2: return "Depth 2 — Fast"
        case 3: return "Depth 3 — Balanced"
        case 4: return "Depth 4 — Slow ⚠️"
        case 5: return "Depth 5 — Very Slow ⚠️"
        default: return "Depth \(depth) — Extremely Slow 🐢"
        }
    }

    private func warning(for depth: Int) -> String? {
        switch depth {
        case 4: return "Expect 5–15 seconds per move."
        case 5: return "May take 30+ seconds per move."
        case 6: return "Could take several minutes per move."
        case 7...10: return "This will likely freeze the app. For research only!"
        default: return nil
        }
    }

    private func warningColor(for depth: Int) -> Color {
        depth >= 6 ? .red : .orange
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 28) {
                // Back + title
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.accentColor)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)

                VStack(spacing: 6) {
                    Text("🤖")
                        .font(.system(size: 52))
                    Text("AI Difficulty")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                    Text("Playing as \(playerColor == .white ? "White ♙" : "Black ♟")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Depth stepper
                VStack(spacing: 12) {
                    HStack(spacing: 20) {
                        Button {
                            if selectedDepth > 1 { selectedDepth -= 1 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(selectedDepth > 1 ? .accentColor : .secondary)
                        }
                        .disabled(selectedDepth <= 1)

                        Text("\(selectedDepth)")
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .frame(width: 90)
                            .monospacedDigit()

                        Button {
                            if selectedDepth < 10 { selectedDepth += 1 }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(selectedDepth < 10 ? .accentColor : .secondary)
                        }
                        .disabled(selectedDepth >= 10)
                    }

                    Text(label(for: selectedDepth))
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                // Warning box
                if let warning = warning(for: selectedDepth) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(warningColor(for: selectedDepth))
                        Text(warning)
                            .font(.subheadline)
                            .foregroundColor(warningColor(for: selectedDepth))
                    }
                    .padding(12)
                    .background(warningColor(for: selectedDepth).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 32)
                    .transition(.opacity)
                    .animation(.easeInOut, value: selectedDepth)
                } else {
                    // Placeholder to keep layout stable
                    Color.clear.frame(height: 44)
                }

                // Start button
                MenuButton("Start Game", icon: "play.fill") {
                    onStart(selectedDepth)
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Game View

struct GameView: View {
    @ObservedObject var vm: GameViewModel
    let onMenu: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ── Status bar ──────────────────────────────────────────────────
            statusBar
                .frame(height: 52)
                .background(Color(.secondarySystemBackground))

            // ── Board ───────────────────────────────────────────────────────
            BoardView(vm: vm)
                .padding(8)

            // ── Captured pieces ─────────────────────────────────────────────
            capturedBar

            // ── Move history ─────────────────────────────────────────────────
            moveHistory
                .frame(maxHeight: 120)

            Spacer(minLength: 4)

            // ── Controls ────────────────────────────────────────────────────
            HStack(spacing: 16) {
                Button { vm.board.setupStartingPosition(); vm.board.currentTurn = .white } label: {
                    Label("New Game", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)

                Button(action: onMenu) {
                    Label("Menu", systemImage: "house")
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 12)
        }
        // ── Promotion sheet ─────────────────────────────────────────────────
        .sheet(item: $vm.promotionPending) { pending in
            let color = vm.board.piece(at: pending.from)?.color ?? .white
            PromotionPickerView(color: color) { pt in
                vm.completePromotion(as: pt)
            }
            .presentationDetents([.height(180)])
        }
        // ── Game-over alert ─────────────────────────────────────────────────
        .alert(isPresented: .constant(isGameOver)) {
            Alert(
                title: Text(gameOverTitle),
                message: Text(gameOverMessage),
                primaryButton: .default(Text("New Game")) {
                    vm.board.setupStartingPosition()
                    vm.board.currentTurn = .white
                    vm.status = .playing
                    vm.lastMove = nil
                    vm.selectedSquare = nil
                    vm.legalTargets = []
                },
                secondaryButton: .cancel(Text("Menu"), action: onMenu)
            )
        }
    }

    // MARK: Sub-views

    @ViewBuilder
    private var statusBar: some View {
        HStack {
            Spacer()
            if vm.aiThinking {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Robot thinking…").font(.subheadline)
                }
            } else {
                VStack(spacing: 2) {
                    Text(turnText).font(.headline)
                    if case .check(let c) = vm.status {
                        Text("\(c == .white ? "White" : "Black") is in check!")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var capturedBar: some View {
        HStack {
            capturedPieces(vm.board.capturedByWhite, label: "White captured:")
            Spacer()
            capturedPieces(vm.board.capturedByBlack, label: "Black captured:")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func capturedPieces(_ pieces: [ChessPiece], label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(pieces.map { $0.symbol }.joined())
                .font(.system(size: 16))
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var moveHistory: some View {
        let history = vm.board.moveHistory
        if history.isEmpty {
            EmptyView()
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    // Pair moves into (white, black?) tuples
                    let pairs = stride(from: 0, to: history.count, by: 2).map { i -> (Int, Move, Move?) in
                        (i / 2 + 1, history[i], i + 1 < history.count ? history[i + 1] : nil)
                    }
                    LazyVStack(spacing: 0) {
                        ForEach(pairs, id: \.0) { num, white, black in
                            HStack(spacing: 0) {
                                Text("\(num).")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 32, alignment: .trailing)
                                Text(algebraic(white))
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(width: 56, alignment: .leading)
                                    .padding(.leading, 6)
                                if let b = black {
                                    Text(algebraic(b))
                                        .font(.system(size: 12, design: .monospaced))
                                        .frame(width: 56, alignment: .leading)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 1)
                            .padding(.horizontal, 8)
                            .background(num % 2 == 0 ? Color(.secondarySystemBackground) : Color.clear)
                            .id(num)
                        }
                    }
                }
                .onChange(of: history.count) { _ in
                    // Auto-scroll to latest move
                    let lastNum = (history.count - 1) / 2 + 1
                    proxy.scrollTo(lastNum, anchor: .bottom)
                }
            }
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    /// Minimal algebraic notation: just from/to squares e.g. "e2e4", with promotion suffix
    private func algebraic(_ move: Move) -> String {
        let promo = move.promotion.map { p -> String in
            switch p {
            case .queen: return "Q"
            case .rook: return "R"
            case .bishop: return "B"
            case .knight: return "N"
            default: return ""
            }
        } ?? ""
        return move.from.algebraic + move.to.algebraic + promo
    }

    // MARK: Computed helpers

    private var turnText: String {
        switch vm.status {
        case .playing, .check: return "\(vm.board.currentTurn == .white ? "⬜ White" : "⬛ Black")'s Turn"
        case .checkmate(let c): return "\(c == .white ? "⬜ White" : "⬛ Black") Checkmated"
        case .stalemate: return "Stalemate"
        case .draw: return "Draw"
        }
    }

    private var isGameOver: Bool {
        switch vm.status {
        case .checkmate, .stalemate, .draw: return true
        default: return false
        }
    }

    private var gameOverTitle: String {
        switch vm.status {
        case .checkmate(let c): return c == .white ? "Black Wins! 🎉" : "White Wins! 🎉"
        case .stalemate: return "Stalemate"
        case .draw: return "Draw"
        default: return ""
        }
    }

    private var gameOverMessage: String {
        switch vm.status {
        case .checkmate: return "Checkmate!"
        case .stalemate: return "No legal moves. It's a draw."
        case .draw: return "Insufficient material to checkmate."
        default: return ""
        }
    }
}

// MARK: - Reusable Button

struct MenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    init(_ title: String, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor.opacity(0.12))
                .foregroundColor(.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .font(.body.weight(.semibold))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Move conformance to Identifiable (for sheet binding)
extension Move: Identifiable {
    public var id: String { "\(from.rank)\(from.file)\(to.rank)\(to.file)\(promotion.map { "\($0)" } ?? "")" }
}

// MARK: - Preview
#Preview {
    ContentView()
}
