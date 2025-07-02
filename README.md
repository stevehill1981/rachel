# Rachel Card Game

A fast-paced, strategic card game implemented in Phoenix LiveView. Based on a 30-year old family card game tradition, Rachel combines strategy, luck, and careful card management in a beautifully crafted web interface.

## 🎮 Game Overview

Rachel is played with a standard 52-card deck where players race to empty their hands while navigating special card effects and strategic decisions. The game features:

- **Strategic gameplay** with special card effects
- **Smart AI opponents** with intelligent decision-making  
- **Beautiful animations** and visual feedback
- **Auto-play features** for smooth gameplay
- **Responsive design** that works on any device

## 🃏 Game Rules

### Objective
Be the first player to play all cards from your hand.

### Basic Play
- Players take turns playing cards that match the suit or rank of the top card
- Draw a card if you cannot play
- Special cards trigger unique effects

### Special Cards
- **2s**: Next player picks up 2 cards (stackable)
- **7s**: Skip next player's turn (stackable)
- **Black Jacks** (♠/♣): Next player picks up 5 cards
- **Red Jacks** (♥/♦): Cancel black jack penalty  
- **Queens**: Reverse play direction
- **Aces**: Play on any card and nominate next suit

### Advanced Rules
- Stack multiple cards of the same rank in one turn
- Single cards with no stackable options play automatically
- Pickup penalties are automatically applied when you can't counter
- Must play when you have a valid move

## 🚀 Getting Started

### Prerequisites
- Elixir 1.18+
- Phoenix 1.8.0
- PostgreSQL (for future features)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/rachel.git
cd rachel
```

2. Install dependencies:
```bash
mix setup
```

3. Start the Phoenix server:
```bash
mix phx.server
```

4. Visit [`localhost:4000`](http://localhost:4000) to start playing!

## 🎯 Features

### Current Features
- ✅ Full game implementation with all rules
- ✅ AI opponents with strategic play
- ✅ Beautiful, polished UI with smooth animations
- ✅ Special card visual effects and indicators
- ✅ Auto-play for single cards
- ✅ Auto-draw for forced pickups
- ✅ Turn indicators and game flow visualization
- ✅ Winner celebration with confetti
- ✅ Sound effects for game actions
- ✅ Responsive design for all devices

### Visual Polish
- 🎨 Glowing effects for special cards
- 🎨 Smooth card animations and transitions
- 🎨 AI thinking indicator with animated dots
- 🎨 Direction flow animations
- 🎨 Hover effects and visual feedback
- 🎨 Card entrance animations
- 🎨 Winner celebration effects

### Planned Features
- 🔄 Multiple AI difficulty levels
- 🔄 Tournament mode
- 🔄 Sound effects and haptic feedback

## 🛠️ Technical Stack

- **Backend**: Elixir with Phoenix Framework
- **Frontend**: Phoenix LiveView for real-time updates
- **UI**: Tailwind CSS with custom animations
- **State Management**: GenServer with ETS backing
- **AI**: Rule-based decision engine

## 📝 Development

### Project Structure
```
lib/
├── rachel/
│   └── games/          # Game logic modules
│       ├── game.ex     # Core game engine
│       ├── card.ex     # Card representation
│       ├── deck.ex     # Deck management
│       ├── ai_player.ex # AI decision logic
│       └── stats.ex    # Statistics tracking
└── rachel_web/
    ├── components/
    │   └── game_components.ex # Reusable UI components
    └── live/
        ├── game_live.ex        # LiveView controller
        └── game_live_modern.ex # Modern UI template
```

### Running Tests
```bash
mix test
```

### Code Quality
```bash
mix format        # Format code
mix credo        # Static analysis
mix dialyzer     # Type checking
```

## 🎮 How to Play

1. **Starting**: Each player receives 7 cards
2. **Your Turn**: 
   - Play a card matching suit or rank
   - Stack multiple cards of the same rank
   - Draw if you can't play
3. **Special Effects**: Watch for glowing cards - they have special powers!
4. **Winning**: First to empty their hand wins!

### Tips
- Save your Aces for strategic suit changes
- Stack 2s to increase pickup penalties
- Use 7s to skip opponents close to winning
- Red Jacks are your defense against Black Jacks

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup
```bash
# Run the test watcher
mix test.watch

# Start the dev server with live reload
iex -S mix phx.server
```

## 📜 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- Based on a beloved card game played with friends and family for over 30 years
- Built with the amazing Phoenix LiveView framework
- UI animations inspired by modern card game apps
- Special thanks to the Elixir community

---

Made with ❤️ and Elixir by Steve Hill