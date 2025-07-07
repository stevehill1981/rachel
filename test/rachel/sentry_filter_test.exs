defmodule Rachel.SentryFilterTest do
  use ExUnit.Case, async: true

  alias Rachel.SentryFilter

  describe "before_send/1 with exception" do
    test "filters out noisy errors" do
      # Phoenix.Router.NoRouteError should be filtered
      event = %{exception: [%{type: Phoenix.Router.NoRouteError}]}
      assert SentryFilter.before_send(event) == nil
      
      # Phoenix.ActionClauseError should be filtered  
      event = %{exception: [%{type: Phoenix.ActionClauseError}]}
      assert SentryFilter.before_send(event) == nil
      
      # Ecto.NoResultsError should be filtered
      event = %{exception: [%{type: Ecto.NoResultsError}]}
      assert SentryFilter.before_send(event) == nil
      
      # Rate limit errors should be filtered
      event = %{exception: [%{type: :rate_limit_exceeded}]}
      assert SentryFilter.before_send(event) == nil
    end

    test "allows other errors through" do
      event = %{exception: [%{type: RuntimeError}], request: %{data: %{}}}
      result = SentryFilter.before_send(event)
      assert result != nil
      assert is_map(result)
    end
  end

  test "sanitizes sensitive parameters" do
    event = %{
      request: %{
        data: %{
          "password" => "secret123",
          "username" => "alice",
          "token" => "abc123"
        }
      }
    }
    
    result = SentryFilter.before_send(event)
    
    assert result.request.data["password"] == "[FILTERED]"
    assert result.request.data["token"] == "[FILTERED]"
    assert result.request.data["username"] == "alice"
  end

  test "adds custom context" do
    event = %{}
    result = SentryFilter.before_send(event)
    
    assert Map.has_key?(result.extra, :environment)
    assert Map.has_key?(result.extra, :elixir_version)
  end
end