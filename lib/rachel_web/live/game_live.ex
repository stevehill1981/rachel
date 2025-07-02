defmodule RachelWeb.GameLive do
  use RachelWeb, :live_view

  alias Rachel.Games.{Game, Card, AIPlayer, GameSave}

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
      |> assign(:saved_games, GameSave.list_saved_games())
      |> assign(:show_save_modal, false)
      |> assign(:show_load_modal, false)

    # Schedule AI moves if it's their turn
    schedule_ai_move(game)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_card", %{"index" => index}, socket) do
    index = String.to_integer(index)
    selected = socket.assigns.selected_cards
    current_player = Game.current_player(socket.assigns.game)

    selected =
      if index in selected do
        Enum.reject(selected, &(&1 == index))
      else
        selected ++ [index]
      end

    # Check if we should auto-play
    if length(selected) == 1 do
      clicked_card = Enum.at(current_player.hand, index)
      stackable_cards = count_stackable_cards(current_player.hand, clicked_card, selected)

      if stackable_cards == 0 do
        # Auto-play immediately
        case Game.play_card(socket.assigns.game, socket.assigns.player_id, selected) do
          {:ok, new_game} ->
            socket =
              socket
              |> assign(:game, new_game)
              |> assign(:selected_cards, [])

            schedule_ai_move(new_game)
            {:noreply, socket}

          {:error, reason} ->
            {:noreply,
             assign(socket, :selected_cards, []) |> put_flash(:error, format_error(reason))}
        end
      else
        {:noreply, assign(socket, :selected_cards, selected)}
      end
    else
      {:noreply, assign(socket, :selected_cards, selected)}
    end
  end

  @impl true
  def handle_event("play_cards", _params, socket) do
    %{game: game, player_id: player_id, selected_cards: selected} = socket.assigns

    # Don't allow winners to play cards
    if player_id in game.winners do
      {:noreply,
       put_flash(socket, :error, "You've already won! Watch the other players continue.")}
    else
      case Game.play_card(game, player_id, selected) do
        {:ok, new_game} ->
          socket =
            socket
            |> assign(:game, new_game)
            |> assign(:selected_cards, [])

          # Check if current player just won
          socket =
            if player_id in new_game.winners and player_id not in game.winners do
              put_flash(socket, :info, "🎉 Congratulations! You won the game! 🎉")
            else
              socket
            end

          schedule_ai_move(new_game)
          {:noreply, socket}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, format_error(reason))}
      end
    end
  end

  @impl true
  def handle_event("nominate_suit", %{"suit" => suit}, socket) do
    %{game: game, player_id: player_id} = socket.assigns
    suit_atom = String.to_existing_atom(suit)

    case Game.nominate_suit(game, player_id, suit_atom) do
      {:ok, new_game} ->
        socket = assign(socket, :game, new_game)
        schedule_ai_move(new_game)
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  @impl true
  def handle_event("draw_card", _params, socket) do
    %{game: game, player_id: player_id} = socket.assigns

    # Don't allow winners to draw cards
    if player_id in game.winners do
      {:noreply,
       put_flash(socket, :error, "You've already won! Watch the other players continue.")}
    else
      case Game.draw_card(game, player_id) do
        {:ok, new_game} ->
          socket = assign(socket, :game, new_game)
          schedule_ai_move(new_game)
          {:noreply, socket}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, format_error(reason))}
      end
    end
  end

  @impl true
  def handle_event("show_save_modal", _params, socket) do
    {:noreply, assign(socket, :show_save_modal, true)}
  end

  @impl true
  def handle_event("hide_save_modal", _params, socket) do
    {:noreply, assign(socket, :show_save_modal, false)}
  end

  @impl true
  def handle_event("save_game", %{"save_name" => save_name}, socket) do
    case GameSave.save_game(socket.assigns.game, save_name) do
      {:ok, saved_name} ->
        socket =
          socket
          |> assign(:show_save_modal, false)
          |> assign(:saved_games, GameSave.list_saved_games())
          |> put_flash(:info, "Game saved as: #{saved_name}")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to save game: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("show_load_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_load_modal, true)
      |> assign(:saved_games, GameSave.list_saved_games())

    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_load_modal", _params, socket) do
    {:noreply, assign(socket, :show_load_modal, false)}
  end

  @impl true
  def handle_event("load_game", %{"save_name" => save_name}, socket) do
    case GameSave.load_game(save_name) do
      {:ok, game} ->
        socket =
          socket
          |> assign(:game, game)
          |> assign(:show_load_modal, false)
          |> assign(:selected_cards, [])
          |> put_flash(:info, "Game loaded: #{save_name}")

        schedule_ai_move(game)
        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Save file not found")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to load game: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("delete_save", %{"save_name" => save_name}, socket) do
    case GameSave.delete_save(save_name) do
      :ok ->
        socket =
          socket
          |> assign(:saved_games, GameSave.list_saved_games())
          |> put_flash(:info, "Save deleted: #{save_name}")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete save: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("export_game", _params, socket) do
    case GameSave.export_game(socket.assigns.game) do
      {:ok, _json_data} ->
        # In a real app, you'd trigger a download. For now, just show success
        {:noreply, put_flash(socket, :info, "Game exported to JSON (check browser console)")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to export game: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info(:ai_move, socket) do
    %{game: game} = socket.assigns
    current = Game.current_player(game)

    if current && current.is_ai && game.status == :playing do
      _socket = assign(socket, :show_ai_thinking, true)
      Process.send_after(self(), {:execute_ai_move, current.id}, 1000)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:execute_ai_move, ai_id}, socket) do
    %{game: game} = socket.assigns

    # Check if AI needs to nominate suit
    if game.nominated_suit == :pending && Game.current_player(game).id == ai_id do
      # AI picks a random suit
      suit = Enum.random([:hearts, :diamonds, :clubs, :spades])

      case Game.nominate_suit(game, ai_id, suit) do
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
    else
      case AIPlayer.make_move(game, ai_id) do
        {:play, indices} when is_list(indices) ->
          case Game.play_card(game, ai_id, indices) do
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

        {:play, index} ->
          case Game.play_card(game, ai_id, index) do
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
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 p-4">
      <div class="max-w-7xl mx-auto">
        <div class="flex justify-between items-center mb-8">
          <h1 class="text-4xl font-bold">Rachel Card Game</h1>
          
    <!-- Save/Load Controls -->
          <div class="flex gap-2">
            <button phx-click="show_save_modal" class="btn btn-primary btn-sm">
              💾 Save Game
            </button>
            <button phx-click="show_load_modal" class="btn btn-secondary btn-sm">
              📁 Load Game
            </button>
            <button phx-click="export_game" class="btn btn-accent btn-sm">
              📤 Export
            </button>
          </div>
        </div>
        
    <!-- Flash Messages -->
        <%= if Phoenix.Flash.get(@flash, :info) do %>
          <div class="alert alert-success mb-4">
            {Phoenix.Flash.get(@flash, :info)}
          </div>
        <% end %>
        <%= if Phoenix.Flash.get(@flash, :error) do %>
          <div class="alert alert-error mb-4">
            {Phoenix.Flash.get(@flash, :error)}
          </div>
        <% end %>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
          <!-- Game Status -->
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Game Status</h2>
              <div class="space-y-2">
                <p>Current Player: <span class="font-bold">{current_player_name(@game)}</span></p>
                <p>Direction: {@game.direction}</p>
                <p>Deck Size: {Rachel.Games.Deck.size(@game.deck)}</p>
                <%= if @game.pending_pickups > 0 do %>
                  <p class="text-error">Pending Pickups: {@game.pending_pickups}</p>
                <% end %>
                <%= if @game.nominated_suit && @game.nominated_suit != :pending do %>
                  <p class="text-info">Nominated Suit: {format_suit(@game.nominated_suit)}</p>
                <% end %>
              </div>
            </div>
          </div>
          
    <!-- Current Card -->
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body items-center">
              <h2 class="card-title">Current Card</h2>
              <%= if @game.current_card do %>
                <div class="text-6xl">
                  {render_card(@game.current_card)}
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Players -->
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Players</h2>
              <div class="space-y-2">
                <%= for {player, idx} <- Enum.with_index(@game.players) do %>
                  <div class={[
                    "flex justify-between p-2 rounded",
                    idx == @game.current_player_index && "bg-primary text-primary-content"
                  ]}>
                    <span>{player.name}</span>
                    <span class="badge">{length(player.hand)} cards</span>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
        
    <!-- AI Thinking Indicator -->
        <%= if @show_ai_thinking do %>
          <div class="alert alert-info mt-4">
            <span class="loading loading-spinner"></span> AI is thinking...
          </div>
        <% end %>
        
    <!-- Suit Nomination -->
        <%= if @game.nominated_suit == :pending && current_player(@game) && current_player(@game).id == @player_id do %>
          <div class="card bg-base-100 shadow-xl mt-8">
            <div class="card-body">
              <h2 class="card-title">Choose a suit for the next player:</h2>
              <div class="flex gap-4 justify-center">
                <button
                  phx-click="nominate_suit"
                  phx-value-suit="hearts"
                  class="btn btn-lg text-red-500"
                >
                  ♥ Hearts
                </button>
                <button
                  phx-click="nominate_suit"
                  phx-value-suit="diamonds"
                  class="btn btn-lg text-red-500"
                >
                  ♦ Diamonds
                </button>
                <button phx-click="nominate_suit" phx-value-suit="clubs" class="btn btn-lg">
                  ♣ Clubs
                </button>
                <button phx-click="nominate_suit" phx-value-suit="spades" class="btn btn-lg">
                  ♠ Spades
                </button>
              </div>
            </div>
          </div>
        <% end %>
        
    <!-- Winner Status -->
        <%= if @player_id in @game.winners do %>
          <div class="card bg-success text-success-content shadow-xl mt-8">
            <div class="card-body text-center">
              <h2 class="card-title">🎉 Congratulations! You Won! 🎉</h2>
              <p>You can watch the remaining players continue the game.</p>
            </div>
          </div>
        <% end %>
        
    <!-- Human Player Hand -->
        <%= if current_player(@game) && current_player(@game).id == @player_id && @player_id not in @game.winners do %>
          <div class="card bg-base-100 shadow-xl mt-8">
            <div class="card-body">
              <h2 class="card-title">Your Hand</h2>
              <div class="flex flex-wrap gap-2">
                <%= for {card, idx} <- Enum.with_index(current_player(@game).hand) do %>
                  <button
                    phx-click="select_card"
                    phx-value-index={idx}
                    class={[
                      "btn btn-lg text-2xl",
                      idx in @selected_cards && "btn-primary",
                      !can_select_card?(@game, card, @selected_cards, current_player(@game).hand) &&
                        "btn-disabled"
                    ]}
                    disabled={
                      !can_select_card?(@game, card, @selected_cards, current_player(@game).hand)
                    }
                  >
                    {render_card(card)}
                  </button>
                <% end %>
              </div>

              <div class="card-actions justify-end mt-4">
                <%= if length(@selected_cards) > 0 do %>
                  <button phx-click="play_cards" class="btn btn-primary">
                    Play Selected Cards
                  </button>
                <% end %>

                <%= if !Game.has_valid_play?(@game, current_player(@game)) do %>
                  <button phx-click="draw_card" class="btn btn-secondary">
                    Draw {max(1, @game.pending_pickups)} Card(s)
                  </button>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
        
    <!-- Winners -->
        <%= if length(@game.winners) > 0 do %>
          <div class="alert alert-success mt-4">
            <h3 class="font-bold">Winners:</h3>
            {Enum.join(@game.winners, ", ")}
          </div>
        <% end %>
        
    <!-- Game Statistics -->
        <%= if @game.stats do %>
          <div class="card bg-base-100 shadow-xl mt-8">
            <div class="card-body">
              <h2 class="card-title">Game Statistics</h2>
              {render_stats(@game)}
            </div>
          </div>
        <% end %>
        
    <!-- Save Game Modal -->
        <%= if @show_save_modal do %>
          <div class="modal modal-open">
            <div class="modal-box">
              <h3 class="font-bold text-lg mb-4">Save Game</h3>
              <form phx-submit="save_game">
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Save Name</span>
                  </label>
                  <input
                    type="text"
                    name="save_name"
                    placeholder="Enter save name..."
                    class="input input-bordered"
                    required
                  />
                </div>
                <div class="modal-action">
                  <button type="submit" class="btn btn-primary">Save</button>
                  <button type="button" phx-click="hide_save_modal" class="btn">Cancel</button>
                </div>
              </form>
            </div>
          </div>
        <% end %>
        
    <!-- Load Game Modal -->
        <%= if @show_load_modal do %>
          <div class="modal modal-open">
            <div class="modal-box max-w-2xl">
              <h3 class="font-bold text-lg mb-4">Load Game</h3>

              <%= if Enum.empty?(@saved_games) do %>
                <p class="text-gray-500">No saved games found.</p>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="table table-zebra w-full">
                    <thead>
                      <tr>
                        <th>Name</th>
                        <th>Players</th>
                        <th>Status</th>
                        <th>Saved</th>
                        <th>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for save <- @saved_games do %>
                        <tr>
                          <td class="font-mono text-sm">{save.name}</td>
                          <td>{save.players}</td>
                          <td>
                            <span class={[
                              "badge",
                              save.status == :playing && "badge-info",
                              save.status == :finished && "badge-success"
                            ]}>
                              {save.status}
                            </span>
                          </td>
                          <td class="text-sm">{format_date(save.saved_at)}</td>
                          <td>
                            <div class="flex gap-1">
                              <button
                                phx-click="load_game"
                                phx-value-save_name={save.name}
                                class="btn btn-xs btn-primary"
                              >
                                Load
                              </button>
                              <button
                                phx-click="delete_save"
                                phx-value-save_name={save.name}
                                class="btn btn-xs btn-error"
                                onclick="return confirm('Delete this save?')"
                              >
                                Delete
                              </button>
                            </div>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>

              <div class="modal-action">
                <button phx-click="hide_load_modal" class="btn">Close</button>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp create_test_game do
    Game.new()
    |> Game.add_player("human", "You", false)
    |> Game.add_player("ai1", "AI Player 1", true)
    |> Game.add_player("ai2", "AI Player 2", true)
    |> Game.add_player("ai3", "AI Player 3", true)
    |> Game.start_game()
  end

  defp current_player(%Game{} = game) do
    Game.current_player(game)
  end

  defp current_player_name(%Game{} = game) do
    case Game.current_player(game) do
      nil -> "None"
      player -> player.name
    end
  end

  defp can_select_card?(%Game{} = game, %Card{} = card, selected_indices, hand) do
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
          
        <!-- Player Leaderboard -->
          <div class="overflow-x-auto">
            <table class="table table-zebra w-full">
              <thead>
                <tr>
                  <th>Rank</th>
                  <th>Player</th>
                  <th>Score</th>
                  <th>Cards Played</th>
                  <th>Cards Drawn</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                <%= for {player, index} <- Enum.with_index(@stats.players) do %>
                  <tr class={index == 0 && "bg-success text-success-content"}>
                    <td class="font-bold">
                      <%= if index == 0 do %>
                        🏆 1st
                      <% else %>
                        {index + 1}
                      <% end %>
                    </td>
                    <td>
                      {get_player_name(player.id)}
                      <%= if player.won do %>
                        <span class="badge badge-success">Winner</span>
                      <% end %>
                    </td>
                    <td class="font-mono">{player.score}</td>
                    <td>{player.cards_played}</td>
                    <td>{player.cards_drawn}</td>
                    <td>
                      <%= if player.won do %>
                        <span class="text-success">Completed</span>
                      <% else %>
                        <span class="text-info">Playing</span>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
        """
    end
  end

  defp get_player_name("human"), do: "You"
  defp get_player_name("ai1"), do: "AI Player 1"
  defp get_player_name("ai2"), do: "AI Player 2"
  defp get_player_name("ai3"), do: "AI Player 3"
  defp get_player_name(id), do: id

  defp format_date(%DateTime{} = datetime) do
    datetime
    |> DateTime.shift_zone!("Etc/UTC")
    |> Calendar.strftime("%m/%d %H:%M")
  end
end
