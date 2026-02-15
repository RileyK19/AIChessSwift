# ChessApp — Minimax Starter

A fully playable SwiftUI chess app built for you to plug in your own minimax AI.

---

## Files

| File | Purpose |
|---|---|
| `Models.swift` | `Position`, `ChessPiece`, `Move`, `GameStatus` |
| `ChessBoard.swift` | Full rules engine — move generation, check, castling, en passant, promotion |
| **`ChessAI.swift`** | ⭐ **Your file** — implement `bestMove(on:)` here |
| `GameViewModel.swift` | State machine connecting board ↔ UI ↔ AI |
| `BoardView.swift` | SwiftUI board + square rendering |
| `ContentView.swift` | Home screen, game screen, promotion picker |

---

## Setup in Xcode

1. **New Project** → iOS → App
   - Product Name: `ChessApp`
   - Interface: `SwiftUI`
   - Language: `Swift`

2. **Delete** the generated `ContentView.swift`

3. **Drag all `.swift` files** from this folder into the Xcode project navigator
   (check "Copy items if needed")

4. **Add board colors** (optional): In `Assets.xcassets` add two Color Sets named
   `LightSquare` and `DarkSquare`. If you skip this, Xcode will warn but the app
   will still build — edit `SquareView` in `BoardView.swift` to use the fallback colors.

5. **Run** on the simulator or device — two-player mode works immediately.

---

## Implementing Your Minimax AI

Open **`ChessAI.swift`**. The only method you need to implement is:

```swift
func bestMove(on board: ChessBoard) -> Move?
```

The starter code just picks a random legal move. Replace it with minimax.

### Key ChessBoard API

```swift
// Get all legal moves for a side
let moves = board.legalMoves(for: .white)   // → [Move]

// Apply a move (mutates the board — copy first!)
let copy = ChessBoard(copying: board)
copy.applyMove(someMove)

// Evaluate the position (white-positive, material only to start)
let score = board.evaluate()   // → Int

// Check game status
let status = board.gameStatus()
// → .playing | .check(color) | .checkmate(color) | .stalemate | .draw
```

### Minimax Pseudocode

```
minimax(board, depth, isMaximising):
    if depth == 0 or game over:
        return board.evaluate()

    if isMaximising:            // White's turn — wants highest score
        best = -∞
        for move in board.legalMoves(for: .white):
            copy = ChessBoard(copying: board)
            copy.applyMove(move)
            score = minimax(copy, depth - 1, false)
            best = max(best, score)
        return best

    else:                       // Black's turn — wants lowest score
        best = +∞
        for move in board.legalMoves(for: .black):
            copy = ChessBoard(copying: board)
            copy.applyMove(move)
            score = minimax(copy, depth - 1, true)
            best = min(best, score)
        return best
```

### Step-by-step progression

1. **Implement basic minimax** (depth 2–3) — should already beat random
2. **Add alpha-beta pruning** — same results, much faster, allows deeper search
3. **Improve `evaluate()`** in `ChessBoard.swift`:
   - Add piece-square tables (reward knights in the center, etc.)
   - Reward mobility (count legal moves)
   - Penalise doubled/isolated pawns
4. **Add move ordering** — try captures first for better alpha-beta cutoffs
5. **Add quiescence search** — keep searching captures past the depth limit to avoid horizon effect

### Adjust search depth

```swift
// In GameViewModel.startVsAI():
vm.startVsAI(playerColor: .white, depth: 3)
//                                       ^ change this (3 = good starting point)
// depth 1 = trivial   depth 3 = decent   depth 5 = slow but strong
```

---

## Board Coordinate System

```
rank 7  ♜ ♞ ♝ ♛ ♚ ♝ ♞ ♜   ← Black back rank
rank 6  ♟ ♟ ♟ ♟ ♟ ♟ ♟ ♟
rank 5  .  .  .  .  .  .  .  .
rank 4  .  .  .  .  .  .  .  .
rank 3  .  .  .  .  .  .  .  .
rank 2  .  .  .  .  .  .  .  .
rank 1  ♙ ♙ ♙ ♙ ♙ ♙ ♙ ♙
rank 0  ♖ ♘ ♗ ♕ ♔ ♗ ♘ ♖   ← White back rank
        a  b  c  d  e  f  g  h
       file 0 ............ file 7
```

`evaluate()` is always from White's perspective (positive = good for white).
