# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rachel is a Phoenix LiveView application implementing a strategic card game. It's a polished web game with AI opponents, real-time gameplay, and beautiful animations.

## Essential Commands

### Development
- `mix setup` - Full project setup (installs deps, creates DB, builds assets)
- `mix phx.server` - Start development server on http://localhost:4000
- `iex -S mix phx.server` - Start server with interactive shell

### Testing
- `mix test` - Run all tests
- `mix test test/rachel/games/game_test.exs` - Run specific test file
- `mix test test/rachel/games/game_test.exs:123` - Run test at specific line
- `mix test.watch` - Run tests in watch mode
- `mix coveralls` - Run tests with coverage report

### Code Quality
- `mix format` - Format code according to Elixir standards
- `mix credo --strict` - Run static code analysis
- `mix dialyzer` - Run type checking (slow on first run)
- `mix sobelow` - Security vulnerability scanning
- `mix deps.audit` - Check dependencies for vulnerabilities
- `./check.sh` - Run ALL quality checks at once

### Assets
- `mix assets.build` - Build CSS and JS assets
- `mix assets.deploy` - Build minified assets for production

## Architecture

### Game Engine (`lib/rachel/games/`)
The core game logic is separate from the web layer:
- `game.ex` - Main game state machine and rule enforcement
- `card.ex` - Card representation with rank/suit
- `deck.ex` - Deck shuffling and dealing
- `ai_player.ex` - AI decision-making logic
- `stats.ex` - Game statistics tracking

### Web Layer (`lib/rachel_web/`)
Phoenix LiveView handles real-time updates:
- `live/game_live.ex` - LiveView process managing game state
- `components/game_components.ex` - Reusable UI components
- `live/game_live_modern.html.heex` - Modern UI template

### Key Patterns
1. **State Management**: Game state is managed in LiveView socket assigns
2. **AI Turns**: Handled via `Process.send_after/3` for natural pacing
3. **Animations**: CSS classes added/removed via LiveView's JS commands
4. **Auto-play**: Single valid cards play automatically for smoother UX

## Game Rules Implementation

### Special Cards (in `game.ex`)
- **2s**: Force next player to pick up 2 (stackable)
- **7s**: Skip next player (stackable)
- **Black Jacks**: Force pickup of 5 cards
- **Red Jacks**: Counter black jacks
- **Queens**: Reverse play direction
- **Aces**: Wild cards that set the suit

### Key Functions
- `Game.play_cards/3` - Validates and applies card plays
- `Game.valid_play?/3` - Checks if a move is legal
- `AIPlayer.choose_play/2` - AI decision logic

## Development Tips

1. **LiveView Updates**: Changes to game state should go through `update/2` in `game_live.ex`
2. **Animations**: Add CSS classes in `assets/css/game.css`, apply via JS commands
3. **Testing AI**: Use `AIPlayer.choose_play/2` directly in tests
4. **Debugging**: Use `IO.inspect(label: "...")` in LiveView callbacks

## Common Tasks

### Adding a New Card Effect
1. Update `Game.apply_card_effects/3` in `lib/rachel/games/game.ex`
2. Add visual indicator in `game_components.ex` `card_class/1`
3. Update AI logic in `ai_player.ex` if needed
4. Add tests in `test/rachel/games/game_test.exs`

### Modifying AI Behavior
1. Edit `lib/rachel/games/ai_player.ex`
2. Key functions: `choose_play/2`, `score_play/3`, `find_best_play/2`
3. Test with `mix test test/rachel/games/ai_player_test.exs`

### UI/UX Changes
1. Styles: `assets/css/game.css` for animations, Tailwind classes in templates
2. Components: `lib/rachel_web/components/game_components.ex`
3. Interactions: JS commands in `game_live_modern.html.heex`

## Security Considerations
- No user authentication currently implemented
- Game state is session-based (no persistence)
- CSRF protection enabled by default in Phoenix
- Run `mix sobelow` before deploying