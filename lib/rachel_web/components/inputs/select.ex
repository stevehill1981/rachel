defmodule RachelWeb.Components.Inputs.Select do
  @moduledoc """
  Select dropdown input component.
  """
  use RachelWeb.Components.Inputs.Base
  
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :rest, :global,
    include: ~w(disabled form required size)
  
  @doc """
  Renders a select input.
  
  ## Examples
  
      <.select name="country" options={["USA", "Canada", "Mexico"]} />
      <.select field={@form[:role]} options={[Admin: "admin", User: "user"]} />
  """
  def select(%{field: %Phoenix.HTML.FormField{}} = assigns) do
    process_field(assigns.field, assigns)
    |> select()
  end
  
  def select(assigns) do
    ~H"""
    <fieldset class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "w-full select", @errors != [] && (@error_class || "select-error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end
end