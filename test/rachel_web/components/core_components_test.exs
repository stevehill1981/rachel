defmodule RachelWeb.CoreComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias RachelWeb.CoreComponents
  
  describe "flash/1" do
    test "renders info flash from flash map" do
      assigns = %{
        kind: :info,
        flash: %{"info" => "Success message"},
        rest: %{}
      }
      
      html = render_component(&CoreComponents.flash/1, assigns)
      
      assert html =~ "alert"
      assert html =~ "alert-info"
      assert html =~ "Success message"
    end
    
    test "renders error flash from flash map" do
      assigns = %{
        kind: :error,
        flash: %{"error" => "Error message"},
        title: "Error!",
        rest: %{}
      }
      
      html = render_component(&CoreComponents.flash/1, assigns)
      
      assert html =~ "alert"
      assert html =~ "alert-error"
      assert html =~ "Error message"
    end
    
    test "renders flash with empty content when no message" do
      assigns = %{
        kind: :info,
        flash: %{},
        rest: %{}
      }
      
      html = render_component(&CoreComponents.flash/1, assigns)
      
      # Should render nothing when no message
      assert html == ""
    end
  end
  
  # Note: Components with slots (button, header, table, list) are difficult to test
  # with render_component as it doesn't support slot rendering properly.
  # These would be better tested in integration tests.
  
  describe "icon/1" do
    test "renders hero icon" do
      assigns = %{
        name: "hero-x-mark",
        class: nil
      }
      
      html = render_component(&CoreComponents.icon/1, assigns)
      
      assert html =~ "<span"
      assert html =~ "hero-x-mark"
    end
    
    test "renders icon with custom class" do
      assigns = %{
        name: "hero-check",
        class: "w-6 h-6 text-green-500"
      }
      
      html = render_component(&CoreComponents.icon/1, assigns)
      
      assert html =~ "hero-check"
      assert html =~ "w-6 h-6 text-green-500"
    end
  end
  
  describe "translate_error/1" do
    test "translates error with count" do
      error = {"must have %{count} items", [count: 5]}
      result = CoreComponents.translate_error(error)
      
      # Since we don't have actual translations loaded, it returns the interpolated message
      assert result =~ "5"
    end
    
    test "translates simple error" do
      error = {"is required", []}
      result = CoreComponents.translate_error(error)
      
      assert result == "is required"
    end
    
    test "translates error with interpolation" do
      error = {"must be at least %{min} characters", [min: 8]}
      result = CoreComponents.translate_error(error)
      
      assert result =~ "8"
    end
  end
  
  describe "translate_errors/2" do
    test "translates list of errors for a field" do
      errors = [
        {:email, {"has invalid format", []}},
        {:name, {"is too short", [min: 3]}}
      ]
      
      result = CoreComponents.translate_errors(errors, :email)
      
      assert result == ["has invalid format"]
    end
    
    test "returns empty list when no errors for field" do
      errors = [
        {:name, {"is required", []}}
      ]
      
      result = CoreComponents.translate_errors(errors, :email)
      
      assert result == []
    end
    
    test "handles multiple errors for same field" do
      errors = [
        {:email, {"is required", []}},
        {:email, {"has invalid format", []}},
        {:name, {"is too short", []}}
      ]
      
      result = CoreComponents.translate_errors(errors, :email)
      
      assert length(result) == 2
      assert "is required" in result
      assert "has invalid format" in result
    end
  end
  
  describe "show/2 and hide/2" do
    test "delegates show to JSCommands" do
      # Just verify delegation works
      result = CoreComponents.show("#element")
      assert %Phoenix.LiveView.JS{} = result
    end
    
    test "delegates hide to JSCommands" do
      # Just verify delegation works
      result = CoreComponents.hide("#element")
      assert %Phoenix.LiveView.JS{} = result
    end
  end
end