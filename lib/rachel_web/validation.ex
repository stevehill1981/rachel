defmodule RachelWeb.Validation do
  @moduledoc """
  Comprehensive input validation utilities for the Rachel application.
  Provides sanitization and validation for user inputs to prevent security vulnerabilities.
  """

  @type validation_result :: {:ok, any()} | {:error, String.t()}

  alias RachelWeb.SecurityLogger

  # Maximum allowed lengths for various inputs
  @max_player_name_length 50
  @max_game_id_length 100
  @max_join_code_length 20

  # Allowed characters in different contexts
  @alphanumeric_regex ~r/^[a-zA-Z0-9_-]+$/
  @name_regex ~r/^[a-zA-Z0-9\s_-]+$/
  @game_id_regex ~r/^[a-zA-Z0-9_-]+$/

  @doc """
  Validates and sanitizes a player name.
  """
  @spec validate_player_name(String.t() | nil) :: validation_result()
  def validate_player_name(nil), do: {:error, "Player name cannot be empty"}
  def validate_player_name(""), do: {:error, "Player name cannot be empty"}

  def validate_player_name(name) when is_binary(name) do
    name = String.trim(name)

    cond do
      String.length(name) == 0 ->
        {:error, "Player name cannot be empty"}

      String.length(name) > @max_player_name_length ->
        {:error, "Player name too long (max #{@max_player_name_length} characters)"}

      not Regex.match?(@name_regex, name) ->
        {:error, "Player name contains invalid characters"}

      contains_profanity?(name) ->
        # Log potential inappropriate content for review
        SecurityLogger.log_validation_failure(:player_name, "unknown", %{
          error: "inappropriate_content",
          value: name
        })

        {:error, "Player name contains inappropriate content"}

      true ->
        {:ok, sanitize_string(name)}
    end
  end

  def validate_player_name(_), do: {:error, "Player name must be a string"}

  @doc """
  Validates a game ID format.
  """
  @spec validate_game_id(String.t() | nil) :: validation_result()
  def validate_game_id(nil), do: {:error, "Game ID cannot be empty"}
  def validate_game_id(""), do: {:error, "Game ID cannot be empty"}

  def validate_game_id(game_id) when is_binary(game_id) do
    cond do
      String.length(game_id) > @max_game_id_length ->
        {:error, "Game ID too long"}

      not Regex.match?(@game_id_regex, game_id) ->
        {:error, "Invalid game ID format"}

      true ->
        {:ok, game_id}
    end
  end

  def validate_game_id(_), do: {:error, "Game ID must be a string"}

  @doc """
  Validates a join code format.
  """
  @spec validate_join_code(String.t() | nil) :: validation_result()
  def validate_join_code(nil), do: {:error, "Join code cannot be empty"}
  def validate_join_code(""), do: {:error, "Join code cannot be empty"}

  def validate_join_code(code) when is_binary(code) do
    code = String.trim(String.upcase(code))

    cond do
      String.length(code) > @max_join_code_length ->
        {:error, "Join code too long"}

      not Regex.match?(@alphanumeric_regex, code) ->
        {:error, "Invalid join code format"}

      true ->
        {:ok, code}
    end
  end

  def validate_join_code(_), do: {:error, "Join code must be a string"}

  @doc """
  Validates card selection indices.
  """
  @spec validate_card_indices([integer()], integer()) :: validation_result()
  def validate_card_indices(indices, max_hand_size) when is_list(indices) do
    cond do
      Enum.empty?(indices) ->
        {:error, "No cards selected"}

      length(indices) > 4 ->
        {:error, "Too many cards selected"}

      not Enum.all?(indices, &is_integer/1) ->
        {:error, "Invalid card indices"}

      not Enum.all?(indices, &(&1 >= 0 and &1 < max_hand_size)) ->
        {:error, "Card index out of range"}

      indices != Enum.uniq(indices) ->
        {:error, "Duplicate card indices"}

      true ->
        {:ok, indices}
    end
  end

  def validate_card_indices(_, _), do: {:error, "Card indices must be a list"}

  @doc """
  Validates a suit nomination.
  """
  @spec validate_suit(String.t() | atom()) :: validation_result()
  def validate_suit(suit) when is_atom(suit) do
    if suit in [:hearts, :diamonds, :clubs, :spades] do
      {:ok, suit}
    else
      {:error, "Invalid suit"}
    end
  end

  def validate_suit(suit) when is_binary(suit) do
    case suit do
      "hearts" -> {:ok, :hearts}
      "diamonds" -> {:ok, :diamonds}
      "clubs" -> {:ok, :clubs}
      "spades" -> {:ok, :spades}
      _ -> {:error, "Invalid suit"}
    end
  end

  def validate_suit(_), do: {:error, "Suit must be a string or atom"}

  @doc """
  Validates event parameters from LiveView events.
  """
  @spec validate_event_params(map(), [atom()]) :: validation_result()
  def validate_event_params(params, required_keys) when is_map(params) do
    missing_keys =
      Enum.filter(required_keys, fn key ->
        not Map.has_key?(params, Atom.to_string(key))
      end)

    if Enum.empty?(missing_keys) do
      {:ok, params}
    else
      {:error, "Missing required parameters: #{Enum.join(missing_keys, ", ")}"}
    end
  end

  def validate_event_params(_, _), do: {:error, "Parameters must be a map"}

  @doc """
  Rate limiting validation - checks if an action is allowed for a player.
  """
  @spec validate_rate_limit(String.t(), atom()) :: validation_result()
  def validate_rate_limit(player_id, action) do
    key = "rate_limit:#{player_id}:#{action}"
    threshold = get_rate_limit_threshold(action)
    current_count = get_rate_limit_count(key)

    case current_count do
      count when count >= threshold ->
        # Log rate limit violation for security monitoring
        SecurityLogger.log_rate_limit_violation(player_id, action, %{
          current_count: count,
          limit: threshold,
          key: key
        })

        {:error, "Rate limit exceeded. Please wait before trying again."}

      _ ->
        increment_rate_limit_count(key)
        {:ok, :allowed}
    end
  end

  # Private helper functions

  defp sanitize_string(input) do
    input
    |> String.trim()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  defp contains_profanity?(name) do
    # Basic profanity filter - in production, use a more comprehensive solution
    profanity_words = ["spam", "test123", "admin", "root", "null", "undefined"]

    normalized_name = String.downcase(name)
    Enum.any?(profanity_words, &String.contains?(normalized_name, &1))
  end

  defp get_rate_limit_count(key) do
    # In production, use Redis or ETS for distributed rate limiting
    # For now, use process dictionary for simplicity
    case Process.get({:rate_limit, key}) do
      nil ->
        0

      {count, timestamp} ->
        if System.system_time(:second) - timestamp > 60 do
          # Reset after 1 minute
          0
        else
          count
        end
    end
  end

  defp increment_rate_limit_count(key) do
    current_count = get_rate_limit_count(key)
    Process.put({:rate_limit, key}, {current_count + 1, System.system_time(:second)})
  end

  defp get_rate_limit_threshold(action) do
    case action do
      # 10 join attempts per minute
      :join_game -> 10
      # 5 game creations per minute
      :create_game -> 5
      # 100 card plays per minute
      :play_card -> 100
      # 50 draws per minute
      :draw_card -> 50
      # Default 20 actions per minute
      _ -> 20
    end
  end
end
