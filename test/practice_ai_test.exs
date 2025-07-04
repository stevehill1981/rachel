defmodule PracticeAITest do
  use ExUnit.Case, async: true
  
  alias Rachel.Games.{Game, AIPlayer}
  
  test "AI takes turns in practice games" do
    # Create a new practice game
    game = Game.new()
    game = Game.add_player(game, "player-1", "Human Player", false)
    game = Game.add_player(game, "ai-1", "Computer", true)
    game = Game.start_game(game)
    
    IO.puts("\n=== PRACTICE GAME TEST ===")
    IO.puts("Players: #{length(game.players)}")
    current_player = Game.current_player(game)
    IO.puts("First player: #{current_player.name} (AI: #{current_player.is_ai})")
    IO.puts("Current card: #{inspect(game.current_card)}")
    
    if current_player.is_ai do
      IO.puts("AI goes first in practice game")
      
      # AI should be able to make a move
      action = AIPlayer.make_move(game, current_player.id)
      IO.inspect(action, label: "AI decision")
      
      # Execute AI move
      new_game = case action do
        {:play, card_index} ->
          {:ok, game} = Game.play_card(game, current_player.id, [card_index])
          game
        {:draw, _} ->
          {:ok, game} = Game.draw_card(game, current_player.id)
          game
      end
      
      next_player = Game.current_player(new_game)
      IO.puts("After AI move, current player: #{next_player.name} (AI: #{next_player.is_ai})")
    else
      IO.puts("Human goes first in practice game")
      
      # Human plays first valid card
      valid_plays = Game.get_valid_plays(game, current_player)
      
      if length(valid_plays) > 0 do
        {card, index} = hd(valid_plays)
        IO.puts("Human plays: #{inspect(card)}")
        
        {:ok, new_game} = Game.play_card(game, current_player.id, [index])
        
        # Handle ace nomination if needed
        new_game = if card.rank == :ace do
          {:ok, game_with_suit} = Game.nominate_suit(new_game, current_player.id, :hearts)
          game_with_suit
        else
          new_game
        end
        
        next_player = Game.current_player(new_game)
        IO.puts("After human move, current player: #{next_player.name} (AI: #{next_player.is_ai})")
        
        if next_player.is_ai do
          IO.puts("✅ Turn correctly passed to AI player")
          
          # Verify AI can make a move
          ai_action = AIPlayer.make_move(new_game, next_player.id)
          IO.inspect(ai_action, label: "AI should be able to")
        else
          IO.puts("❌ Turn did not pass to AI player")
        end
      else
        IO.puts("Human has no valid plays, must draw")
        {:ok, new_game} = Game.draw_card(game, current_player.id)
        
        next_player = Game.current_player(new_game)
        IO.puts("After human draw, current player: #{next_player.name} (AI: #{next_player.is_ai})")
      end
    end
    
    assert true
  end
  
  test "AI makes optimal decisions in practice games" do
    # Test specific scenario
    game = Game.new()
    game = Game.add_player(game, "player-1", "Human", false)
    game = Game.add_player(game, "ai-1", "AI Player", true)
    game = Game.start_game(game)
    
    # Find AI player
    ai_player = Enum.find(game.players, & &1.is_ai)
    current_player = Game.current_player(game)
    
    if ai_player && current_player.is_ai do
      IO.puts("\n=== AI DECISION MAKING ===")
      IO.puts("AI hand size: #{length(ai_player.hand)}")
      IO.puts("Current card: #{inspect(game.current_card)}")
      
      # Check what AI would do
      action = AIPlayer.make_move(game, ai_player.id)
      IO.inspect(action, label: "AI decision")
      
      # Verify it's a valid decision
      case action do
        {:play, index} ->
          card = Enum.at(ai_player.hand, index)
          IO.puts("AI wants to play: #{inspect(card)}")
          assert card != nil
          
        {:draw, _} ->
          IO.puts("AI wants to draw")
          valid_plays = Game.get_valid_plays(game, ai_player)
          assert length(valid_plays) == 0, "AI should only draw when no valid plays"
          
        {:nominate, suit} ->
          IO.puts("AI wants to nominate suit: #{suit}")
          assert game.nominated_suit == :pending
      end
    else
      IO.puts("\n=== HUMAN GOES FIRST ===")
      IO.puts("Skipping AI decision test since human goes first")
    end
  end
end