defmodule RachelWeb.Components.Inputs.TextFieldTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias RachelWeb.Components.Inputs.TextField

  describe "text_field/1" do
    test "renders basic text input" do
      assigns = %{
        name: "email",
        label: "Email Address",
        value: "test@example.com",
        type: "email",
        id: "user-email",
        errors: [],
        rest: %{}
      }

      html = render_component(&TextField.text_field/1, assigns)

      assert html =~ ~s(type="email")
      assert html =~ ~s(name="email")
      assert html =~ ~s(id="user-email")
      assert html =~ ~s(value="test@example.com")
      assert html =~ "Email Address"
    end

    test "renders with errors" do
      assigns = %{
        name: "password",
        label: "Password",
        value: "",
        type: "password",
        id: "user-password",
        errors: ["must be at least 8 characters"],
        rest: %{}
      }

      html = render_component(&TextField.text_field/1, assigns)

      assert html =~ "input-error"
      assert html =~ "must be at least 8 characters"
      assert html =~ "text-error"
    end

    test "renders number input with constraints" do
      assigns = %{
        name: "age",
        label: "Age",
        value: "25",
        type: "number",
        id: "user-age",
        errors: [],
        rest: %{min: "0", max: "120", step: "1"}
      }

      html = render_component(&TextField.text_field/1, assigns)

      assert html =~ ~s(type="number")
      assert html =~ ~s(min="0")
      assert html =~ ~s(max="120")
      assert html =~ ~s(step="1")
    end

    test "applies custom CSS classes" do
      assigns = %{
        name: "custom",
        label: "Custom Field",
        value: "",
        type: "text",
        id: "custom-field",
        errors: [],
        class: "custom-input-class",
        rest: %{}
      }

      html = render_component(&TextField.text_field/1, assigns)

      assert html =~ "custom-input-class"
      refute html =~ "w-full input"
    end
  end
end
