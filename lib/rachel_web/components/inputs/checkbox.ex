defmodule RachelWeb.Components.Inputs.Checkbox do
  @moduledoc """
  Checkbox input component.
  """
  use RachelWeb.Components.Inputs.Base
  
  alias Phoenix.HTML.Form
  
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :rest, :global,
    include: ~w(disabled form required)
  
  @doc """
  Renders a checkbox input.
  
  ## Examples
  
      <.checkbox name="terms" label="I agree to the terms" />
      <.checkbox field={@form[:subscribe]} label="Subscribe to newsletter" />
  """
  def checkbox(%{field: %Phoenix.HTML.FormField{}} = assigns) do
    assigns
    |> process_field(assigns)
    |> checkbox()
  end
  
  def checkbox(assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Form.normalize_value("checkbox", assigns[:value])
      end)
    
    ~H"""
    <fieldset class="fieldset mb-2">
      <label>
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <span class="label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "checkbox checkbox-sm"}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end
end