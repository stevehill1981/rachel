defmodule RachelWeb.GameLive do
  use RachelWeb, :live_view

  alias Rachel.Games.{AIPlayer, Card, Game, GameServer}
  alias RachelWeb.GameLive.Modern
  alias Phoenix.PubSub

  @impl true
  def mount(%{"game_id" => game_id}, session, socket) do
    # Generate or get player identity
    player_id = get_player_id(session)
    player_name = get_player_name(session)
    
    case handle_game_join(game_id, player_id, player_name) do
      {:ok, game} ->
        # Subscribe to game updates
        PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")
        
        # Notify GameServer that we're connected
        try do
          GameServer.player_connected(game_id, player_id, self())
        catch
          # Continue even if GameServer notification fails
          :exit, _ -> :ok
        end
        
        socket =
          socket
          |> assign(:game, game)
          |> assign(:game_id, game_id)
          |> assign(:player_id, player_id)
          |> assign(:player_name, player_name)
          |> assign(:selected_cards, [])
          |> assign(:show_ai_thinking, false)
          |> assign(:show_winner_banner, false)
          |> assign(:winner_acknowledged, false)
          |> assign(:connection_status, :connected)
          |> assign(:is_spectator, false)
        
        {:ok, socket}

      {:ok, game, :spectator} ->
        # Subscribe to game updates as spectator
        PubSub.subscribe(Rachel.PubSub, "game:#{game_id}")
        
        socket =
          socket
          |> assign(:game, game)
          |> assign(:game_id, game_id)
          |> assign(:player_id, player_id)
          |> assign(:player_name, player_name)
          |> assign(:selected_cards, [])
          |> assign(:show_ai_thinking, false)
          |> assign(:show_winner_banner, false)
          |> assign(:winner_acknowledged, false)
          |> assign(:connection_status, :connected)
          |> assign(:is_spectator, true)
          |> put_flash(:info, "Joined as spectator - watching the game!")
        
        {:ok, socket}
        
      {:error, reason} ->
        socket = 
          socket
          |> put_flash(:error, format_join_error(reason))
          |> push_navigate(to: "/lobby")
        
        {:ok, socket}
    end
  end
  
  # Fallback for single-player mode (no game_id)
  def mount(_params, session, socket) do
    # Get player identity for single-player mode
    player_name = get_player_name(session)
    game = create_test_game(player_name)
    
    socket =
      socket
      |> assign(:game, game)
      |> assign(:game_id, nil)
      |> assign(:player_id, "human")
      |> assign(:player_name, player_name)
      |> assign(:selected_cards, [])
      |> assign(:show_ai_thinking, false)
      |> assign(:show_winner_banner, false)
      |> assign(:winner_acknowledged, false)
      |> assign(:connection_status, :offline)
    
    # Check if AI should start
    schedule_ai_move(game)
    
    # Check if player needs to auto-draw
    socket = check_auto_draw(socket)
    
    {:ok, socket}
  end

  @impl true
  def handle_event("select_card", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    current_player = current_player(socket.assigns.game)

    if current_player && current_player.id == socket.assigns.player_id do
      selected = socket.assigns.selected_cards

      # If clicking on a selected card, deselect it
      if index in selected do
        {:noreply, assign(socket, :selected_cards, List.delete(selected, index))}
      else
        # Check if we can add this card
        clicked_card = Enum.at(current_player.hand, index)

        if clicked_card &&
             can_select_card?(socket.assigns.game, clicked_card, selected, current_player.hand) do
          # Check for auto-play condition
          if clicked_card && Enum.empty?(selected) do
            # Count other cards with same rank (excluding the clicked card)
            other_same_rank =
              count_other_cards_with_rank(current_player.hand, clicked_card, index, selected)

            if other_same_rank == 0 do
              # Auto-play immediately - this is the only card of its rank
              case play_cards_action(socket, [index]) do
                {:ok, new_game} ->
                  socket =
                    socket
                    |> assign(:game, new_game)
                    |> assign(:selected_cards, [])
                    |> check_and_show_winner_banner(new_game)

                  socket = check_auto_draw(socket)
                  {:noreply, socket}

                {:error, reason} ->
                  {:noreply, socket |> clear_flash() |> put_flash(:error, format_error(reason))}
              end
            else
              # Can stack with other cards - add to selection
              {:noreply, assign(socket, :selected_cards, selected ++ [index])}
            end
          else
            # Either cards are already selected or clicked_card is nil - add to selection
            {:noreply, assign(socket, :selected_cards, selected ++ [index])}
          end
        else
          # Can't select this card
          {:noreply, socket}
        end
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("play_cards", _, socket) do
    current_player = current_player(socket.assigns.game)

    if current_player &&
         current_player.id == socket.assigns.player_id &&
         length(socket.assigns.selected_cards) > 0 do
      case play_cards_action(socket, socket.assigns.selected_cards) do
        {:ok, new_game} ->
          socket =
            socket
            |> assign(:game, new_game)
            |> assign(:selected_cards, [])
            |> check_and_show_winner_banner(new_game)

          socket = check_auto_draw(socket)
          
          # Schedule AI move for single-player games
          if socket.assigns.game_id == nil do
            schedule_ai_move(new_game)
          end
          
          {:noreply, socket}

        {:error, reason} ->
          {:noreply, socket |> clear_flash() |> put_flash(:error, format_error(reason))}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("draw_card", _, socket) do
    current_player = current_player(socket.assigns.game)

    if current_player && current_player.id == socket.assigns.player_id do
      case draw_card_action(socket) do
        {:ok, new_game} ->
          socket =
            socket
            |> assign(:game, new_game)
            |> assign(:selected_cards, [])
            |> clear_flash()
            |> put_flash(:info, "Card drawn!")
          
          # Schedule AI move for single-player games
          if socket.assigns.game_id == nil do
            schedule_ai_move(new_game)
          end

          {:noreply, socket}

        {:error, reason} ->
          {:noreply, socket |> clear_flash() |> put_flash(:error, format_error(reason))}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("nominate_suit", %{"suit" => suit}, socket) do
    current_player = current_player(socket.assigns.game)

    if current_player && current_player.id == socket.assigns.player_id do
      suit_atom = String.to_existing_atom(suit)

      case nominate_suit_action(socket, suit_atom) do
        {:ok, new_game} ->
          socket =
            socket
            |> assign(:game, new_game)
            |> clear_flash()
            |> put_flash(:info, "Suit nominated: #{suit}")
          
          # Schedule AI move for single-player games
          if socket.assigns.game_id == nil do
            schedule_ai_move(new_game)
          end

          {:noreply, socket}

        {:error, reason} ->
          {:noreply, socket |> clear_flash() |> put_flash(:error, format_error(reason))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("acknowledge_win", _, socket) do
    {:noreply, assign(socket, :show_winner_banner, false)}
  end
  
  @impl true
  def handle_event("copy_game_code", _, socket) do
    if socket.assigns.game_id do
      game_code = String.slice(socket.assigns.game_id, -6..-1)
      {:noreply, put_flash(socket, :info, "Game code #{game_code} copied!")}
    else
      {:noreply, socket}
    end
  end
  
  @impl true
  def handle_event("start_game", _, socket) do
    if socket.assigns.game_id && socket.assigns.player_id do
      case GameServer.start_game(socket.assigns.game_id, socket.assigns.player_id) do
        {:ok, _game} ->
          {:noreply, put_flash(socket, :info, "Game started!")}
          
        {:error, :not_host} ->
          {:noreply, put_flash(socket, :error, "Only the host can start the game")}
          
        {:error, :not_enough_players} ->
          {:noreply, put_flash(socket, :error, "Need at least 2 players to start")}
          
        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to start game: #{inspect(reason)}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:ai_move, socket) do
    # Only handle AI moves for single-player games
    # Multiplayer AI moves are handled by GameServer
    if socket.assigns.game_id do
      {:noreply, socket}
    else
      game = socket.assigns.game
      current = Game.current_player(game)

      # Double-check it's still AI's turn
      if current && current.is_ai && game.status == :playing do
      socket = assign(socket, :show_ai_thinking, true)

      # Get AI's move
      case AIPlayer.make_move(game, current.id) do
        {:play, cards} ->
          case Game.play_card(game, current.id, cards) do
            {:ok, new_game} ->
              socket =
                socket
                |> assign(:game, new_game)
                |> assign(:show_ai_thinking, false)

              schedule_ai_move(new_game)
              socket = check_auto_draw(socket)
              {:noreply, socket}

            _ ->
              # If play fails, try drawing
              handle_ai_draw(socket, game, current.id)
          end

        {:nominate, suit} ->
          case Game.nominate_suit(game, current.id, suit) do
            {:ok, new_game} ->
              socket =
                socket
                |> assign(:game, new_game)
                |> assign(:show_ai_thinking, false)

              schedule_ai_move(new_game)
              socket = check_auto_draw(socket)
              {:noreply, socket}

            _ ->
              {:noreply, socket}
          end

        {:draw, _} ->
          handle_ai_draw(socket, game, current.id)

        _ ->
          {:noreply, socket}
      end
      else
        {:noreply, socket}
      end
    end
  end

  def handle_info(:auto_hide_winner_banner, socket) do
    {:noreply, assign(socket, :show_winner_banner, false)}
  end

  # PubSub event handlers for multiplayer games
  def handle_info({:game_updated, game}, socket) do
    socket = 
      socket
      |> assign(:game, game)
      |> assign(:selected_cards, [])
      |> check_and_show_winner_banner(game)
    
    {:noreply, socket}
  end
  
  def handle_info({:cards_played, %{player_id: player_id, cards: cards, game: game} = msg}, socket) do
    socket = 
      socket
      |> assign(:game, game)
      |> assign(:selected_cards, [])
      |> check_and_show_winner_banner(game)
      
    socket = if player_id != socket.assigns.player_id do
      # Use player_name from message if available, otherwise look it up
      player_name = Map.get(msg, :player_name) || get_player_name_by_id(game, player_id)
      card_count = length(cards)
      message = "#{player_name} played #{card_count} card#{if card_count == 1, do: "", else: "s"}"
      put_flash(socket, :info, message)
    else
      socket
    end
    
    {:noreply, socket}
  end
  
  def handle_info({:card_drawn, %{player_id: player_id, game: game}}, socket) do
    socket = assign(socket, :game, game)
    
    socket = if player_id != socket.assigns.player_id do
      player_name = get_player_name_by_id(game, player_id)
      put_flash(socket, :info, "#{player_name} drew a card")
    else
      socket
    end
    
    {:noreply, socket}
  end
  
  def handle_info({:suit_nominated, %{player_id: player_id, suit: suit, game: game}}, socket) do
    socket = assign(socket, :game, game)
    
    socket = if player_id != socket.assigns.player_id do
      player_name = get_player_name_by_id(game, player_id)
      put_flash(socket, :info, "#{player_name} nominated suit: #{suit}")
    else
      socket
    end
    
    {:noreply, socket}
  end
  
  def handle_info({:player_won, %{player_id: _player_id, game: game}}, socket) do
    socket = 
      socket
      |> assign(:game, game)
      |> check_and_show_winner_banner(game)
    
    {:noreply, socket}
  end
  
  def handle_info({:game_started, game}, socket) do
    socket = assign(socket, :game, game)
    {:noreply, socket}
  end
  
  def handle_info({:player_reconnected, %{player_id: player_id, player_name: player_name}}, socket) do
    socket = if player_id != socket.assigns.player_id do
      put_flash(socket, :info, "#{player_name} reconnected")
    else
      socket
    end
    
    {:noreply, socket}
  end
  
  def handle_info({:player_disconnected, %{player_id: player_id, player_name: player_name}}, socket) do
    socket = if player_id != socket.assigns.player_id do
      put_flash(socket, :info, "#{player_name} disconnected")
    else
      socket
    end
    
    {:noreply, socket}
  end

  def handle_info(:auto_draw_pending_cards, socket) do
    game = socket.assigns.game
    current_player = current_player(game)

    # Double-check conditions are still met
    if current_player &&
         current_player.id == socket.assigns.player_id &&
         game.pending_pickups > 0 &&
         !Game.has_valid_play?(game, current_player) &&
         game.status == :playing do
      pickup_count = game.pending_pickups
      pickup_type = game.pending_pickup_type

      case draw_card_action(socket) do
        {:ok, new_game} ->
          message =
            if pickup_type == :black_jacks do
              "Drew #{pickup_count} cards from Black Jacks!"
            else
              "Drew #{pickup_count} cards from 2s!"
            end

          socket =
            socket
            |> assign(:game, new_game)
            |> assign(:selected_cards, [])
            |> clear_flash()
            |> put_flash(:info, message)

          {:noreply, socket}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Catch-all handler for unmatched messages (including error tuples)
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp handle_ai_draw(socket, game, ai_id) do
    case AIPlayer.make_move(game, ai_id) do
      {:draw, _} ->
        case Game.draw_card(game, ai_id) do
          {:ok, new_game} ->
            socket =
              socket
              |> assign(:game, new_game)
              |> assign(:show_ai_thinking, false)

            schedule_ai_move(new_game)
            {:noreply, socket}

          _ ->
            {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    Modern.render(assigns)
  end
  
  @impl true
  def terminate(_reason, socket) do
    # Notify GameServer that we're disconnecting (only for multiplayer)
    if socket.assigns[:game_id] && socket.assigns[:player_id] do
      try do
        GameServer.player_disconnected(socket.assigns.game_id, socket.assigns.player_id)
      catch
        # Ignore errors during termination - GameServer might already be dead
        :exit, _ -> :ok
      end
    end
    :ok
  end

  defp create_test_game(player_name \\ "You") do
    ai_names = [
      "Alice",
      "Bob",
      "Charlie",
      "Diana",
      "Eve",
      "Frank",
      "Grace",
      "Henry",
      "Ivy",
      "Jack",
      "Kate",
      "Liam",
      "Maya",
      "Noah",
      "Olivia",
      "Paul",
      "Quinn",
      "Ruby",
      "Sam",
      "Tara"
    ]

    selected_names = Enum.take_random(ai_names, 3)

    Game.new()
    |> Game.add_player("human", player_name, false)
    |> Game.add_player("ai1", Enum.at(selected_names, 0), true)
    |> Game.add_player("ai2", Enum.at(selected_names, 1), true)
    |> Game.add_player("ai3", Enum.at(selected_names, 2), true)
    |> Game.start_game()
  end
  
  # Player identity and session management
  defp get_player_id(session) do
    Map.get(session, "player_id", "player_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}")
  end
  
  defp get_player_name(session) do
    Map.get(session, "player_name", "Anonymous")
  end
  
  # Game joining logic
  defp handle_game_join(game_id, player_id, player_name) do
    try do
      case GameServer.get_state(game_id) do
        game when is_map(game) ->
          # Game exists - try to join or reconnect
          if player_in_game?(game, player_id) do
            # Player is already in game - reconnect
            case GameServer.reconnect_player(game_id, player_id) do
              :ok -> 
                # Reconnection successful, get updated game state
                updated_game = GameServer.get_state(game_id)
                {:ok, updated_game}
              {:error, reason} -> {:error, reason}
            end
          else
            # Try to join the game
            case GameServer.join_game(game_id, player_id, player_name) do
              {:ok, updated_game} -> {:ok, updated_game}
              {:error, :game_started} -> 
                # Game already started, try to join as spectator
                case GameServer.join_as_spectator(game_id, player_id, player_name) do
                  {:ok, updated_game} -> {:ok, updated_game, :spectator}
                  {:error, reason} -> {:error, reason}
                end
              {:error, reason} -> {:error, reason}
            end
          end
          
        _ ->
          {:error, :game_not_found}
      end
    catch
      :exit, _ ->
        {:error, :game_not_found}
    end
  end
  
  defp player_in_game?(game, player_id) do
    Enum.any?(game.players, &(&1.id == player_id))
  end
  
  # Action helpers - determine if multiplayer or single-player
  defp play_cards_action(socket, card_indices) do
    if socket.assigns.game_id do
      # Multiplayer - use GameServer (convert indices to cards)
      current_player = current_player(socket.assigns.game)
      if current_player do
        cards = card_indices
          |> Enum.map(fn index -> Enum.at(current_player.hand, index) end)
          |> Enum.reject(&is_nil/1)
        
        try do
          case GameServer.play_cards(socket.assigns.game_id, socket.assigns.player_id, cards) do
            {:ok, game} -> {:ok, game}
            {:error, reason} -> {:error, reason}
          end
        catch
          :exit, {:noproc, _} -> {:error, :game_not_found}
          :exit, {:timeout, _} -> {:error, :timeout}
          :exit, reason -> {:error, {:server_error, reason}}
        end
      else
        {:error, :player_not_found}
      end
    else
      # Single-player - use Game module directly
      Game.play_card(socket.assigns.game, socket.assigns.player_id, card_indices)
    end
  end
  
  defp draw_card_action(socket) do
    if socket.assigns.game_id do
      # Multiplayer - use GameServer
      try do
        case GameServer.draw_card(socket.assigns.game_id, socket.assigns.player_id) do
          {:ok, game} -> {:ok, game}
          {:error, reason} -> {:error, reason}
        end
      catch
        :exit, {:noproc, _} -> {:error, :game_not_found}
        :exit, {:timeout, _} -> {:error, :timeout}
        :exit, reason -> {:error, {:server_error, reason}}
      end
    else
      # Single-player - use Game module directly
      Game.draw_card(socket.assigns.game, socket.assigns.player_id)
    end
  end
  
  defp nominate_suit_action(socket, suit) do
    if socket.assigns.game_id do
      # Multiplayer - use GameServer
      try do
        case GameServer.nominate_suit(socket.assigns.game_id, socket.assigns.player_id, suit) do
          {:ok, game} -> {:ok, game}
          {:error, reason} -> {:error, reason}
        end
      catch
        :exit, {:noproc, _} -> {:error, :game_not_found}
        :exit, {:timeout, _} -> {:error, :timeout}
        :exit, reason -> {:error, {:server_error, reason}}
      end
    else
      # Single-player - use Game module directly
      Game.nominate_suit(socket.assigns.game, socket.assigns.player_id, suit)
    end
  end
  
  # Helper to get player name by ID
  defp get_player_name_by_id(game, player_id) do
    case Enum.find(game.players, &(&1.id == player_id)) do
      %{name: name} -> name
      _ -> "Unknown"
    end
  end
  
  # Error formatting
  defp format_join_error(:game_not_found), do: "Game not found"
  defp format_join_error(:game_started), do: "Game has already started"
  defp format_join_error(:game_full), do: "Game is full"
  defp format_join_error(:already_joined), do: "You're already in this game"
  defp format_join_error(:game_not_started), do: "Cannot spectate a game that hasn't started yet"
  defp format_join_error(:already_spectating), do: "You're already spectating this game"
  defp format_join_error(:already_playing), do: "You're already playing in this game"
  defp format_join_error(error), do: "Error joining game: #{inspect(error)}"

  def current_player(%Game{} = game) do
    Game.current_player(game)
  end
  
  def current_player(_), do: nil

  def current_player_name(%Game{} = game) do
    case Game.current_player(game) do
      nil -> "None"
      player -> player.name
    end
  end

  def can_select_card?(%Game{} = game, %Card{} = card, selected_indices, hand) do
    # Can always select if nothing selected yet
    if Enum.empty?(selected_indices) do
      # Check if it's a valid play
      current = Game.current_player(game)
      valid_plays = Game.get_valid_plays(game, current)

      Enum.any?(valid_plays, fn {valid_card, _} ->
        valid_card.suit == card.suit && valid_card.rank == card.rank
      end)
    else
      # If cards are already selected, can only select cards with same rank
      first_selected_index = hd(selected_indices)
      first_card = Enum.at(hand, first_selected_index)

      if first_card do
        card.rank == first_card.rank
      else
        false
      end
    end
  end

  defp schedule_ai_move(%Game{} = game) do
    # Only schedule AI moves for single-player games
    # Multiplayer AI moves are handled by GameServer
    current = Game.current_player(game)

    if current && current.is_ai && game.status == :playing do
      Process.send_after(self(), :ai_move, 1500)
    end
  end

  defp format_error(:not_your_turn), do: "It's not your turn!"
  defp format_error(:must_play_valid_card), do: "You must play a valid card!"
  defp format_error(:invalid_play), do: "Invalid play!"
  defp format_error(:first_card_invalid), do: "The first card doesn't match the current card!"
  defp format_error(:must_play_pickup_card), do: "You must play a 2 or black jack!"
  defp format_error(:must_play_twos), do: "You must play 2s to continue the stack!"
  defp format_error(:must_play_jacks), do: "You must play Jacks to counter black jacks!"
  defp format_error(:must_play_nominated_suit), do: "You must play the nominated suit!"
  defp format_error(:can_only_stack_same_rank), do: "You can only stack cards of the same rank!"
  defp format_error(:game_not_found), do: "Game connection lost. Please return to lobby."
  defp format_error(:timeout), do: "Game server is not responding. Please try again."
  defp format_error(:player_not_found), do: "Player not found in game."
  defp format_error(:cards_not_in_hand), do: "Selected cards are not in your hand."
  defp format_error(:no_ace_played), do: "No ace was played, suit nomination not needed."
  defp format_error(:not_host), do: "Only the host can start the game."
  defp format_error({:server_error, _reason}), do: "Server error occurred. Please try again."
  defp format_error(error), do: "Error: #{inspect(error)}"

  defp count_other_cards_with_rank(hand, clicked_card, clicked_index, selected_indices) do
    hand
    |> Enum.with_index()
    |> Enum.count(fn {card, idx} ->
      idx != clicked_index && idx not in selected_indices && card.rank == clicked_card.rank
    end)
  end

  defp check_and_show_winner_banner(socket, nil), do: socket
  
  defp check_and_show_winner_banner(socket, game) do
    player_id = socket.assigns.player_id
    winners = Map.get(game, :winners, [])

    # Check if the current player just won and hasn't acknowledged it yet
    if player_id in winners && !socket.assigns.winner_acknowledged do
      # Auto-hide the banner after 5 seconds
      Process.send_after(self(), :auto_hide_winner_banner, 5000)

      socket
      |> assign(:show_winner_banner, true)
      |> assign(:winner_acknowledged, true)
    else
      socket
    end
  end

  defp check_auto_draw(socket) do
    game = socket.assigns.game
    current_player = current_player(game)

    # Check if it's the human player's turn with pending pickups and no valid plays
    if current_player &&
         current_player.id == socket.assigns.player_id &&
         game.pending_pickups > 0 &&
         !Game.has_valid_play?(game, current_player) &&
         game.status == :playing do
      # Schedule auto-draw after a delay
      Process.send_after(self(), :auto_draw_pending_cards, 2000)
      socket
    else
      socket
    end
  end
end
