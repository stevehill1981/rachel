# Rachel Card Game - Project Brief

## Overview
Create a web-based implementation of "Rachel," a strategic card game played with a standard 52-card deck. The game features special card effects, stacking mechanics, and turn-based multiplayer gameplay with AI opponents.

## Game Rules & Mechanics

### Setup
- **Deck**: Standard 52-card deck (no jokers for standard Rachel)
- **Players**: 4-6 players typically, support up to 8
- **Starting Hands**: Variable based on player count (distribute evenly)
- **Initial Play**: Draw first card from deck to start discard pile

### Basic Gameplay
- **Turn Requirement**: Must play card matching either suit OR number of top discard card
- **No Valid Play**: Must draw one card from deck
- **Forced Play**: If player has valid card, they MUST play it (cannot hold back strategically)
- **Turn Order**: Clockwise by default (can be reversed by Queens)

### Special Card Effects

#### 2s (Any Suit) - Pick Up Cards
- Next player must pick up 2 cards
- **Stacking**: Players can add more 2s to increase penalty
- Damage accumulates until a player cannot play a 2
- That player picks up all accumulated cards (2 × number of 2s played)

#### 7s (Any Suit) - Skip Turn
- Next player skips their turn
- **Stacking**: Multiple 7s = multiple players skip turns
- Players can counter with their own 7, passing the skip effect forward
- Number of 7s played = number of players who miss turns

#### Black Jacks (Spades/Clubs) - Major Penalty
- Next player picks up 5 cards
- **Stacking**: Can play multiple Black Jacks (max 2 in deck = 10 cards max)
- **Counters**: 
  - Red Jack cancels one Black Jack
  - Black Jack passes entire penalty to next player

#### Red Jacks (Hearts/Diamonds) - Defensive Only
- Cancels one Black Jack when played defensively
- No standalone effect when played normally

#### Queens (Any Suit) - Reverse Direction
- Reverses turn order (clockwise ↔ counterclockwise)
- **Multiple Queens**: Cancel each other out (even number = no change, odd number = reverse)

#### Aces (Any Suit) - Suit Choice
- Player nominates any suit for the next player to match
- Next player must play the nominated suit (or another Ace)

### Card Stacking Rules
- **Same Number Only**: Can stack cards of identical number/face value
- **Player Choice**: Can play 1 or multiple matching cards in single turn
- **No Mixed Effects**: Special effects don't combine (e.g., can't mix 7s with other numbers)
- **Effect Consistency**: All cards of same value have same effect (all 7s skip, etc.)

### Deck Management
- **Empty Deck**: When deck runs out, reshuffle all played cards except current top card
- **Reshuffled Deck**: All previously played cards return to play

### Win Conditions
- **Individual Win**: Play all cards in hand to leave the game
- **Game End**: Continue until only one player has cards remaining
- **Multiple Winners**: Players can win by emptying their hand, game continues for remaining players

## Technical Requirements

## Development Environment & Technical Stack

### Required Software Versions
- **Elixir**: 1.18+ (latest stable with type checking and built-in JSON)
- **Phoenix**: 1.8.0-rc.3+ (includes daisyUI, enhanced auth, scopes)
- **Erlang/OTP**: 26.0+ (required for Elixir 1.18)
- **Node.js**: 18+ (for asset compilation)
- **PostgreSQL**: 14+ (locally or via Docker)
- **Git**: For version control

### Phoenix Application Setup
```bash
# Install latest Phoenix with daisyUI support
mix archive.install hex phx_new 1.8.0-rc.3

# Create new Phoenix app with LiveView and PostgreSQL
mix phx.new rachel --live --database postgres
cd rachel

# Key dependencies to add to mix.exs
{:bcrypt_elixir, "~> 3.0"},     # Password hashing
{:phoenix_live_dashboard, "~> 0.8"}, # Monitoring
{:sentry, "~> 10.0"},           # Error tracking
{:ex_machina, "~> 2.7", only: :test}, # Test factories
```

### Asset Pipeline Configuration
- **CSS Framework**: Tailwind CSS + daisyUI (Phoenix 1.8 default)
- **Component System**: daisyUI components for professional card game UI
- **Theme Support**: Built-in light/dark mode, pub-themed customizations
- **JavaScript**: Phoenix default setup with esbuild
- **Icons**: Heroicons (included with Phoenix 1.8)
- **Custom Assets**: Store card images in `priv/static/images/cards/`

### daisyUI Benefits for Rachel
```css
/* Example daisyUI components perfect for card games */
.card { @apply card bg-base-100 shadow-xl; }
.btn-game-action { @apply btn btn-primary; }
.achievement-badge { @apply badge badge-success; }
.player-hand { @apply carousel carousel-center space-x-4; }

/* Built-in theming for pub atmosphere */
[data-theme="dark"] { /* Pub-like dark theme */ }
[data-theme="retro"] { /* 80s/90s nostalgic theme */ }
```

### Card Asset Strategy
**Option 1: SVG Card Library (Recommended)**
```bash
# Use free playing card SVGs from:
# https://github.com/htdebeer/SVG-cards
# Download and place in assets/static/images/cards/
```

**Option 2: CSS-Based Cards**
```css
/* Simple CSS card representation using Unicode suits */
.card { background: white; border: 1px solid #ccc; }
.suit-hearts:after { content: "♥"; color: red; }
.suit-diamonds:after { content: "♦"; color: red; }
.suit-clubs:after { content: "♣"; color: black; }
.suit-spades:after { content: "♠"; color: black; }
```

### Testing Framework & Strategy
- **Primary**: ExUnit (Elixir standard testing framework)
- **LiveView Testing**: Phoenix.LiveViewTest for integration tests
- **Test Factories**: ExMachina for generating test data

#### Key Test Scenarios to Implement
```elixir
# Core game logic tests (high priority)
describe "Rachel.Game" do
  test "2s stack correctly and accumulate pickup count"
  test "black jack + red jack cancellation works"
  test "queen direction reversal handles multiple queens"
  test "forced play rule prevents strategic holding"
  test "deck reshuffling when empty during penalty draws"
end

# LiveView integration tests
describe "GameLive" do
  test "real-time updates propagate to all players"
  test "player disconnection/reconnection flow"
  test "achievement notifications appear correctly"
end
```

### Environment Configuration
```bash
# Development (.env)
DATABASE_URL=postgres://user:pass@localhost/rachel_dev
SECRET_KEY_BASE=generated_key_here
LIVE_VIEW_SIGNING_SALT=generated_salt_here

# Production (set via hosting platform)
DATABASE_URL=postgres://...
SECRET_KEY_BASE=prod_secret_here
LIVE_VIEW_SIGNING_SALT=prod_salt_here
PHX_HOST=play-rachel.com
SENTRY_DSN=optional_error_tracking
PORT=4000
```
- **Backend**: Phoenix LiveView application
- **Game State**: GenServer processes managing individual game sessions
- **Card Logic**: Robust validation for all special card interactions
- **AI System**: Strategic AI opponents with difficulty levels
- **Database**: PostgreSQL for player stats, game history (optional)

### Game Session Management

#### Session Creation & Discovery
- **Game Lobby**: Main page showing available games and player counts
- **Create Game**: 
  - Host sets game name, player limit (4-8), AI difficulty
  - Generates unique game code/URL for sharing
  - Host automatically joins as first player
- **Join Options**:
  - Browse public games in lobby
  - Join via game code/URL shared by host
  - Quick match system (optional)

#### Player Management Flow
```
1. Player visits lobby → sees available games
2. Creates new game OR joins existing game
3. Game session LiveView process spawns/updates
4. Real-time player list updates for all connected players
5. Host can start game when minimum players (2) present
6. Late joiners become spectators if game in progress
```

#### Game Session Architecture
- **GameServer GenServer**: Manages game state, enforces rules
- **GameLive LiveView**: Handles UI updates, player interactions
- **Session Registry**: Track active games and player connections
- **Presence**: Track which players are online/offline

### Multiplayer System
- **Turn-Based**: LiveView handles turn progression with real-time updates
- **Connection Handling**: Graceful disconnection/reconnection
- **Player Slots**: Support AI backfill for disconnected players
### LiveView Implementation Details

#### Game Session Lifecycle
```elixir
# Game creation flow
/lobby → Create Game → /game/:game_id (waiting room)
→ Players join → Host starts → Game begins → Winners exit → Game ends

# Key LiveView processes:
- LobbyLive: Shows available games, handles creation
- GameLive: Main game interface, handles all player interactions
- GameServer: GenServer managing game state and rules
```

#### State Management Pattern
- **GameServer**: Authoritative game state, rule enforcement
- **LiveView**: UI state, user interactions, real-time updates
- **PubSub**: Broadcast game events to all connected players
- **Registry**: Track game sessions and player assignments

#### Player Connection Handling
- **Join Game**: LiveView mount assigns player to game session
- **Disconnection**: Temporary AI takeover, rejoin capability
- **Reconnection**: Restore player state, resume control
- **Permanent Leave**: Convert to AI player or remove from game

### Marketing Site & Onboarding

### Landing Page Requirements
- **Single-page site** at root domain (`/`) with clean, engaging design
- **Hero Section**: Game name, tagline, compelling "Play Now" button
- **Game Overview**: Brief explanation of what makes Rachel unique and fun
- **How to Play**: Clear, visual explanation of basic rules and special cards
- **Features Highlight**: Multiplayer, achievements, stats tracking
- **Social Proof**: Maybe quotes about the 30-year history with your friend group

### Content Structure
```
/ (Landing Page)
├── Hero: "Rachel - The Strategic Card Game" + Play Now CTA
├── What is Rachel?: Brief game overview with appeal
├── How to Play: Visual rule explanations with card examples
├── Features: Multiplayer, achievements, stats, cross-platform
├── Footer: Simple contact/about, link to game lobby
```

### Visual Design Consistency
- **Same pub theme** as main game (beer-stained table, retro feel)
- **Card visuals** showing example hands and special card effects
- **Responsive design** that works on all devices
- **Fast loading** with optimized images and minimal JS

### Call-to-Action Flow
- **Primary CTA**: "Play Now" → `/lobby` (main game entry point)
- **Secondary CTA**: "Learn Rules" → anchor link to how-to-play section
- **Account optional**: Emphasize you can play immediately without signup

### SEO & Discoverability
- **Meta tags**: Optimized for "online card games", "multiplayer card games"
- **Structured data**: Game/entertainment markup for search engines
- **Social sharing**: Open Graph tags for clean Facebook/Twitter sharing
- **Simple analytics**: Basic page view tracking (privacy-friendly)

### Persistence & Player Tracking

#### Player Account System
- **Optional Registration**: Players can play anonymously or create accounts
- **Guest Players**: Full gameplay without account, but no stat tracking
- **Account Benefits**: Persistent stats, achievements, leaderboards
- **Simple Auth**: Username/password or social login options

#### Database Schema
```elixir
# Core tables
players: id, username, email, created_at, total_games, total_wins
games: id, name, status, started_at, finished_at, winner_id, total_players

# Game participation and results
game_players: game_id, player_id, position, cards_remaining, is_ai, joined_at
game_events: game_id, player_id, event_type, event_data, timestamp

# Achievement and stat tracking
achievements: id, player_id, achievement_type, count, first_earned, last_earned
player_stats: player_id, stat_name, value, updated_at
```

#### Fun Stats & Achievements (Worms-style)

**Evil Achievements:**
- "Most Evil" - Double/Triple Black Jack plays
- "Heartbreaker" - Stacked someone with 8+ pickup cards
- "Chain Reaction" - Longest stacking chain initiated
- "No Mercy" - Won with opponent having 15+ cards

**Defensive Heroes:**
- "Red Shield" - Most Black Jacks countered with Red Jacks
- "Escape Artist" - Most penalty card pickups avoided
- "Lucky Duck" - Fewest total cards picked up across all games

**Strategic Mastermind:**
- "Queen Bee" - Most direction changes caused
- "Suit Dictator" - Most successful Ace nominations
- "Perfect Timing" - Won by playing last card as special effect

**Unlucky Legends:**
- "Card Magnet" - Most cards picked up in single game
- "Victim" - Most times targeted by Black Jacks
- "Wrong Turn" - Most times skipped by 7s
- "Deck Destroyer" - Triggered most deck reshuffles

**Social Stats:**
- Longest winning streak
- Biggest comeback (from most cards to winner)
- Fastest game completion
- "Nemesis" tracking (who beats you most often)
- "Favorite Victim" (who you target most with specials)

#### Leaderboard Categories
- **Overall**: Total wins, win percentage
- **Monthly**: Recent performance and streaks  
- **Achievements**: Most evil plays, best defenses
- **Fun Stats**: Biggest card pickups, longest games
- **Friend Groups**: Private leaderboards for regular players

### AI Strategy Considerations
- **Basic AI**: Random valid moves with special card awareness
- **Strategic AI**: 
  - Hold defensive cards (Red Jacks) when opponents have Black Jacks
  - Use special cards strategically (timing 2s and 7s)
  - Track played cards for suit/number availability
  - Manage hand size vs. aggressive play

### User Interface Requirements

#### Visual Design
- **Theme**: Nostalgic pub atmosphere (1980s-90s feel)
- **Cards**: Standard playing card design, clear and readable
- **Table**: Beer-stained wooden table aesthetic
- **Ambient**: Subtle background suggesting pub environment
- **Responsive**: Works on desktop and mobile devices

#### Game Interface
- **Hand Display**: Fan-out card view for current player
- **Discard Pile**: Clear view of top card and pile size
- **Deck Status**: Remaining cards indicator
- **Player Status**: All players' hand sizes and turn indicator
- **Special Effects**: Visual feedback for stacking, skips, penalties
- **Game Log**: History of recent plays and special effects

### Critical Edge Cases to Handle

#### Stacking Scenarios
- Multiple consecutive 2s from different players
- Chain of 7s with counters and passes
- Black Jack + Red Jack combinations
- Multiple Queens changing direction repeatedly

#### Deck Management
- Reshuffling when deck empties during penalty draws
- Ensuring reshuffled cards are properly randomized
- Handling edge case where only one card remains in play

#### Turn Management
- Skipped players don't increment turn counter
- Direction changes affecting skip chains
- Player elimination mid-game

#### Forced Play Validation
- Detecting when player has valid cards but tries to draw
- Preventing strategic holding of playable cards
- Clear feedback when forced to play

## Development Phases

### Phase 1: Foundation & Technical Setup
- **Environment Setup**: Phoenix 1.7+ app with LiveView, PostgreSQL, Tailwind CSS
- **Asset Pipeline**: Card SVG assets, pub-themed CSS styling
- **Marketing Site**: Landing page with rules explanation (`PageController`)
- **Basic Architecture**: Core modules (`Rachel.Games`, `RachelWeb.Live`)
- **Authentication**: Simple player registration system with optional accounts
- **Testing Foundation**: ExUnit setup with test factories for cards/games
- **Development Tools**: Phoenix LiveDashboard, basic error handling

### Phase 2: Core Game Logic & Local Multiplayer
- **Game Engine**: Complete rule implementation with comprehensive test coverage
- **Special Cards**: All effects (2s, 7s, Jacks, Queens, Aces) with stacking logic
- **GameServer**: GenServer managing individual game sessions
- **Local Multiplayer**: Pass-and-play style game in single browser
- **Lobby System**: Create/join games, basic game discovery
- **Database**: Core tables for games, players, game_events
- **Testing**: 80%+ coverage for game logic, key edge cases covered

### Phase 3: Real-time Multiplayer & AI
- **LiveView Integration**: Real-time multiplayer with Phoenix PubSub
- **Connection Handling**: Player disconnection/reconnection with graceful degradation
- **AI Opponents**: Strategic AI with multiple difficulty levels
- **Game Session Management**: Complete player lifecycle (join/leave/spectate)
- **Basic Stats**: Win/loss tracking, game history
- **Performance**: Meet <200ms response time requirements
- **Testing**: Integration tests for multiplayer scenarios

### Phase 4: Achievements & Social Features
- **Achievement System**: Full "Most Evil" style tracking with real-time notifications
- **Statistics Engine**: Leaderboards, player profiles, fun stats
- **Social Features**: Friend groups, private leaderboards
- **Mobile Optimization**: Touch-friendly responsive design
- **Performance**: Scale testing for 500+ concurrent players

### Phase 5: Production Deployment & Polish
- **Deployment**: Fly.io production setup with monitoring
- **Security**: Production secrets, SSL, rate limiting
- **Monitoring**: Sentry error tracking, uptime monitoring
- **Backup Strategy**: Automated database backups with tested recovery
- **API Foundation**: Basic JSON endpoints for future mobile apps
- **Load Testing**: Verify 100+ concurrent game capacity

## Success Criteria
- All card rules implemented correctly, including edge cases
- Smooth multiplayer experience for 4-8 players via LiveView
- Robust game session management (create, join, leave, reconnect)
- Challenging but fair AI opponents
- Intuitive interface that captures the pub game nostalgia
- Engaging achievement system that encourages repeat play
- Fun stats tracking that creates memorable moments and friendly competition
- Graceful handling of player disconnections
- Real-time updates without page refreshes
- Works great for both casual anonymous players and dedicated account holders
- Mobile-friendly responsive design
- **Production-ready deployment** with proper security, monitoring, and backup strategies
- **Scalable architecture** that can handle growth beyond initial friend group

## Non-Functional Requirements

### Performance
- **Response Time**: Card plays and game actions should respond within 200ms
- **Real-time Updates**: Game state changes propagated to all players within 500ms
- **Concurrent Games**: Support 50+ simultaneous games without degradation
- **Memory Efficiency**: Each game session should use <10MB memory
- **Database Queries**: Achievement/stats queries under 100ms

### Scalability & Capacity
- **Player Capacity**: Support 500+ concurrent active players
- **Game Sessions**: Handle 100+ active games simultaneously
- **Database Growth**: Efficient queries as player/game data grows to 10k+ players
- **Horizontal Scaling**: Architecture should support multiple server instances

### Security & Integrity
- **Anti-Cheating**: Server-side validation prevents invalid moves or card manipulation
- **Game State Integrity**: Impossible to modify hand/deck through client manipulation
- **Account Security**: Secure password handling, session management
- **Input Validation**: All player inputs sanitized and validated
- **Rate Limiting**: Prevent spam/abuse of game actions

### Availability & Reliability
- **Uptime Target**: 99.5% availability (acceptable for hobby project)
- **Graceful Degradation**: Game continues if individual players disconnect
- **Error Recovery**: Games can resume after temporary server issues
- **Data Persistence**: No game state lost due to server restarts
- **Fault Tolerance**: Individual game failures don't affect other games

### Usability & Accessibility
- **Mobile Responsive**: Full functionality on phones/tablets (touch-friendly)
- **Browser Support**: Works on Chrome, Firefox, Safari, Edge (last 2 versions)
- **Loading Times**: Initial game load under 3 seconds on decent connection
- **Offline Handling**: Clear feedback when connection lost, auto-reconnect
- **Accessibility**: Keyboard navigation, screen reader friendly card descriptions

### Maintainability & Monitoring
- **Code Quality**: Well-documented, tested code following Elixir/Phoenix conventions
- **Test Coverage**: >80% test coverage for game logic, >60% for LiveView components
- **Logging**: Comprehensive game event and error logging
- **Monitoring**: Health checks, performance metrics, error tracking
- **Deployment**: Simple deployment process, easy rollbacks

### Data & Privacy
- **Data Retention**: Game history kept for 1 year, achievements permanent
- **Privacy**: No tracking beyond game stats, optional account deletion
- **GDPR Compliance**: EU players can export/delete their data
- **Analytics**: Basic usage metrics without personal data collection
- **Backup Strategy**: Regular database backups, tested recovery procedures

### Performance & Scalability
- **Process Per Game**: Each game runs in isolated GenServer
- **Memory Management**: Clean up completed games and disconnected players
- **PubSub Efficiency**: Targeted broadcasts to game participants only
- **LiveView Optimization**: Minimize unnecessary re-renders

### User Experience Patterns
- **Immediate Feedback**: Card plays appear instantly with optimistic updates
- **Loading States**: Clear indicators during game state transitions
- **Error Handling**: Graceful degradation when connection issues occur
- **Mobile Touch**: Card selection and play optimized for touch interfaces

### Game State Synchronization
- **Authority Model**: GameServer is single source of truth
- **Conflict Resolution**: Handle simultaneous player actions gracefully
- **State Recovery**: Players can rejoin and see current game state
- **Validation**: Server-side validation prevents cheating

## Technical Notes for Implementation
- **GenServer for Game Logic**: Use OTP patterns for reliable, fault-tolerant game state management
- **PubSub for Real-time**: Phoenix.PubSub for efficient broadcasting (meets 500ms update requirement)
- **LiveView Components**: Modular components for cards, player hands, game status
- **Process Registry**: Track active games and enable player reconnection
- **Presence**: Monitor player online/offline status for graceful degradation
- **Database Optimization**: Proper indexing for leaderboards and achievement queries
- **Comprehensive Testing**: Unit tests for game rules (80%+ coverage), integration tests for LiveView flows
- **Performance Monitoring**: Use tools like Sentry for error tracking in production
- **Production Deployment**: Fly.io recommended for Phoenix LiveView apps with WebSocket support
- **Environment Configuration**: Proper production config with secrets management
- **Database Strategy**: Managed PostgreSQL with automated backups for achievement preservation
- **Future Enhancement**: Modular design for potential Ultimate Rachel expansion

### Key LiveView Features to Leverage
- **handle_event**: Card plays, game actions, chat messages (with rate limiting)
- **handle_info**: Game state updates from GameServer (optimized for <200ms response)
- **temporary_assigns**: Efficient card rendering to minimize memory usage
- **live_components**: Reusable card and player components
- **live_navigation**: Seamless lobby ↔ game transitions
- **Phoenix.Presence**: Track player connections for reliability

### Getting Started Checklist

### Immediate Development Tasks
1. **Initialize Phoenix App**
   ```bash
   # Install Phoenix 1.8 with daisyUI support
   mix archive.install hex phx_new 1.8.0-rc.3
   
   mix phx.new rachel --live --database postgres
   cd rachel
   mix deps.get
   mix ecto.create
   ```

2. **Add Dependencies** (update `mix.exs`)
   - bcrypt_elixir for authentication
   - sentry for error tracking (production)
   - ex_machina for test factories

3. **Configure daisyUI Theme**
   ```css
   /* In assets/css/app.css - customize for pub atmosphere */
   @import "tailwindcss/base";
   @import "tailwindcss/components";
   @import "tailwindcss/utilities";
   
   /* daisyUI theme configuration */
   @plugin "daisyui" {
     themes: ["light", "dark", "retro", "cyberpunk"];
   }
   ```

4. **Download Card Assets**
   - Get SVG playing cards from recommended source
   - Place in `assets/static/images/cards/`
   - Create daisyUI card components for display

5. **Start with Core Models**
   - `Rachel.Games.Card` - card struct with suit/rank
   - `Rachel.Games.Game` - game state management
   - `Rachel.Games.Rules` - rule validation functions

6. **Test-First Development**
   - Write tests for each special card effect
   - Focus on stacking mechanics and edge cases
   - Aim for 80%+ test coverage on game logic

### Key Success Factors
- **Game Logic First**: Get the card mechanics perfect before focusing on UI
- **Test Coverage**: Complex rules need comprehensive testing
- **daisyUI Components**: Leverage built-in components for professional look
- **Performance**: Design for real-time multiplayer from the start
- **Mobile-First**: Pub games need to work on phones with touch-friendly daisyUI
- **Achievement Fun**: The social stats will drive engagement

This brief provides everything needed to build a complete, production-ready implementation of Rachel using the latest Phoenix 1.8 with daisyUI. The game mechanics are well-defined, the technical architecture leverages modern Phoenix features, and the development path is clear. The daisyUI integration will significantly speed up UI development while ensuring a professional, mobile-friendly experience. Focus on Phase 1-2 for an MVP that captures the core Rachel experience, then expand with achievements and social features.