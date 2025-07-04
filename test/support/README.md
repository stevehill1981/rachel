# Test Builders Documentation

This directory contains test builders and helpers that make writing tests much easier and more maintainable.

## GameBuilder

The `GameBuilder` module provides a fluent API for building game states in tests.

### Basic Usage

```elixir
alias Test.GameBuilder

# Create a simple 2-player game
game = GameBuilder.two_player_game()

# Create and configure a custom game
game = GameBuilder.new()
  |> GameBuilder.with_players([{"p1", "Alice", false}, {"p2", "Bob", false}])
  |> GameBuilder.start_game()
  |> GameBuilder.set_current_player("p1")
  |> GameBuilder.set_current_card(GameBuilder.card({:hearts, 3}))
  |> GameBuilder.give_cards("p1", [GameBuilder.card({:hearts, 7})])
```

### Common Scenarios

```elixir
# Test special card effects
game = GameBuilder.special_card_scenario(
  GameBuilder.card({:hearts, 2}), 
  "p1"
)

# Test winning conditions
game = GameBuilder.winning_scenario(
  "p1", 
  GameBuilder.card({:hearts, 7})
)

# Test pending pickups
game = GameBuilder.pending_twos_scenario("p1", 2)  # 4 pickups from 2 twos
```

### Card Creation Helpers

```elixir
# Various ways to create cards
card1 = GameBuilder.card({:hearts, 7})
card2 = GameBuilder.card("7H")  # String notation
cards = GameBuilder.cards([{:hearts, 7}, {:spades, :ace}])
```

## GameServerBuilder  

The `GameServerBuilder` module helps create and manage GameServer processes for integration tests.

### Basic Usage

```elixir
alias Test.GameServerBuilder

# Start a server and set up a game
{game_id, pid} = GameServerBuilder.start_server()
  |> GameServerBuilder.with_cleanup()  # Auto-cleanup when test ends
  |> GameServerBuilder.add_players(["alice", "bob"])
  |> GameServerBuilder.start_game("alice")

# Get current state
state = GameServerBuilder.get_state({game_id, pid})

# Play cards
{game_id, pid} = GameServerBuilder.play_valid_card({game_id, pid}, "alice")
```

### Common Scenarios

```elixir
# Human vs AI game
{game_id, pid} = GameServerBuilder.human_vs_ai_game()

# Test reconnection
{game_id, pid} = GameServerBuilder.reconnection_scenario("player1")
  |> GameServerBuilder.reconnect_player("player1")

# Timeout testing
{game_id, pid} = GameServerBuilder.timeout_game(100)  # 100ms timeout
```

## AITestHelper

The `AITestHelper` module provides scenarios and assertions specifically for AI player testing.

### Basic Usage

```elixir
alias Test.AITestHelper

# Create AI test scenarios
game = AITestHelper.ai_scenario(:play_ace, "ai")
game = AITestHelper.ai_scenario(:prefer_non_ace, "ai") 
game = AITestHelper.ai_scenario(:no_valid_plays, "ai")

# Test AI decisions
assert {:play, 0} = AITestHelper.ai_move(game, "ai")
assert AITestHelper.ai_chooses_play?(game, "ai", 0)
assert AITestHelper.ai_chooses_draw?(game, "ai")
```

### Available AI Scenarios

- `:play_ace` - AI has only an ace to play
- `:prefer_non_ace` - AI has both ace and matching card (should prefer non-ace)
- `:stack_twos` - AI can stack 2s on pending 2s
- `:no_valid_plays` - AI must draw
- `:nominate_suit` - AI needs to nominate suit after ace
- `:counter_black_jack` - AI can counter black jack with red jack
- `:skip_opponent` - AI can play 7 to skip opponent

## Before and After Examples

### Before: Manual Game Setup

```elixir
test "7s skip next player", %{game: game} do
  game = %{game | 
    current_player_index: 0,
    current_card: %Card{suit: :hearts, rank: 3}
  }
  [player1, player2] = game.players
  
  player1 = %{player1 | hand: [%Card{suit: :hearts, rank: 7}]}
  player2 = %{player2 | hand: [
    %Card{suit: :spades, rank: 2},
    %Card{suit: :clubs, rank: 3}
  ]}
  
  game = %{game | players: [player1, player2]}
  
  {:ok, new_game} = Game.play_card(game, "p1", [0])
  # assertions...
end
```

### After: Using GameBuilder

```elixir
test "7s skip next player", %{game: _game} do
  game = GameBuilder.two_player_game()
    |> GameBuilder.set_current_player("p1")
    |> GameBuilder.set_current_card(GameBuilder.card({:hearts, 3}))
    |> GameBuilder.give_cards("p1", [GameBuilder.card({:hearts, 7})])
    |> GameBuilder.give_cards("p2", GameBuilder.cards([{:spades, 2}, {:clubs, 3}]))
  
  {:ok, new_game} = Game.play_card(game, "p1", [0])
  # assertions...
end
```

## Benefits

1. **Readability**: Tests clearly express intent rather than implementation details
2. **Maintainability**: Changes to game structure only require updating builders
3. **Reusability**: Common scenarios can be reused across tests
4. **Consistency**: Reduces copy-paste errors and ensures consistent test setup
5. **Documentation**: Builder method names serve as living documentation

## Best Practices

1. **Always use builders for new tests** - Don't manually construct game states
2. **Create scenario helpers** - If you find yourself repeating the same setup, add it to the appropriate builder
3. **Use cleanup helpers** - Always call `with_cleanup()` for GameServer tests
4. **Prefer semantic methods** - Use `two_player_game()` instead of manual player addition
5. **Chain operations** - Take advantage of the fluent API for readable test setup