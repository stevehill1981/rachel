defmodule Rachel.RateLimiter do
  @moduledoc """
  ETS-based rate limiter for single-node deployments.
  Uses a sliding window algorithm to track requests.
  
  Can be upgraded to use Redis for multi-node deployments.
  """
  
  use GenServer
  require Logger
  
  @table_name :rate_limiter
  @cleanup_interval :timer.minutes(5)
  @default_window_ms :timer.seconds(60)
  @default_max_requests 60
  
  # Client API
  
  @doc """
  Check if a request is allowed for the given key.
  Returns {:ok, remaining} or {:error, :rate_limited}
  """
  def check_rate(key, opts \\ []) do
    max_requests = Keyword.get(opts, :max_requests, @default_max_requests)
    window_ms = Keyword.get(opts, :window_ms, @default_window_ms)
    
    GenServer.call(__MODULE__, {:check_rate, key, max_requests, window_ms})
  end
  
  @doc """
  Get current usage for a key
  """
  def get_usage(key, window_ms \\ @default_window_ms) do
    GenServer.call(__MODULE__, {:get_usage, key, window_ms})
  end
  
  @doc """
  Reset rate limit for a key (useful for testing)
  """
  def reset(key) do
    GenServer.call(__MODULE__, {:reset, key})
  end
  
  # Server callbacks
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    # Create ETS table for storing rate limit data
    :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    
    # Schedule periodic cleanup
    schedule_cleanup()
    
    {:ok, %{}}
  end
  
  @impl true
  def handle_call({:check_rate, key, max_requests, window_ms}, _from, state) do
    now = System.system_time(:millisecond)
    window_start = now - window_ms
    
    # Get or create entry for this key
    requests = case :ets.lookup(@table_name, key) do
      [{^key, timestamps}] -> 
        # Filter out timestamps outside the window
        Enum.filter(timestamps, &(&1 > window_start))
      [] -> 
        []
    end
    
    request_count = length(requests)
    
    if request_count < max_requests do
      # Allow request and record timestamp
      new_requests = [now | requests]
      :ets.insert(@table_name, {key, new_requests})
      {:reply, {:ok, max_requests - request_count - 1}, state}
    else
      # Rate limited
      {:reply, {:error, :rate_limited}, state}
    end
  end
  
  @impl true
  def handle_call({:get_usage, key, window_ms}, _from, state) do
    now = System.system_time(:millisecond)
    window_start = now - window_ms
    
    count = case :ets.lookup(@table_name, key) do
      [{^key, timestamps}] -> 
        timestamps
        |> Enum.filter(&(&1 > window_start))
        |> length()
      [] -> 
        0
    end
    
    {:reply, count, state}
  end
  
  @impl true
  def handle_call({:reset, key}, _from, state) do
    :ets.delete(@table_name, key)
    {:reply, :ok, state}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    # Remove old entries to prevent memory growth
    cleanup_old_entries()
    schedule_cleanup()
    {:noreply, state}
  end
  
  # Private functions
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
  
  defp cleanup_old_entries do
    now = System.system_time(:millisecond)
    # Keep data for up to 2 hours
    cutoff = now - :timer.hours(2)
    
    # Iterate through all entries and clean old timestamps
    :ets.foldl(fn {key, timestamps}, acc ->
      filtered = Enum.filter(timestamps, &(&1 > cutoff))
      
      if filtered == [] do
        # No recent requests, delete the entry
        :ets.delete(@table_name, key)
      else
        # Update with filtered timestamps
        :ets.insert(@table_name, {key, filtered})
      end
      
      acc
    end, 0, @table_name)
    
    Logger.debug("Rate limiter cleanup completed")
  end
end