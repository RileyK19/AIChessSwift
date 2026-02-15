# ♟ Chess AI — Minimax from Scratch

A fully playable iOS chess app built in SwiftUI, designed as a learning project for implementing minimax AI with alpha-beta pruning.

The game engine is complete — move generation, check/checkmate/stalemate detection, castling, en passant, pawn promotion. The AI stub is intentionally left for you to implement.

---

## Screenshots

<!-- Add screenshots here -->

---

## Features

- Full chess rules engine (all special moves included)
- Two player local mode
- vs AI mode with configurable search depth (1–10)
- Board flips when playing as black
- Move history list with algebraic notation
- Captured pieces display
- Promotion picker
- Dark mode support

---

## AI Implementation

The engine is in `ChessAI.swift`. The `bestMove(on:)` method is where the minimax search lives.

Current implementation:
- Minimax with alpha-beta pruning
- Move ordering by surface evaluation (helps pruning)
- Custom evaluation function combining:
  - Material score (piece values)
  - Tension (hanging/contested pieces)
  - Activity (piece pressure on enemy pieces)
  - Piece-square tables (positional bonuses)

### Evaluation Heuristics

| Component | What it measures |
|---|---|
| Material | Raw piece values (pawn=100, knight=320, bishop=330, rook=500, queen=900) |
| Tension | Penalty for hanging pieces, small penalty for contested pieces |
| Activity | Bonus for pieces that are eyeing high-value enemy targets |
| Positional | Piece-square tables rewarding good squares (center control, king safety) |

---

## Project Structure

```
ChessApp/
├── Models.swift          # Position, ChessPiece, Move, GameStatus
├── ChessBoard.swift      # Full rules engine + evaluate()
├── ChessAI.swift         # Minimax AI — the interesting file
├── GameViewModel.swift   # State machine connecting board ↔ UI ↔ AI
├── BoardView.swift       # SwiftUI board rendering
├── ContentView.swift     # Screens: home, depth picker, game
└── PromotionPickerView.swift
```

---

## Setup

1. Clone the repo
2. Open in Xcode (16.2+ recommended)
3. Select your simulator or device
4. Build and run — no dependencies, no package manager

---

## How Minimax Works

The AI searches a game tree of possible moves to a fixed depth, assuming both sides play optimally.

```
minimax(board, depth, isMaximising):
    if depth == 0 or game over:
        return evaluate(board)

    if isMaximising:          # white wants highest score
        best = -∞
        for each move:
            copy board, apply move
            best = max(best, minimax(copy, depth-1, false))
        return best
    else:                     # black wants lowest score
        best = +∞
        for each move:
            copy board, apply move
            best = min(best, minimax(copy, depth-1, true))
        return best
```

Alpha-beta pruning cuts branches that can't affect the final result, allowing deeper search in the same time.

### Depth vs Speed (approximate, varies by position)

| Depth | Speed |
|---|---|
| 1–2 | Instant |
| 3 | ~1 second |
| 4 | ~5–15 seconds |
| 5+ | Very slow |

---

## Things to Try

- **Quiescence search** — keep searching captures past the depth limit to avoid the horizon effect
- **Iterative deepening** — search depth 1, 2, 3... using shallower results to order moves better
- **Transposition table** — cache already-evaluated positions to avoid redundant work
- **Better evaluation** — pawn structure, king safety, rook on open files

---

## Built With

- Swift / SwiftUI
- No external dependencies

---

## License

MIT
