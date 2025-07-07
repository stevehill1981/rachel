defmodule Rachel.RateLimiterTest do
  use ExUnit.Case, async: false

  alias Rachel.RateLimiter

  setup do
    # Ensure clean state
    :ok = RateLimiter.reset("test_key")
    :ok
  end

  test "allows requests within limit" do
    assert :ok = RateLimiter.check_rate("test_key", max_requests: 5, window_ms: 1000)
    assert :ok = RateLimiter.check_rate("test_key", max_requests: 5, window_ms: 1000)
    assert :ok = RateLimiter.check_rate("test_key", max_requests: 5, window_ms: 1000)
  end

  test "blocks requests over limit" do
    # Fill up the limit
    for _i <- 1..5 do
      assert :ok = RateLimiter.check_rate("test_key", max_requests: 5, window_ms: 60_000)
    end
    
    # This should be blocked
    assert {:error, :rate_limited} = RateLimiter.check_rate("test_key", max_requests: 5, window_ms: 60_000)
  end

  test "reset clears rate limit" do
    # Fill up the limit
    for _i <- 1..5 do
      assert :ok = RateLimiter.check_rate("test_key", max_requests: 5, window_ms: 60_000)
    end
    
    assert {:error, :rate_limited} = RateLimiter.check_rate("test_key", max_requests: 5, window_ms: 60_000)
    
    # Reset and try again
    :ok = RateLimiter.reset("test_key")
    assert :ok = RateLimiter.check_rate("test_key", max_requests: 5, window_ms: 60_000)
  end

  test "different keys are independent" do
    # Fill up limit for key1
    for _i <- 1..5 do
      assert :ok = RateLimiter.check_rate("key1", max_requests: 5, window_ms: 60_000)
    end
    
    assert {:error, :rate_limited} = RateLimiter.check_rate("key1", max_requests: 5, window_ms: 60_000)
    
    # key2 should still work
    assert :ok = RateLimiter.check_rate("key2", max_requests: 5, window_ms: 60_000)
  end
end