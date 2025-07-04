defmodule RachelWeb.Components.Helpers.CSSClassesTest do
  use ExUnit.Case, async: true
  alias RachelWeb.Components.Helpers.CSSClasses
  
  describe "input_classes/3" do
    test "returns base classes for text input without errors" do
      result = CSSClasses.input_classes("text", false, nil)
      assert result == ["w-full input"]
    end
    
    test "adds error class for text input with errors" do
      result = CSSClasses.input_classes("text", true, nil)
      assert result == ["w-full input", "input-error"]
    end
    
    test "uses custom error class when provided" do
      result = CSSClasses.input_classes("text", true, "custom-error")
      assert result == ["w-full input", "custom-error"]
    end
    
    test "returns textarea classes" do
      result = CSSClasses.input_classes("textarea", false, nil)
      assert result == ["w-full textarea"]
      
      result = CSSClasses.input_classes("textarea", true, nil)
      assert result == ["w-full textarea", "textarea-error"]
    end
    
    test "returns select classes" do
      result = CSSClasses.input_classes("select", false, nil)
      assert result == ["w-full select"]
      
      result = CSSClasses.input_classes("select", true, nil)
      assert result == ["w-full select", "select-error"]
    end
  end
  
  describe "button_classes/2" do
    test "returns default button classes" do
      result = CSSClasses.button_classes(nil, false)
      assert result == ["btn btn-primary"]
    end
    
    test "uses custom base class" do
      result = CSSClasses.button_classes("btn btn-secondary", false)
      assert result == ["btn btn-secondary"]
    end
    
    test "adds disabled class when disabled" do
      result = CSSClasses.button_classes("btn btn-primary", true)
      assert result == ["btn btn-primary", "btn-disabled"]
    end
  end
  
  describe "flash_classes/1" do
    test "returns info alert classes" do
      result = CSSClasses.flash_classes(:info)
      assert result == ["alert flex gap-2", "alert-info"]
    end
    
    test "returns error alert classes" do
      result = CSSClasses.flash_classes(:error)
      assert result == ["alert flex gap-2", "alert-error"]
    end
    
    test "returns warning alert classes" do
      result = CSSClasses.flash_classes(:warning)
      assert result == ["alert flex gap-2", "alert-warning"]
    end
    
    test "returns success alert classes" do
      result = CSSClasses.flash_classes(:success)
      assert result == ["alert flex gap-2", "alert-success"]
    end
    
    test "defaults to info for unknown kinds" do
      result = CSSClasses.flash_classes(:unknown)
      assert result == ["alert flex gap-2", "alert-info"]
    end
  end
end