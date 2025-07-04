defmodule RachelWeb.Components.Inputs.TextField do
  @moduledoc """
  Text field input component for various input types.
  Handles text, email, password, number, date, and other HTML5 input types.
  """
  use RachelWeb.Components.Inputs.Base
  
  attr :type, :string,
    default: "text",
    values: ~w(color date datetime-local email file month number password
               search tel text time url week)
  
  attr :rest, :global,
    include: ~w(accept autocomplete capture disabled form list max maxlength min minlength
                pattern placeholder readonly required size step)
  
  @doc """
  Renders a text-based input field.
  
  ## Examples
  
      <.text_field name="email" type="email" label="Email Address" />
      <.text_field field={@form[:password]} type="password" />
      <.text_field name="age" type="number" min="0" max="120" />
  """
  def text_field(%{field: %Phoenix.HTML.FormField{}} = assigns) do
    assigns
    |> process_field(assigns)
    |> text_field()
  end
  
  def text_field(assigns) do
    ~H"""
    <fieldset class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || "w-full input",
            @errors != [] && (@error_class || "input-error")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end
end