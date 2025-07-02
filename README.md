# Rachel Card Game

A strategic card game implemented in Phoenix LiveView. Based on a 30-year old family card game tradition, Rachel is a fast-paced game of strategy, luck, and careful card management.

## 🎮 Game Overview

Rachel is played with a standard 52-card deck where players race to empty their hands while navigating special card effects and strategic decisions. The game features:

- **Strategic gameplay** with special card effects
- **AI opponents** with intelligent decision-making
- **Real-time statistics** tracking performance
- **Save/Load functionality** to pause and resume games
- **Responsive web interface** built with Phoenix LiveView and daisyUI

## 🃏 Game Rules

### Objective
Be the first player to play all cards from your hand.

### Basic Play
- Players take turns playing cards that match the suit or rank of the top card
- Draw a card if you cannot play
- Special cards trigger unique effects

### Special Cards
- **2s**: Next player picks up 2 cards (stackable)
- **7s**: Skip next player's turn
- **Black Jacks** (♠/♣): Next player picks up 5 cards
- **Red Jacks** (♥/♦): Cancel black jack penalty  
- **Queens**: Reverse play direction
- **Aces**: Play on any card and nominate next suit

### Advanced Rules
- Stack multiple cards of the same rank in one turn
- Forced play when possible (no strategic holding)
- Special pickup cards can be countered or stacked

## 🚀 Getting Started

### Prerequisites
- Elixir 1.18+
- Phoenix 1.8.0-rc.3
- PostgreSQL

### Installation

1. Clone the repository:
```bash
git clone https://github.com/stevehill1981/rachel.git
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

4. Visit [`localhost:4000/play`](http://localhost:4000/play) to start playing!

## 🎯 Features

### Current Features
- ✅ Full game implementation with all rules
- ✅ AI opponents with strategic play
- ✅ Game statistics and scoring system
- ✅ Save/load game functionality
- ✅ Responsive UI with real-time updates

### Planned Features
- 🔄 Multiple AI difficulty levels
- 🔄 Tournament mode
- 🔄 Online multiplayer
- 🔄 Player profiles and statistics tracking
- 🔄 Achievement system

## 🛠️ Technical Stack

- **Backend**: Elixir with Phoenix Framework
- **Frontend**: Phoenix LiveView
- **UI**: Tailwind CSS with daisyUI
- **Database**: PostgreSQL (prepared for future features)
- **Real-time**: Phoenix PubSub

## 📝 Development

### Project Structure
```
lib/
├── rachel/
│   └── games/          # Game logic modules
│       ├── game.ex     # Core game engine
│       ├── card.ex     # Card representation
│       ├── deck.ex     # Deck management
│       ├── ai_player.ex # AI logic
│       ├── stats.ex    # Statistics tracking
│       └── game_save.ex # Save/load functionality
└── rachel_web/
    └── live/
        └── game_live.ex # LiveView interface
```

### Running Tests
```bash
mix test
```

### Code Formatting
```bash
mix format
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📜 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- Based on a card game played with friends and family for over 30 years
- Built with Phoenix LiveView and the amazing Elixir community tools
- UI powered by Tailwind CSS and daisyUI

---

Made with ❤️ and Elixir
