defmodule RachelWeb.Components.Helpers.CSSClasses do
  @moduledoc """
  Helper functions for building CSS class lists.
  Provides pure functions that can be easily tested.
  """
  
  @doc """
  Builds input CSS classes based on type and error state.
  
  ## Examples
  
      iex> input_classes("text", false, nil)
      ["w-full input"]
      
      iex> input_classes("text", true, nil)
      ["w-full input", "input-error"]
      
      iex> input_classes("text", true, "custom-error")
      ["w-full input", "custom-error"]
  """
  def input_classes(type, has_errors?, custom_error_class) do
    base_class = case type do
      "textarea" -> "w-full textarea"
      "select" -> "w-full select"
      _ -> "w-full input"
    end
    
    error_class = case {has_errors?, custom_error_class} do
      {false, _} -> nil
      {true, nil} -> "#{type_base(type)}-error"
      {true, custom} -> custom
    end
    
    [base_class, error_class] |> Enum.filter(& &1)
  end
  
  defp type_base("textarea"), do: "textarea"
  defp type_base("select"), do: "select"
  defp type_base(_), do: "input"
  
  @doc """
  Builds button CSS classes based on state.
  """
  def button_classes(base_class, disabled?) do
    base = base_class || "btn btn-primary"
    
    if disabled? do
      [base, "btn-disabled"]
    else
      [base]
    end
  end
  
  @doc """
  Builds flash CSS classes based on kind.
  """
  def flash_classes(kind) do
    base = "alert flex gap-2"
    
    kind_class = case kind do
      :info -> "alert-info"
      :error -> "alert-error"
      :warning -> "alert-warning"
      :success -> "alert-success"
      _ -> "alert-info"
    end
    
    [base, kind_class]
  end
end