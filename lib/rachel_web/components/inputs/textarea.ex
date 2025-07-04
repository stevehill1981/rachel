defmodule RachelWeb.Components.Inputs.Textarea do
  @moduledoc """
  Textarea input component.
  """
  use RachelWeb.Components.Inputs.Base
  
  attr :rest, :global,
    include: ~w(cols disabled form maxlength minlength placeholder readonly required rows)
  
  @doc """
  Renders a textarea input.
  
  ## Examples
  
      <.textarea name="description" label="Description" rows="4" />
      <.textarea field={@form[:message]} placeholder="Enter your message..." />
  """
  def textarea(%{field: %Phoenix.HTML.FormField{}} = assigns) do
    process_field(assigns.field, assigns)
    |> textarea()
  end
  
  def textarea(assigns) do
    ~H"""
    <fieldset class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full textarea",
            @errors != [] && (@error_class || "textarea-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end
end