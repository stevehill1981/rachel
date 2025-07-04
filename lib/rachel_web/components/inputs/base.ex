defmodule RachelWeb.Components.Inputs.Base do
  @moduledoc """
  Base functionality shared by all input components.
  Provides common attributes and helper functions.
  """
  
  use Phoenix.Component
  
  defmacro __using__(_opts) do
    quote do
      use Phoenix.Component
      
      # Common attributes for all inputs
      attr :id, :any, default: nil
      attr :name, :any
      attr :label, :string, default: nil
      attr :value, :any
      attr :field, Phoenix.HTML.FormField,
        doc: "a form field struct retrieved from the form, for example: @form[:email]"
      attr :errors, :list, default: []
      attr :class, :string, default: nil, doc: "the input class to use over defaults"
      attr :error_class, :string, default: nil, doc: "the input error class to use over defaults"
      
      # Import helper functions
      import RachelWeb.Components.Inputs.Base
    end
  end
  
  @doc """
  Processes a Phoenix.HTML.FormField and extracts its properties.
  """
  def process_field(%Phoenix.HTML.FormField{} = field, assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []
    
    assigns
    |> Map.merge(%{
      field: nil,
      id: assigns.id || field.id,
      errors: Enum.map(errors, &translate_error(&1)),
      name: assigns[:multiple] && field.name <> "[]" || field.name,
      value: assigns[:value] || field.value
    })
  end
  
  def process_field(_field, assigns), do: assigns
  
  @doc """
  Renders error messages for an input.
  """
  def error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <svg class="size-5" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
      </svg>
      {render_slot(@inner_block)}
    </p>
    """
  end
  
  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # Use the same translation backend as CoreComponents
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
  
  def translate_error(msg), do: msg
end