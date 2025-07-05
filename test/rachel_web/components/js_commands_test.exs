defmodule RachelWeb.Components.JSCommandsTest do
  use ExUnit.Case, async: true
  alias Phoenix.LiveView.JS
  alias RachelWeb.Components.JSCommands

  describe "show/2" do
    test "creates show command with default JS struct" do
      result = JSCommands.show("#my-element")

      assert %JS{} = result
      assert [["show", opts]] = result.ops
      assert opts[:to] == "#my-element"
      assert opts[:time] == 200
      assert opts[:transition] != nil
    end

    test "chains show command to existing JS struct" do
      js = %JS{ops: [["hide", %{to: "#other"}]]}
      result = JSCommands.show(js, "#my-element")

      assert length(result.ops) == 2
      assert [["hide", _], ["show", _]] = result.ops
    end
  end

  describe "hide/2" do
    test "creates hide command with default JS struct" do
      result = JSCommands.hide("#my-element")

      assert %JS{} = result
      assert [["hide", opts]] = result.ops
      assert opts[:to] == "#my-element"
      assert opts[:time] == 200
      assert opts[:transition] != nil
    end

    test "chains hide command to existing JS struct" do
      js = %JS{ops: [["show", %{to: "#other"}]]}
      result = JSCommands.hide(js, "#my-element")

      assert length(result.ops) == 2
      assert [["show", _], ["hide", _]] = result.ops
    end
  end

  describe "show_modal/2" do
    test "creates sequence of commands to show modal" do
      result = JSCommands.show_modal("my-modal")

      assert %JS{} = result
      # Should have multiple operations for showing modal
      assert length(result.ops) > 1

      # Check for key operations
      ops = result.ops

      assert Enum.any?(ops, fn
               ["show", %{to: "#my-modal"}] -> true
               _ -> false
             end)

      assert Enum.any?(ops, fn
               ["show", %{to: "#my-modal-bg"}] -> true
               _ -> false
             end)

      assert Enum.any?(ops, fn
               ["add_class", %{to: "body"}] -> true
               _ -> false
             end)

      assert Enum.any?(ops, fn
               ["focus_first", %{to: "#my-modal-content"}] -> true
               _ -> false
             end)
    end

    test "chains modal commands to existing JS struct" do
      js = %JS{ops: [["hide", %{to: "#something"}]]}
      result = JSCommands.show_modal(js, "my-modal")

      assert [["hide", _] | _rest] = result.ops
      assert length(result.ops) > 2
    end
  end

  describe "hide_modal/2" do
    test "creates sequence of commands to hide modal" do
      result = JSCommands.hide_modal("my-modal")

      assert %JS{} = result
      # Should have multiple operations for hiding modal
      assert length(result.ops) > 1

      # Check for key operations
      ops = result.ops

      assert Enum.any?(ops, fn
               ["hide", %{to: "#my-modal-bg"}] -> true
               _ -> false
             end)

      assert Enum.any?(ops, fn
               ["hide", %{to: "#my-modal"}] -> true
               _ -> false
             end)

      assert Enum.any?(ops, fn
               ["remove_class", %{to: "body"}] -> true
               _ -> false
             end)

      assert Enum.any?(ops, fn
               ["pop_focus" | _] -> true
               _ -> false
             end)
    end
  end

  describe "dismiss_flash/1" do
    test "creates commands to dismiss flash message" do
      result = JSCommands.dismiss_flash("#flash-info")

      assert %JS{} = result
      ops = result.ops

      # Should push clear-flash event
      assert Enum.any?(ops, fn
               ["push", %{event: "lv:clear-flash"}] -> true
               _ -> false
             end)

      # Should hide the flash element
      assert Enum.any?(ops, fn
               ["hide", %{to: "#flash-info"}] -> true
               _ -> false
             end)
    end

    test "includes flash key in push value" do
      result = JSCommands.dismiss_flash("#flash-error")

      push_op =
        Enum.find(result.ops, fn
          ["push", _] -> true
          _ -> false
        end)

      assert ["push", %{value: %{key: "#flash-error"}}] = push_op
    end
  end
end
