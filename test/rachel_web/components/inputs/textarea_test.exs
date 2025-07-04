defmodule RachelWeb.Components.Inputs.TextareaTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias RachelWeb.Components.Inputs.Textarea

  describe "textarea/1" do
    test "renders basic textarea" do
      assigns = %{
        name: "description",
        label: "Description",
        value: "This is a test description",
        id: "desc-field",
        errors: [],
        rest: %{}
      }

      html = render_component(&Textarea.textarea/1, assigns)

      assert html =~ ~s(<textarea)
      assert html =~ ~s(name="description")
      assert html =~ ~s(id="desc-field")
      assert html =~ "This is a test description"
      assert html =~ "Description"
      assert html =~ "w-full textarea"
    end

    test "renders with placeholder and rows" do
      assigns = %{
        name: "comment",
        label: "Comment",
        value: "",
        id: "comment-field",
        errors: [],
        rest: %{placeholder: "Enter your comment...", rows: "5"}
      }

      html = render_component(&Textarea.textarea/1, assigns)

      assert html =~ ~s(placeholder="Enter your comment...")
      assert html =~ ~s(rows="5")
    end

    test "renders with errors" do
      assigns = %{
        name: "bio",
        label: "Bio",
        value: "",
        id: "bio-field",
        errors: ["is too short", "must be interesting"],
        rest: %{}
      }

      html = render_component(&Textarea.textarea/1, assigns)

      assert html =~ "textarea-error"
      assert html =~ "is too short"
      assert html =~ "must be interesting"
      assert html =~ "text-error"
    end

    test "handles disabled and readonly states" do
      assigns = %{
        name: "locked",
        label: "Locked Content",
        value: "This cannot be changed",
        id: "locked-field",
        errors: [],
        rest: %{disabled: true, readonly: true}
      }

      html = render_component(&Textarea.textarea/1, assigns)

      assert html =~ ~s(disabled)
      assert html =~ ~s(readonly)
    end

    test "applies custom classes" do
      assigns = %{
        name: "styled",
        label: "Styled Textarea",
        value: "",
        id: "styled-field",
        errors: [],
        class: "custom-textarea-class",
        rest: %{}
      }

      html = render_component(&Textarea.textarea/1, assigns)

      assert html =~ "custom-textarea-class"
      refute html =~ "w-full textarea"
    end

    test "handles maxlength and minlength" do
      assigns = %{
        name: "limited",
        label: "Limited Text",
        value: "",
        id: "limited-field",
        errors: [],
        rest: %{minlength: "10", maxlength: "200"}
      }

      html = render_component(&Textarea.textarea/1, assigns)

      assert html =~ ~s(minlength="10")
      assert html =~ ~s(maxlength="200")
    end

    test "normalizes textarea value correctly" do
      assigns = %{
        name: "normalized",
        label: "Normalized",
        value: nil,
        id: "normalized-field",
        errors: [],
        rest: %{}
      }

      html = render_component(&Textarea.textarea/1, assigns)

      # Phoenix.HTML.Form.normalize_value converts nil to empty string for textarea
      assert html =~ ~s(<textarea id="normalized-field")
    end
  end
end
