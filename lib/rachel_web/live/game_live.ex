defmodule RachelWeb.GameLive do
  use RachelWeb, :live_view

  alias Rachel.Games.{AIPlayer, Card, Game}
  alias RachelWeb.GameLive.Modern

  @impl true
  def mount(_params, _session, socket) do
    game = create_test_game()

    socket =
      socket
      |> assign(:game, game)
      |> assign(:player_id, "human")
      |> assign(:selected_cards, [])
      |> assign(:show_ai_thinking, false)
      |> assign(:show_winner_banner, false)
      |> assign(:winner_acknowledged, false)

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
              case Game.play_card(socket.assigns.game, current_player.id, [index]) do
                {:ok, new_game} ->
                  socket =
                    socket
                    |> assign(:game, new_game)
                    |> assign(:selected_cards, [])
                    |> check_and_show_winner_banner(new_game)

                  schedule_ai_move(new_game)
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
      case Game.play_card(
             socket.assigns.game,
             current_player.id,
             socket.assigns.selected_cards
           ) do
        {:ok, new_game} ->
          socket =
            socket
            |> assign(:game, new_game)
            |> assign(:selected_cards, [])
            |> check_and_show_winner_banner(new_game)

          schedule_ai_move(new_game)
          socket = check_auto_draw(socket)
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
      case Game.draw_card(socket.assigns.game, current_player.id) do
        {:ok, new_game} ->
          socket =
            socket
            |> assign(:game, new_game)
            |> assign(:selected_cards, [])
            |> clear_flash()
            |> put_flash(:info, "Card drawn!")

          schedule_ai_move(new_game)
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

      case Game.nominate_suit(socket.assigns.game, current_player.id, suit_atom) do
        {:ok, new_game} ->
          socket =
            socket
            |> assign(:game, new_game)
            |> clear_flash()
            |> put_flash(:info, "Suit nominated: #{suit}")

          schedule_ai_move(new_game)
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
  def handle_info(:ai_move, socket) do
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

  def handle_info(:auto_hide_winner_banner, socket) do
    {:noreply, assign(socket, :show_winner_banner, false)}
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

      case Game.draw_card(game, current_player.id) do
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

          schedule_ai_move(new_game)
          {:noreply, socket}

        {:error, _} ->
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
    Modern.render(assigns)
  end

  defp create_test_game do
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
    |> Game.add_player("human", "You", false)
    |> Game.add_player("ai1", Enum.at(selected_names, 0), true)
    |> Game.add_player("ai2", Enum.at(selected_names, 1), true)
    |> Game.add_player("ai3", Enum.at(selected_names, 2), true)
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

  defp schedule_ai_move(%Game{} = game) do
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
  defp format_error(error), do: "Error: #{inspect(error)}"

  defp count_other_cards_with_rank(hand, clicked_card, clicked_index, selected_indices) do
    hand
    |> Enum.with_index()
    |> Enum.count(fn {card, idx} ->
      idx != clicked_index && idx not in selected_indices && card.rank == clicked_card.rank
    end)
  end

  defp check_and_show_winner_banner(socket, game) do
    player_id = socket.assigns.player_id

    # Check if the current player just won and hasn't acknowledged it yet
    if player_id in game.winners && !socket.assigns.winner_acknowledged do
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
