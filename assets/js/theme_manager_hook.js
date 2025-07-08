// ThemeManager hook for handling theme switching
export const ThemeManager = {
  mounted() {
    // Load saved theme from localStorage
    const savedTheme = localStorage.getItem('rachel-theme') || 'modern-minimalist'
    this.applyTheme(savedTheme)
    
    // Listen for theme change events from LiveView
    this.handleEvent("change_theme", ({theme}) => {
      this.applyTheme(theme)
      localStorage.setItem('rachel-theme', theme)
      
      // Provide visual feedback
      this.showThemeChangeNotification(theme)
    })
    
    // Send current theme to LiveView on mount
    this.pushEvent("theme_loaded", {theme: savedTheme})
  },
  
  applyTheme(themeName) {
    // Apply theme to document root
    document.documentElement.setAttribute('data-theme', themeName)
    
    // Add smooth transition class temporarily
    document.documentElement.classList.add('theme-transitioning')
    
    // Remove transition class after animation completes
    setTimeout(() => {
      document.documentElement.classList.remove('theme-transitioning')
    }, 300)
  },
  
  showThemeChangeNotification(themeName) {
    // Create a temporary notification
    const notification = document.createElement('div')
    notification.className = 'fixed top-4 left-1/2 transform -translate-x-1/2 z-50 px-4 py-2 bg-black/80 text-white rounded-lg text-sm font-medium pointer-events-none opacity-0 transition-opacity duration-200'
    notification.textContent = `Switched to ${this.formatThemeName(themeName)}`
    
    document.body.appendChild(notification)
    
    // Animate in
    requestAnimationFrame(() => {
      notification.style.opacity = '1'
    })
    
    // Animate out and remove after 2 seconds
    setTimeout(() => {
      notification.style.opacity = '0'
      setTimeout(() => {
        if (notification.parentNode) {
          notification.parentNode.removeChild(notification)
        }
      }, 200)
    }, 2000)
  },
  
  formatThemeName(themeName) {
    return themeName
      .split('-')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ')
  }
}

// CSS for smooth theme transitions
const themeTransitionCSS = `
  .theme-transitioning * {
    transition: background-color 0.3s ease, 
                border-color 0.3s ease, 
                color 0.3s ease,
                box-shadow 0.3s ease !important;
  }
`

// Inject transition CSS
const style = document.createElement('style')
style.textContent = themeTransitionCSS
document.head.appendChild(style)