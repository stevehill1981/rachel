defmodule RachelWeb.Components.Game.DeckArea do
  @moduledoc """
  Deck and current card display area
  """
  use Phoenix.Component
  import RachelWeb.GameComponents
  alias Rachel.Games.Game

  attr :game, :map, required: true
  attr :player_id, :string, required: true
  attr :show_ai_thinking, :boolean, default: false
  attr :current_player, :any, required: true

  def deck_area(assigns) do
    # Provide safe defaults for missing data
    game = assigns[:game]

    assigns =
      assigns
      |> assign_new(:deck_size, fn ->
        case game do
          %{deck: deck} -> Rachel.Games.Deck.size(deck)
          _ -> 0
        end
      end)
      |> assign_new(:discard_pile_size, fn ->
        case game do
          %{discard_pile: pile} when is_list(pile) -> length(pile)
          _ -> 0
        end
      end)
      |> assign_new(:pending_pickups, fn ->
        case game do
          %{pending_pickups: pickups} -> pickups
          _ -> 0
        end
      end)
      |> assign_new(:pending_skips, fn ->
        case game do
          %{pending_skips: skips} -> skips
          _ -> 0
        end
      end)
      |> assign_new(:current_card, fn ->
        case game do
          %{current_card: card} -> card
          _ -> nil
        end
      end)
      |> assign_new(:can_draw, fn ->
        current_player = assigns[:current_player]
        player_id = assigns[:player_id]

        case {game, current_player} do
          {%Game{} = g, %{id: cp_id}} when cp_id == player_id ->
            !Game.has_valid_play?(g, current_player)

          _ ->
            false
        end
      end)

    ~H"""
    <div class="relative">
      <!-- AI Thinking Indicator -->
      <%= if @show_ai_thinking && @current_player && Map.get(@current_player, :is_ai) do %>
        <div class="absolute -top-12 left-1/2 -translate-x-1/2 z-20">
          <.ai_thinking_indicator />
        </div>
      <% end %>

      <div class="flex items-center justify-center gap-8 mb-8">
        <!-- Deck -->
        <div class="flex flex-col items-center">
          <div class="w-32 h-44">
            <.deck_display deck_size={@deck_size} can_draw={@can_draw} />
          </div>
        </div>
        
    <!-- Current Card -->
        <div class="flex flex-col items-center">
          <div class="w-32 h-44">
            <.current_card_display
              card={@current_card}
              discard_pile_size={@discard_pile_size}
              pending_pickups={@pending_pickups}
              pending_skips={@pending_skips}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end
end
