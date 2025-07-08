defmodule RachelWeb.ThemeComponents do
  @moduledoc """
  Theme-related UI components for Rachel card game.
  """
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  @themes [
    %{
      id: "modern-minimalist",
      name: "Modern Minimalist",
      description: "Clean, Apple-inspired design",
      preview_colors: ["#007aff", "#ffffff", "#f8f9fa"]
    },
    %{
      id: "premium-card-room", 
      name: "Premium Card Room",
      description: "Luxury casino aesthetic",
      preview_colors: ["#d4af37", "#1a2332", "#1a4d3a"]
    },
    %{
      id: "warm-social",
      name: "Warm & Social", 
      description: "Cozy pub atmosphere",
      preview_colors: ["#d2691e", "#faf6f2", "#8b4513"]
    }
  ]

  @doc """
  Renders a compact theme selector button for the UI.
  """
  attr :current_theme, :string, default: "modern-minimalist"
  attr :position, :string, default: "top-4 right-4", doc: "CSS positioning classes"

  def theme_selector_button(assigns) do
    assigns = assign(assigns, :themes, @themes)
    
    ~H"""
    <div class={"fixed #{@position} z-50"}>
      <button
        id="theme-selector-toggle"
        class="p-3 bg-white/90 backdrop-blur-sm rounded-full shadow-lg hover:shadow-xl transition-all duration-200 group"
        phx-click={toggle_theme_menu()}
        title="Change theme"
      >
        <svg class="w-5 h-5 text-gray-700 group-hover:text-gray-900 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zM21 5a2 2 0 00-2-2h-4a2 2 0 00-2 2v6a2 2 0 002 2h4a2 2 0 002-2V5zM21 15a2 2 0 00-2-2h-4a2 2 0 00-2 2v2a2 2 0 002 2h4a2 2 0 002-2v-2z" />
        </svg>
      </button>
      
      <!-- Theme selection menu -->
      <div
        id="theme-menu"
        class="hidden absolute top-full right-0 mt-2 w-80 bg-white rounded-2xl shadow-2xl border border-gray-200 overflow-hidden transform scale-95 opacity-0 transition-all duration-200"
        phx-click-away={hide_theme_menu()}
      >
        <div class="p-4 border-b border-gray-100">
          <h3 class="text-lg font-semibold text-gray-900 mb-1">Choose Theme</h3>
          <p class="text-sm text-gray-600">Select your preferred visual style</p>
        </div>
        
        <div class="p-2">
          <%= for theme <- @themes do %>
            <.theme_option 
              theme={theme} 
              is_current={theme.id == @current_theme}
            />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a full theme selector modal for settings pages.
  """
  attr :current_theme, :string, default: "modern-minimalist"
  attr :show, :boolean, default: false

  def theme_selector_modal(assigns) do
    assigns = assign(assigns, :themes, @themes)
    
    ~H"""
    <div
      class={[
        "fixed inset-0 z-50 flex items-center justify-center transition-all duration-300",
        @show && "bg-black/50 backdrop-blur-sm",
        !@show && "pointer-events-none bg-transparent"
      ]}
      phx-click={@show && JS.push("close_theme_modal")}
    >
      <div
        class={[
          "bg-white rounded-2xl shadow-2xl max-w-2xl w-full mx-4 transform transition-all duration-300",
          @show && "scale-100 opacity-100",
          !@show && "scale-95 opacity-0"
        ]}
        phx-click="close_theme_modal"
      >
        <!-- Header -->
        <div class="p-6 border-b border-gray-200">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-2xl font-bold text-gray-900">Choose Your Theme</h2>
              <p class="text-gray-600 mt-1">Customize the look and feel of Rachel</p>
            </div>
            <button
              phx-click="close_theme_modal"
              class="p-2 hover:bg-gray-100 rounded-lg transition-colors"
            >
              <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        </div>
        
        <!-- Theme Options -->
        <div class="p-6 space-y-4">
          <%= for theme <- @themes do %>
            <.theme_option_detailed 
              theme={theme} 
              is_current={theme.id == @current_theme}
            />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Private components
  
  defp theme_option(assigns) do
    ~H"""
    <button
      phx-click="change_theme"
      phx-value-theme={@theme.id}
      class={[
        "w-full p-3 rounded-xl border-2 transition-all duration-200 hover:bg-gray-50 text-left",
        @is_current && "border-blue-500 bg-blue-50",
        !@is_current && "border-gray-200 hover:border-gray-300"
      ]}
    >
      <div class="flex items-center gap-3">
        <!-- Color preview -->
        <div class="flex gap-1">
          <%= for color <- @theme.preview_colors do %>
            <div 
              class="w-4 h-4 rounded-full"
              style={"background-color: #{color}"}
            >
            </div>
          <% end %>
        </div>
        
        <!-- Theme info -->
        <div class="flex-1">
          <div class="font-medium text-gray-900">{@theme.name}</div>
          <div class="text-sm text-gray-600">{@theme.description}</div>
        </div>
        
        <!-- Current indicator -->
        <%= if @is_current do %>
          <div class="w-5 h-5 text-blue-500">
            <svg fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
            </svg>
          </div>
        <% end %>
      </div>
    </button>
    """
  end

  defp theme_option_detailed(assigns) do
    ~H"""
    <button
      phx-click="change_theme"
      phx-value-theme={@theme.id}
      class={[
        "w-full p-6 rounded-2xl border-2 transition-all duration-200 hover:scale-[1.02] text-left group",
        @is_current && "border-blue-500 bg-blue-50 shadow-lg",
        !@is_current && "border-gray-200 hover:border-gray-300 hover:shadow-md"
      ]}
    >
      <div class="flex items-start gap-4">
        <!-- Large color preview -->
        <div class="flex flex-col gap-2">
          <%= for color <- @theme.preview_colors do %>
            <div 
              class="w-8 h-8 rounded-lg shadow-sm"
              style={"background-color: #{color}"}
            >
            </div>
          <% end %>
        </div>
        
        <!-- Theme details -->
        <div class="flex-1">
          <h3 class="text-xl font-bold text-gray-900 mb-2">{@theme.name}</h3>
          <p class="text-gray-600 mb-3">{@theme.description}</p>
          
          <!-- Sample UI elements -->
          <div class="flex items-center gap-2">
            <div class="px-3 py-1 bg-blue-500 text-white text-sm rounded-lg">Sample Button</div>
            <div class="px-3 py-1 bg-gray-100 text-gray-700 text-sm rounded-lg">Card</div>
          </div>
        </div>
        
        <!-- Selection indicator -->
        <div class={[
          "w-6 h-6 rounded-full border-2 flex items-center justify-center transition-colors",
          @is_current && "border-blue-500 bg-blue-500",
          !@is_current && "border-gray-300 group-hover:border-blue-300"
        ]}>
          <%= if @is_current do %>
            <svg class="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
            </svg>
          <% end %>
        </div>
      </div>
    </button>
    """
  end

  # JavaScript helpers

  defp toggle_theme_menu do
    JS.toggle(
      to: "#theme-menu",
      in: {"ease-out duration-200", "opacity-0 scale-95", "opacity-100 scale-100"},
      out: {"ease-in duration-150", "opacity-100 scale-100", "opacity-0 scale-95"}
    )
  end

  defp hide_theme_menu do
    JS.hide(
      to: "#theme-menu",
      transition: {"ease-in duration-150", "opacity-100 scale-100", "opacity-0 scale-95"}
    )
  end

  @doc """
  Returns the list of available themes.
  """
  def available_themes, do: @themes

  @doc """
  Gets theme info by ID.
  """
  def get_theme(theme_id) do
    Enum.find(@themes, &(&1.id == theme_id))
  end
end