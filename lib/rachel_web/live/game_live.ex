defmodule RachelWeb.GameLive do
  use RachelWeb, :live_view

  alias Rachel.Games.{AIPlayer, Card, Game, GameSave}
  import RachelWeb.GameComponents

  @impl true
  def mount(_params, _session, socket) do
    # Initialize save system
    GameSave.start_link()

    game = create_test_game()

    socket =
      socket
      |> assign(:game, game)
      |> assign(:player_id, "human")
      |> assign(:selected_cards, [])
      |> assign(:show_ai_thinking, false)
      |> assign(:show_save_modal, false)
      |> assign(:show_load_modal, false)
      |> assign(:saved_games, [])

    # Check if AI should start
    schedule_ai_move(game)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_card", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    current_player = current_player(socket.assigns.game)

    if current_player && current_player.id == socket.assigns.player_id do
      selected = socket.assigns.selected_cards

      # If clicking on a selected card, deselect it
      new_selected =
        if index in selected do
          List.delete(selected, index)
        else
          # Check if we can add this card
          if can_select_card?(
               socket.assigns.game,
               Enum.at(current_player.hand, index),
               selected,
               current_player.hand
             ) do
            # Check if this is the only card that could be stacked
            clicked_card = Enum.at(current_player.hand, index)
            stackable_cards = count_stackable_cards(current_player.hand, clicked_card, selected)

            # If this is the only instance of this rank (no stacking possible)
            # and no cards are selected yet, auto-play it
            if length(selected) == 0 && stackable_cards == 0 do
              # Auto-play immediately
              case Game.play_cards(socket.assigns.game, current_player.id, [index]) do
                {:ok, new_game} ->
                  socket =
                    socket
                    |> assign(:game, new_game)
                    |> assign(:selected_cards, [])
                    |> put_flash(:info, "Card played!")

                  schedule_ai_move(new_game)
                  {:noreply, socket}

                {:error, reason} ->
                  {:noreply, put_flash(socket, :error, format_error(reason))}
              end
            else
              # Add to selection for potential stacking
              [index | selected]
            end
          else
            selected
          end
        end

      {:noreply, assign(socket, :selected_cards, new_selected)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("play_cards", _, socket) do
    current_player = current_player(socket.assigns.game)

    if current_player &&
         current_player.id == socket.assigns.player_id &&
         length(socket.assigns.selected_cards) > 0 do
      case Game.play_cards(
             socket.assigns.game,
             current_player.id,
             socket.assigns.selected_cards
           ) do
        {:ok, new_game} ->
          socket =
            socket
            |> assign(:game, new_game)
            |> assign(:selected_cards, [])
            |> put_flash(:info, "Cards played!")

          schedule_ai_move(new_game)
          {:noreply, socket}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, format_error(reason))}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("draw_card", _, socket) do
    current_player = current_player(socket.assigns.game)

    if current_player && current_player.id == socket.assigns.player_id do
      case Game.draw_card(socket.assigns.game, current_player.id) do
        {:ok, new_game} ->
          socket =
            socket
            |> assign(:game, new_game)
            |> assign(:selected_cards, [])
            |> put_flash(:info, "Card drawn!")

          schedule_ai_move(new_game)
          {:noreply, socket}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, format_error(reason))}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("nominate_suit", %{"suit" => suit}, socket) do
    current_player = current_player(socket.assigns.game)

    if current_player && current_player.id == socket.assigns.player_id do
      suit_atom = String.to_existing_atom(suit)

      case Game.nominate_suit(socket.assigns.game, current_player.id, suit_atom) do
        {:ok, new_game} ->
          socket =
            socket
            |> assign(:game, new_game)
            |> put_flash(:info, "Suit nominated: #{suit}")

          schedule_ai_move(new_game)
          {:noreply, socket}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, format_error(reason))}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("show_save_modal", _, socket) do
    {:noreply, assign(socket, :show_save_modal, true)}
  end

  def handle_event("hide_save_modal", _, socket) do
    {:noreply, assign(socket, :show_save_modal, false)}
  end

  def handle_event("save_game", %{"save_name" => save_name}, socket) do
    case GameSave.save_game(socket.assigns.game, save_name) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:show_save_modal, false)
         |> put_flash(:info, "Game saved successfully!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save game")}
    end
  end

  def handle_event("show_load_modal", _, socket) do
    saved_games = GameSave.list_saved_games()

    {:noreply,
     socket
     |> assign(:show_load_modal, true)
     |> assign(:saved_games, saved_games)}
  end

  def handle_event("hide_load_modal", _, socket) do
    {:noreply, assign(socket, :show_load_modal, false)}
  end

  def handle_event("load_game", %{"save_name" => save_name}, socket) do
    case GameSave.load_game(save_name) do
      {:ok, game} ->
        socket =
          socket
          |> assign(:game, game)
          |> assign(:show_load_modal, false)
          |> assign(:selected_cards, [])
          |> put_flash(:info, "Game loaded successfully!")

        schedule_ai_move(game)
        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to load game")}
    end
  end

  def handle_event("delete_save", %{"save_name" => save_name}, socket) do
    case GameSave.delete_save(save_name) do
      :ok ->
        saved_games = GameSave.list_saved_games()

        {:noreply,
         socket
         |> assign(:saved_games, saved_games)
         |> put_flash(:info, "Save deleted")}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to delete save")}
    end
  end

  @impl true
  def handle_event("acknowledge_win", _, socket) do
    {:noreply, socket}
  end

  def handle_event("export_game", _params, socket) do
    case GameSave.export_game(socket.assigns.game) do
      {:ok, _json_data} ->
        # In a real app, you'd trigger a download. For now, just show success
        {:noreply, put_flash(socket, :info, "Game exported to JSON (check browser console)")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to export game")}
    end
  end

  @impl true
  def handle_info(:ai_move, socket) do
    game = socket.assigns.game
    current = Game.current_player(game)

    # Double-check it's still AI's turn
    if current && current.is_ai && game.status == :playing &&
         game.nominated_suit != :pending do
      socket = assign(socket, :show_ai_thinking, true)

      # Get AI's move
      case AIPlayer.make_move(game, current.id) do
        {:play, cards} ->
          case Game.play_cards(game, current.id, cards) do
            {:ok, new_game} ->
              socket =
                socket
                |> assign(:game, new_game)
                |> assign(:show_ai_thinking, false)

              schedule_ai_move(new_game)
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
    RachelWeb.GameLive.Modern.render(assigns)
  end

  defp create_test_game do
    Game.new()
    |> Game.add_player("human", "You", false)
    |> Game.add_player("ai1", "AI Player 1", true)
    |> Game.add_player("ai2", "AI Player 2", true)
    |> Game.add_player("ai3", "AI Player 3", true)
    |> Game.start_game()
  end

  def current_player(%Game{} = game) do
    Game.current_player(game)
  end

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

  defp render_card(%Card{} = card) do
    Card.display(card)
  end

  defp schedule_ai_move(%Game{} = game) do
    current = Game.current_player(game)

    if current && current.is_ai && game.status == :playing do
      Process.send_after(self(), :ai_move, 500)
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
  defp format_error(error), do: "Error: #{inspect(error)}"

  defp format_suit(:hearts), do: "♥ Hearts"
  defp format_suit(:diamonds), do: "♦ Diamonds"
  defp format_suit(:clubs), do: "♣ Clubs"
  defp format_suit(:spades), do: "♠ Spades"
  defp format_suit(_), do: "Unknown"

  defp count_stackable_cards(hand, clicked_card, selected_indices) do
    hand
    |> Enum.with_index()
    |> Enum.count(fn {card, idx} ->
      idx not in selected_indices && card.rank == clicked_card.rank
    end)
  end

  defp render_stats(%Game{} = game) do
    case Game.get_game_stats(game) do
      nil ->
        assigns = %{}
        ~H"<p>Statistics tracking not available</p>"

      stats ->
        assigns = %{stats: stats}

        ~H"""
        <div class="space-y-4">
          <!-- Game Overview -->
          <div class="stats shadow">
            <div class="stat">
              <div class="stat-title">Total Turns</div>
              <div class="stat-value text-primary">{@stats.game.total_turns}</div>
            </div>
            <div class="stat">
              <div class="stat-title">Cards Played</div>
              <div class="stat-value text-secondary">{@stats.game.total_cards_played}</div>
            </div>
            <div class="stat">
              <div class="stat-title">Duration</div>
              <div class="stat-value text-accent">{@stats.game.duration_minutes}</div>
            </div>
          </div>
          
        <!-- Player Stats -->
          <h3 class="text-lg font-bold">Player Statistics</h3>
          <div class="overflow-x-auto">
            <table class="table table-zebra w-full">
              <thead>
                <tr>
                  <th>Player</th>
                  <th>Cards Played</th>
                  <th>Special Cards</th>
                  <th>Cards Drawn</th>
                  <th>Score</th>
                </tr>
              </thead>
              <tbody>
                <%= for player <- @stats.players do %>
                  <tr class={player.won && "font-bold text-success"}>
                    <td>{player.name}</td>
                    <td>{player.total_cards_played}</td>
                    <td>{player.special_cards_played}</td>
                    <td>{player.total_cards_drawn}</td>
                    <td>{player.score}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
        """
    end
  end

  defp format_date(datetime) do
    datetime
    |> DateTime.shift_zone!("Etc/UTC")
    |> Calendar.strftime("%b %d at %I:%M %p")
  end
end
