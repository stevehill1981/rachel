ExUnit.start()
# No database in simplified version

# Clean up any leftover game processes before running tests
defmodule TestHelper do
  def cleanup_all_games do
    # Stop all game servers
    Rachel.Games.GameManager.list_active_games()
    |> Enum.each(fn game ->
      try do
        Rachel.Games.GameManager.stop_game(game.id)
      rescue
        _ -> :ok
      end
    end)

    # Give processes time to shut down
    Process.sleep(100)
  end
end

# Run cleanup before all tests
TestHelper.cleanup_all_games()
