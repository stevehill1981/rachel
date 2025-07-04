defmodule RachelWeb.Components.Inputs.CheckboxTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias RachelWeb.Components.Inputs.Checkbox
  
  describe "checkbox/1" do
    test "renders unchecked checkbox" do
      assigns = %{
        name: "subscribe",
        label: "Subscribe to newsletter",
        value: false,
        id: "subscribe-checkbox",
        errors: [],
        rest: %{}
      }
      
      html = render_component(&Checkbox.checkbox/1, assigns)
      
      assert html =~ ~s(type="checkbox")
      assert html =~ ~s(name="subscribe")
      assert html =~ ~s(id="subscribe-checkbox")
      assert html =~ ~s(value="true")
      refute html =~ ~s(checked)
      assert html =~ "Subscribe to newsletter"
      
      # Hidden input for false value
      assert html =~ ~s(type="hidden")
      assert html =~ ~s(value="false")
    end
    
    test "renders checked checkbox" do
      assigns = %{
        name: "terms",
        label: "I agree to the terms",
        value: true,
        checked: true,
        id: "terms-checkbox",
        errors: [],
        rest: %{}
      }
      
      html = render_component(&Checkbox.checkbox/1, assigns)
      
      assert html =~ ~s(checked)
      assert html =~ "I agree to the terms"
    end
    
    test "renders with errors" do
      assigns = %{
        name: "terms",
        label: "I agree to the terms",
        value: false,
        id: "terms-checkbox",
        errors: ["must be accepted"],
        rest: %{}
      }
      
      html = render_component(&Checkbox.checkbox/1, assigns)
      
      assert html =~ "must be accepted"
      assert html =~ "text-error"
    end
    
    test "handles disabled state" do
      assigns = %{
        name: "locked",
        label: "This is locked",
        value: true,
        checked: true,
        id: "locked-checkbox",
        errors: [],
        rest: %{disabled: true}
      }
      
      html = render_component(&Checkbox.checkbox/1, assigns)
      
      assert html =~ ~s(disabled)
    end
  end
end