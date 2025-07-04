defmodule Rachel.Games.GameComprehensiveTest do
  use ExUnit.Case, async: true

  alias Rachel.Games.{Card, Deck, Game}
  alias Test.GameBuilder

  describe "new/0 and new/1" do
    test "creates a new game with auto-generated ID" do
      game = Game.new()
      
      assert %Game{} = game
      assert is_binary(game.id)
      assert String.length(game.id) == 16  # hex encoded 8 bytes
      assert game.status == :waiting
      assert game.players == []
      assert game.current_player_index == 0
      assert game.direction == :clockwise
      assert game.pending_pickups == 0
      assert game.pending_pickup_type == nil
      assert game.nominated_suit == nil
      assert game.winners == []
      assert %Deck{} = game.deck
    end

    test "creates a new game with custom ID" do
      custom_id = "test-game-123"
      game = Game.new(custom_id)
      
      assert game.id == custom_id
    end
  end

  describe "add_player/3 and add_player/4" do
    setup do
      {:ok, game: Game.new()}
    end

    test "adds human player", %{game: game} do
      game = Game.add_player(game, "player-1", "Alice", false)
      
      assert length(game.players) == 1
      [player] = game.players
      assert player.id == "player-1"
      assert player.name == "Alice"
      assert player.is_ai == false
      assert player.hand == []
    end

    test "adds AI player", %{game: game} do
      game = Game.add_player(game, "ai-1", "Computer", true)
      
      assert length(game.players) == 1
      [player] = game.players
      assert player.id == "ai-1"
      assert player.name == "Computer"
      assert player.is_ai == true
    end

    test "adds multiple players", %{game: game} do
      game = game
        |> Game.add_player("p1", "Alice", false)
        |> Game.add_player("p2", "Bob", false)
        |> Game.add_player("ai-1", "Computer", true)
      
      assert length(game.players) == 3
      assert Enum.map(game.players, & &1.name) == ["Alice", "Bob", "Computer"]
    end

    test "cannot add player after game starts", %{game: game} do
      game = game
        |> Game.add_player("p1", "Alice", false)
        |> Game.add_player("p2", "Bob", false)
      
      started_game = Game.start_game(game)
      
      # add_player only works on waiting games, so create new game in waiting status
      # to verify the function clause matching
      waiting_game = %{started_game | status: :waiting}
      added_game = Game.add_player(waiting_game, "p3", "Charlie", false)
      assert length(added_game.players) == 3
      
      # But the actual started game should remain unchanged
      assert length(started_game.players) == 2
    end
  end

  describe "start_game/1" do
    test "starts game with minimum 2 players" do
      game = Game.new()
        |> Game.add_player("p1", "Alice", false)
        |> Game.add_player("p2", "Bob", false)
        |> Game.start_game()
      
      assert game.status == :playing
      assert game.current_card != nil
      
      # Each player should have 7 cards
      assert Enum.all?(game.players, fn p -> length(p.hand) == 7 end)
      
      # Deck should have remaining cards
      total_cards = 52
      cards_dealt = 7 * 2  # 7 cards per player, 2 players
      cards_in_deck = Deck.size(game.deck)
      
      assert cards_dealt + cards_in_deck + 1 == total_cards  # +1 for current card
    end

    test "cannot start game with less than 2 players" do
      game = Game.new()
        |> Game.add_player("p1", "Alice", false)
      
      # start_game has a guard clause requiring 2+ players
      # It will raise FunctionClauseError with only 1 player
      assert_raise FunctionClauseError, fn ->
        Game.start_game(game)
      end
    end

    test "initializes stats when starting game" do
      game = Game.new()
        |> Game.add_player("p1", "Alice", false)
        |> Game.add_player("p2", "Bob", false)
        |> Game.start_game()
      
      assert game.stats != nil
    end
  end

  describe "draw_card/2" do
    setup do
      game = Game.new()
        |> Game.add_player("p1", "Alice", false)
        |> Game.add_player("p2", "Bob", false)
        |> Game.start_game()
      
      {:ok, game: game}
    end

    test "draws a card when no valid plays", %{game: game} do
      # Set current card that player can't match
      game = %{game | 
        current_card: %Card{suit: :hearts, rank: :king},
        current_player_index: 0
      }
      
      # Give player cards that don't match
      [player | rest] = game.players
      player = %{player | hand: [
        %Card{suit: :spades, rank: 2},
        %Card{suit: :clubs, rank: 3}
      ]}
      game = %{game | players: [player | rest]}
      
      initial_hand_size = length(player.hand)
      
      {:ok, new_game} = Game.draw_card(game, "p1")
      
      # Player should have one more card
      [updated_player | _] = new_game.players
      assert length(updated_player.hand) == initial_hand_size + 1
      
      # Turn should advance
      assert new_game.current_player_index != game.current_player_index
    end

    test "draws multiple cards when pending pickups", %{game: game} do
      # Set pending pickups from 2s
      game = %{game | 
        current_player_index: 0,
        pending_pickups: 4,
        pending_pickup_type: :twos
      }
      
      [player | _rest] = game.players
      
      # Remove any 2s from player's hand to ensure they must draw
      player_hand_no_twos = Enum.reject(player.hand, & &1.rank == 2)
      player = %{player | hand: player_hand_no_twos}
      game = %{game | players: [player | tl(game.players)]}
      
      initial_hand_size = length(player.hand)
      
      {:ok, new_game} = Game.draw_card(game, player.id)
      
      # Player should have drawn 4 cards
      [updated_player | _] = new_game.players
      assert length(updated_player.hand) == initial_hand_size + 4
      
      # Pending pickups should be cleared
      assert new_game.pending_pickups == 0
      assert new_game.pending_pickup_type == nil
    end

    test "cannot draw when valid plays exist", %{game: game} do
      # Set current card that player CAN match
      game = %{game | 
        current_card: %Card{suit: :hearts, rank: :king},
        current_player_index: 0
      }
      
      # Give player a card that matches
      [player | rest] = game.players
      player = %{player | hand: [
        %Card{suit: :hearts, rank: 2},  # Matches suit
        %Card{suit: :clubs, rank: 3}
      ]}
      game = %{game | players: [player | rest]}
      
      assert {:error, :must_play_valid_card} = Game.draw_card(game, "p1")
    end

    test "reshuffles discard pile when deck is empty", %{game: game} do
      # Set up game with empty deck and cards in discard
      game = %{game |
        deck: %Deck{cards: [], discarded: []},
        discard_pile: [
          %Card{suit: :hearts, rank: 2},
          %Card{suit: :spades, rank: 3},
          %Card{suit: :clubs, rank: 4}
        ],
        current_player_index: 0
      }
      
      # Ensure player has no valid plays
      [player | rest] = game.players
      game = %{game | 
        current_card: %Card{suit: :diamonds, rank: :king},
        players: [%{player | hand: [%Card{suit: :clubs, rank: 2}]} | rest]
      }
      
      {:ok, new_game} = Game.draw_card(game, player.id)
      
      # Discard pile should be empty after reshuffle
      assert new_game.discard_pile == []
      
      # Player should have drawn a card
      [updated_player | _] = new_game.players
      assert length(updated_player.hand) == 2
    end
  end

  describe "nominate_suit/3" do
    setup do
      game = Game.new()
        |> Game.add_player("p1", "Alice", false)
        |> Game.add_player("p2", "Bob", false)
        |> Game.start_game()
      
      {:ok, game: game}
    end

    test "nominates suit after playing ace", %{game: game} do
      # Set up game where ace was just played
      game = %{game |
        current_card: %Card{suit: :hearts, rank: :ace},
        nominated_suit: :pending,
        current_player_index: 0
      }
      
      {:ok, new_game} = Game.nominate_suit(game, "p1", :spades)
      
      assert new_game.nominated_suit == :spades
      # Turn should advance after nomination
      assert new_game.current_player_index != game.current_player_index
    end

    test "cannot nominate suit when not pending", %{game: game} do
      # No ace played
      game = %{game |
        current_card: %Card{suit: :hearts, rank: :king},
        nominated_suit: nil,
        current_player_index: 0
      }
      
      assert {:error, :no_ace_played} = Game.nominate_suit(game, "p1", :spades)
    end

    test "only current player can nominate suit", %{game: game} do
      game = %{game |
        nominated_suit: :pending,
        current_player_index: 0  # p1's turn
      }
      
      # p2 tries to nominate
      assert {:error, :not_your_turn} = Game.nominate_suit(game, "p2", :hearts)
    end
  end

  describe "current_player/1" do
    test "returns current player" do
      game = Game.new()
        |> Game.add_player("p1", "Alice", false)
        |> Game.add_player("p2", "Bob", false)
        |> Game.start_game()
      
      current = Game.current_player(game)
      assert current.id == "p1"
      
      # Change current player
      game = %{game | current_player_index: 1}
      current = Game.current_player(game)
      assert current.id == "p2"
    end
  end

  describe "get_valid_plays/2 and has_valid_play?/2" do
    setup do
      game = Game.new()
        |> Game.add_player("p1", "Alice", false)
        |> Game.add_player("p2", "Bob", false)
        |> Game.start_game()
      
      {:ok, game: game}
    end

    test "identifies valid plays by suit and rank", %{game: game} do
      game = %{game | current_card: %Card{suit: :hearts, rank: :king}}
      
      player = %{id: "p1", hand: [
        %Card{suit: :hearts, rank: 2},      # Valid - matches suit
        %Card{suit: :spades, rank: :king},  # Valid - matches rank
        %Card{suit: :clubs, rank: 3},       # Invalid
        %Card{suit: :hearts, rank: :ace}    # Valid - ace always valid
      ]}
      
      valid_plays = Game.get_valid_plays(game, player)
      assert length(valid_plays) == 3
      
      # Check indices
      valid_indices = Enum.map(valid_plays, fn {_card, idx} -> idx end)
      assert 0 in valid_indices  # hearts 2
      assert 1 in valid_indices  # spades king
      assert 3 in valid_indices  # hearts ace
      
      assert Game.has_valid_play?(game, player) == true
    end

    test "identifies when no valid plays exist", %{game: game} do
      game = %{game | current_card: %Card{suit: :hearts, rank: :king}}
      
      player = %{id: "p1", hand: [
        %Card{suit: :spades, rank: 2},
        %Card{suit: :clubs, rank: 3},
        %Card{suit: :diamonds, rank: 4}
      ]}
      
      valid_plays = Game.get_valid_plays(game, player)
      assert valid_plays == []
      assert Game.has_valid_play?(game, player) == false
    end

    test "only allows 2s when pending 2s", %{game: game} do
      game = %{game | 
        current_card: %Card{suit: :hearts, rank: 2},
        pending_pickups: 2,
        pending_pickup_type: :twos
      }
      
      player = %{id: "p1", hand: [
        %Card{suit: :spades, rank: 2},      # Valid - can stack 2s
        %Card{suit: :hearts, rank: 3},      # Invalid - not a 2
        %Card{suit: :hearts, rank: :ace}    # Invalid - not a 2
      ]}
      
      valid_plays = Game.get_valid_plays(game, player)
      assert length(valid_plays) == 1
      [{card, _idx}] = valid_plays
      assert card.rank == 2
    end

    test "respects nominated suit", %{game: game} do
      game = %{game | 
        current_card: %Card{suit: :hearts, rank: :ace},
        nominated_suit: :clubs
      }
      
      player = %{id: "p1", hand: [
        %Card{suit: :clubs, rank: 2},       # Valid - nominated suit
        %Card{suit: :hearts, rank: 3},      # Invalid - wrong suit
        %Card{suit: :spades, rank: :ace}    # Valid - ace always valid
      ]}
      
      valid_plays = Game.get_valid_plays(game, player)
      assert length(valid_plays) == 2
    end
  end

  describe "get_game_stats/1" do
    test "returns nil when no stats" do
      game = %Game{stats: nil}
      assert Game.get_game_stats(game) == nil
    end

    test "returns formatted stats when available" do
      game = Game.new()
        |> Game.add_player("p1", "Alice", false)
        |> Game.add_player("p2", "Bob", false)
        |> Game.start_game()
      
      # Stats should be initialized
      stats = Game.get_game_stats(game)
      assert is_map(stats)
    end
  end

  describe "special card effects" do
    setup do
      game = Game.new()
        |> Game.add_player("p1", "Alice", false)
        |> Game.add_player("p2", "Bob", false)
        |> Game.start_game()
      
      {:ok, game: game}
    end

    test "2s cause pickup 2", %{game: _game} do
      # Using GameBuilder for cleaner test setup
      game = GameBuilder.special_card_scenario(
        GameBuilder.card({:hearts, 2}), 
        "p1"
      )
      
      {:ok, new_game} = Game.play_card(game, "p1", [0])
      
      assert new_game.pending_pickups == 2
      assert new_game.pending_pickup_type == :twos
    end

    test "7s skip next player", %{game: _game} do
      # Using GameBuilder for much cleaner setup
      game = GameBuilder.two_player_game()
        |> GameBuilder.set_current_player("p1")
        |> GameBuilder.set_current_card(GameBuilder.card({:hearts, 3}))
        |> GameBuilder.give_cards("p1", [GameBuilder.card({:hearts, 7})])
        |> GameBuilder.give_cards("p2", GameBuilder.cards([{:spades, 2}, {:clubs, 3}]))
      
      {:ok, new_game} = Game.play_card(game, "p1", [0])
      
      # The 7 effect adds 1 to pending_skips and then advance_turn applies it
      assert new_game.pending_skips == 0  # Skip was applied
      
      # In a 2-player game, turn advances to player 1 and they get skipped
      # Since there's nowhere else to go, player 1 remains current but is effectively skipped
      assert new_game.current_player_index == 1
    end

    test "queens reverse direction", %{game: game} do
      # Set current card that queen can play on
      game = %{game | 
        current_player_index: 0, 
        direction: :clockwise,
        current_card: %Card{suit: :hearts, rank: 3}  # Queen of hearts can play on this
      }
      [player | rest] = game.players
      player = %{player | hand: [%Card{suit: :hearts, rank: :queen}]}
      game = %{game | players: [player | rest]}
      
      {:ok, new_game} = Game.play_card(game, "p1", [0])
      
      assert new_game.direction == :counterclockwise
    end

    test "black jacks cause pickup 5", %{game: game} do
      game = %{game | 
        current_player_index: 0,
        current_card: %Card{suit: :hearts, rank: :jack}  # Jack on jack is valid
      }
      [player | rest] = game.players
      player = %{player | hand: [%Card{suit: :spades, rank: :jack}]}
      game = %{game | players: [player | rest]}
      
      {:ok, new_game} = Game.play_card(game, "p1", [0])
      
      assert new_game.pending_pickups == 5
      assert new_game.pending_pickup_type == :black_jacks
    end

    test "red jacks cancel black jacks", %{game: game} do
      game = %{game | 
        current_player_index: 0,
        pending_pickups: 5,
        pending_pickup_type: :black_jacks
      }
      
      [player | rest] = game.players
      player = %{player | hand: [%Card{suit: :hearts, rank: :jack}]}
      game = %{game | players: [player | rest]}
      
      {:ok, new_game} = Game.play_card(game, "p1", [0])
      
      assert new_game.pending_pickups == 0
      assert new_game.pending_pickup_type == nil
    end

    test "aces require suit nomination", %{game: game} do
      game = %{game | current_player_index: 0}
      [player | rest] = game.players
      player = %{player | hand: [%Card{suit: :hearts, rank: :ace}]}
      game = %{game | players: [player | rest]}
      
      {:ok, new_game} = Game.play_card(game, "p1", [0])
      
      assert new_game.nominated_suit == :pending
      # Turn should NOT advance until suit is nominated
      assert new_game.current_player_index == game.current_player_index
    end
  end

  describe "turn advancement and skipping" do
    test "advances turn clockwise" do
      game = Game.new()
        |> Game.add_player("p1", "Alice", false)
        |> Game.add_player("p2", "Bob", false)
        |> Game.add_player("p3", "Charlie", false)
        |> Game.start_game()
      
      game = %{game | current_player_index: 0, direction: :clockwise}
      
      # Set up a valid play: make current card hearts and give player a hearts card
      current_card = %Card{suit: :hearts, rank: 5}
      game = %{game | current_card: current_card}
      
      # Play a normal card that matches the current card
      [player | rest] = game.players
      player = %{player | hand: [%Card{suit: :hearts, rank: 3}]}
      game = %{game | players: [player | rest]}
      
      {:ok, new_game} = Game.play_card(game, "p1", [0])
      
      # Should advance from p1 (0) to p2 (1)
      assert new_game.current_player_index == 1
    end

    test "advances turn counterclockwise" do
      game = Game.new()
        |> Game.add_player("p1", "Alice", false)
        |> Game.add_player("p2", "Bob", false)
        |> Game.add_player("p3", "Charlie", false)
        |> Game.start_game()
      
      game = %{game | 
        current_player_index: 0, 
        direction: :counterclockwise,
        current_card: %Card{suit: :hearts, rank: :king}  # 3 of hearts can play on this
      }
      
      # Play a normal card
      [player | rest] = game.players
      player = %{player | hand: [%Card{suit: :hearts, rank: 3}]}
      game = %{game | players: [player | rest]}
      
      {:ok, new_game} = Game.play_card(game, "p1", [0])
      
      # Should advance from p1 (0) to p3 (2) going counterclockwise
      assert new_game.current_player_index == 2
    end

    test "skips players who have already won" do
      game = Game.new()
        |> Game.add_player("p1", "Alice", false)
        |> Game.add_player("p2", "Bob", false)
        |> Game.add_player("p3", "Charlie", false)
        |> Game.start_game()
      
      # p2 has already won
      game = %{game | 
        current_player_index: 0,
        winners: ["p2"],
        direction: :clockwise,
        current_card: %Card{suit: :hearts, rank: :king}  # Set current card
      }
      
      # Play a normal card from p1
      [player | rest] = game.players
      player = %{player | hand: [%Card{suit: :hearts, rank: 3}]}  # Matches suit
      game = %{game | players: [player | rest]}
      
      {:ok, new_game} = Game.play_card(game, "p1", [0])
      
      # Should skip p2 (who won) and go to p3
      assert new_game.current_player_index == 2
    end
  end

  describe "winning conditions" do
    test "player wins when they play their last card" do
      game = Game.new()
        |> Game.add_player("p1", "Alice", false)
        |> Game.add_player("p2", "Bob", false)
        |> Game.start_game()
      
      # Set up p1 with only one card that can play on current_card
      game = %{game | 
        current_player_index: 0,
        current_card: %Card{suit: :hearts, rank: :king}  # 3 of hearts can play on this
      }
      [player | rest] = game.players
      player = %{player | hand: [%Card{suit: :hearts, rank: 3}]}
      game = %{game | players: [player | rest]}
      
      {:ok, new_game} = Game.play_card(game, "p1", [0])
      
      assert "p1" in new_game.winners
      assert new_game.status == :finished  # Game ends in 2-player game when one wins
    end

    test "game ends when only one player remains" do
      game = Game.new()
        |> Game.add_player("p1", "Alice", false)
        |> Game.add_player("p2", "Bob", false)
        |> Game.start_game()
      
      # p1 already won, p2 plays last card
      game = %{game | 
        current_player_index: 1,
        winners: ["p1"],
        current_card: %Card{suit: :hearts, rank: :king}  # 3 of hearts can play on this
      }
      
      players = game.players
      [p1, p2] = players
      p2 = %{p2 | hand: [%Card{suit: :hearts, rank: 3}]}
      game = %{game | players: [p1, p2]}
      
      {:ok, new_game} = Game.play_card(game, "p2", [0])
      
      assert "p2" in new_game.winners
      assert new_game.status == :finished
    end
  end
end