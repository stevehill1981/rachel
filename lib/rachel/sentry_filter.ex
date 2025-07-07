defmodule Rachel.SentryFilter do
  @moduledoc """
  Filters and sanitizes events before sending to Sentry.
  Prevents sensitive data from being logged.
  """

  @filtered_params ["password", "token", "secret", "api_key", "session_id"]

  @doc """
  Filter out sensitive data and noisy errors before sending to Sentry.
  """
  def before_send(%{exception: [%{type: exception_type}]} = event) do
    # Don't send certain expected errors to Sentry
    case exception_type do
      # Phoenix expected errors
      Phoenix.Router.NoRouteError -> nil
      Phoenix.ActionClauseError -> nil
      # Ecto expected errors (like unique constraint violations)
      Ecto.NoResultsError -> nil
      # Rate limiting errors (these are expected)
      :rate_limit_exceeded -> nil
      # Everything else gets sent
      _ -> sanitize_event(event)
    end
  end

  def before_send(event), do: sanitize_event(event)

  defp sanitize_event(event) do
    event
    |> sanitize_params()
    |> sanitize_cookies()
    |> add_custom_context()
  end

  defp sanitize_params(%{request: %{data: data}} = event) when is_map(data) do
    sanitized_data =
      data
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        if Enum.any?(@filtered_params, &String.contains?(to_string(key), &1)) do
          Map.put(acc, key, "[FILTERED]")
        else
          Map.put(acc, key, value)
        end
      end)

    put_in(event, [:request, :data], sanitized_data)
  end

  defp sanitize_params(event), do: event

  defp sanitize_cookies(%{request: %{cookies: cookies}} = event) when is_map(cookies) do
    # Filter out session cookies
    sanitized_cookies =
      cookies
      |> Enum.reduce(%{}, fn {key, _value}, acc ->
        Map.put(acc, key, "[FILTERED]")
      end)

    put_in(event, [:request, :cookies], sanitized_cookies)
  end

  defp sanitize_cookies(event), do: event

  defp add_custom_context(%{extra: extra} = event) do
    # Add useful game context without sensitive data
    custom_context = %{
      node: node() |> to_string(),
      otp_release: :erlang.system_info(:otp_release) |> to_string(),
      elixir_version: System.version()
    }

    %{event | extra: Map.merge(extra || %{}, custom_context)}
  end

  defp add_custom_context(event) do
    add_custom_context(Map.put(event, :extra, %{}))
  end
end
