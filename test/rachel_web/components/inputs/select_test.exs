defmodule RachelWeb.Components.Inputs.SelectTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias RachelWeb.Components.Inputs.Select
  
  describe "select/1" do
    test "renders basic select" do
      assigns = %{
        name: "country",
        label: "Country",
        value: "US",
        options: [{"United States", "US"}, {"Canada", "CA"}, {"Mexico", "MX"}],
        id: "country-select",
        errors: [],
        multiple: false,
        prompt: nil,
        rest: %{}
      }
      
      html = render_component(&Select.select/1, assigns)
      
      assert html =~ ~s(<select)
      assert html =~ ~s(name="country")
      assert html =~ ~s(id="country-select")
      assert html =~ "Country"
      assert html =~ "United States"
      assert html =~ "Canada"
      assert html =~ "Mexico"
      assert html =~ ~s(value="US")
      assert html =~ ~s(value="CA")
      assert html =~ ~s(value="MX")
    end
    
    test "renders with prompt" do
      assigns = %{
        name: "role",
        label: "User Role",
        value: nil,
        options: [{"Admin", "admin"}, {"User", "user"}],
        prompt: "Choose a role",
        id: "role-select",
        errors: [],
        multiple: false,
        rest: %{}
      }
      
      html = render_component(&Select.select/1, assigns)
      
      assert html =~ ~s(<option value="">Choose a role</option>)
    end
    
    test "renders multiple select" do
      assigns = %{
        name: "tags",
        label: "Tags",
        value: ["elixir", "phoenix"],
        options: [{"Elixir", "elixir"}, {"Phoenix", "phoenix"}, {"LiveView", "liveview"}],
        id: "tags-select",
        errors: [],
        multiple: true,
        prompt: nil,
        rest: %{}
      }
      
      html = render_component(&Select.select/1, assigns)
      
      assert html =~ ~s(multiple)
    end
    
    test "renders with errors" do
      assigns = %{
        name: "category",
        label: "Category",
        value: nil,
        options: [{"Tech", "tech"}, {"Business", "business"}],
        id: "category-select",
        errors: ["is required"],
        multiple: false,
        prompt: nil,
        rest: %{}
      }
      
      html = render_component(&Select.select/1, assigns)
      
      assert html =~ "select-error"
      assert html =~ "is required"
    end
  end
end