#!/usr/bin/env elixir

# Simple load testing script for Rachel
# Usage: elixir scripts/load_test.exs [base_url] [num_players]

defmodule LoadTest do
  @moduledoc """
  Simple load testing for Rachel game.
  Creates multiple concurrent game sessions to test capacity.
  """
  
  def run(base_url \\ "http://localhost:4000", num_players \\ 10) do
    IO.puts("Load Testing Rachel Game")
    IO.puts("========================")
    IO.puts("Target: #{base_url}")
    IO.puts("Players: #{num_players}")
    IO.puts("")
    
    # Health check first
    case check_health(base_url) do
      :ok ->
        IO.puts("✅ Health check passed")
        run_load_test(base_url, num_players)
      :error ->
        IO.puts("❌ Health check failed - is the server running?")
        System.halt(1)
    end
  end
  
  defp check_health(base_url) do
    url = "#{base_url}/health"
    
    case :httpc.request(:get, {String.to_charlist(url), []}, [], []) do
      {:ok, {{_, 200, _}, _, _}} -> :ok
      _ -> :error
    end
  end
  
  defp run_load_test(base_url, num_players) do
    IO.puts("\nStarting load test...")
    start_time = System.monotonic_time(:millisecond)
    
    # Create concurrent players
    tasks = for i <- 1..num_players do
      Task.async(fn ->
        player_name = "LoadTest#{i}"
        simulate_player(base_url, player_name, i)
      end)
    end
    
    # Wait for all players to complete
    results = Task.await_many(tasks, 60_000)
    
    # Calculate statistics
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time
    
    successful = Enum.count(results, fn {status, _} -> status == :ok end)
    failed = num_players - successful
    
    IO.puts("\nLoad Test Results")
    IO.puts("=================")
    IO.puts("Duration: #{duration}ms")
    IO.puts("Successful: #{successful}/#{num_players}")
    IO.puts("Failed: #{failed}/#{num_players}")
    IO.puts("Avg time per player: #{div(duration, num_players)}ms")
    
    if failed > 0 do
      IO.puts("\nErrors:")
      results
      |> Enum.filter(fn {status, _} -> status == :error end)
      |> Enum.each(fn {_, error} -> IO.puts("  - #{error}") end)
    end
  end
  
  defp simulate_player(base_url, player_name, delay_ms) do
    # Stagger player joins
    Process.sleep(delay_ms * 100)
    
    try do
      # 1. Hit the home page
      case http_get("#{base_url}/") do
        {:ok, _} ->
          # 2. Create a practice game (would need WebSocket for full test)
          # For now, just hit the practice page
          case http_get("#{base_url}/practice") do
            {:ok, _} ->
              IO.puts("✅ Player #{player_name} connected")
              {:ok, player_name}
            {:error, reason} ->
              {:error, "Practice page failed: #{reason}"}
          end
        {:error, reason} ->
          {:error, "Home page failed: #{reason}"}
      end
    rescue
      e -> {:error, "Exception: #{inspect(e)}"}
    end
  end
  
  defp http_get(url) do
    case :httpc.request(:get, {String.to_charlist(url), []}, [{:timeout, 10_000}], []) do
      {:ok, {{_, status, _}, _, _body}} when status in 200..299 ->
        {:ok, status}
      {:ok, {{_, status, _}, _, _}} ->
        {:error, "HTTP #{status}"}
      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end
end

# Start the inets application for HTTP client
:inets.start()

# Parse command line arguments
{base_url, num_players} = case System.argv() do
  [url, num] -> 
    {url, String.to_integer(num)}
  [url] -> 
    {url, 10}
  [] -> 
    {"http://localhost:4000", 10}
end

# Run the load test
LoadTest.run(base_url, num_players)