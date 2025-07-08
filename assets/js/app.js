// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Import custom hooks
import { TouchCard } from "./touch_card_hook"
import { SuitSelector } from "./suit_selector_hook"
import { SpectatorDashboard } from "./spectator_dashboard_hook"
import { ThemeManager } from "./theme_manager_hook"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Hooks for custom client-side behavior
const Hooks = {
  TouchCard,
  SuitSelector,
  SpectatorDashboard,
  ThemeManager,
  
  // Button debouncing to prevent double-clicks and improve reliability
  ClickDebounce: {
    mounted() {
      this.lastClick = 0
      this.debounceMs = parseInt(this.el.dataset.debounce) || 500
      
      this.el.addEventListener('click', (e) => {
        const now = Date.now()
        if (now - this.lastClick < this.debounceMs) {
          e.preventDefault()
          e.stopImmediatePropagation()
          console.log('Click debounced')
          return false
        }
        this.lastClick = now
        
        // Add visual feedback
        this.el.style.opacity = '0.7'
        setTimeout(() => {
          if (this.el) this.el.style.opacity = '1'
        }, 200)
      }, true) // Use capture to ensure we get the event first
    }
  },
  
  // Connection status indicator to help debug reliability issues
  ConnectionStatus: {
    mounted() {
      this.updateStatus('connecting')
      
      // Listen for LiveSocket connection events
      window.addEventListener('phx:live_socket_connected', () => {
        this.updateStatus('connected')
      })
      
      window.addEventListener('phx:live_socket_disconnected', () => {
        this.updateStatus('disconnected')
      })
      
      window.addEventListener('phx:live_socket_error', () => {
        this.updateStatus('error')
      })
    },
    
    updateStatus(status) {
      this.el.className = `connection-status connection-status-${status}`
      this.el.title = `Connection: ${status}`
      
      const indicators = {
        connecting: { text: '●', color: '#f59e0b' }, // yellow
        connected: { text: '●', color: '#10b981' },   // green  
        disconnected: { text: '●', color: '#ef4444' }, // red
        error: { text: '●', color: '#dc2626' }        // dark red
      }
      
      const indicator = indicators[status] || indicators.disconnected
      this.el.textContent = indicator.text
      this.el.style.color = indicator.color
    }
  },
  
  // Simple bridge to convert LiveView events to window events
  ThemeBridge: {
    mounted() {
      this.handleEvent("phx:set-theme", ({theme}) => {
        console.log("ThemeBridge converting LiveView event to window event:", theme);
        
        // Performance monitoring for theme switches
        const start = performance.now();
        
        window.dispatchEvent(new CustomEvent("phx:set-theme", {
          detail: { theme }
        }));
        
        // Measure theme switch performance
        requestAnimationFrame(() => {
          const end = performance.now();
          const duration = end - start;
          
          // Log performance data
          console.log(`Theme switch to ${theme}: ${duration.toFixed(2)}ms`);
          
          // Warning if theme switch is slow
          if (duration > 50) {
            console.warn(`Slow theme switch detected: ${duration.toFixed(2)}ms (target: <16ms for 60fps)`);
          }
          
          // Store performance data for debugging
          if (!window.rachelPerformanceData) {
            window.rachelPerformanceData = [];
          }
          window.rachelPerformanceData.push({
            type: 'theme-switch',
            theme: theme,
            duration: duration,
            timestamp: Date.now()
          });
          
          // Keep only last 20 performance measurements
          if (window.rachelPerformanceData.length > 20) {
            window.rachelPerformanceData = window.rachelPerformanceData.slice(-20);
          }
        });
      });
    }
  },
  
  PlayerName: {
    mounted() {
      // Load saved player name from localStorage
      const savedName = localStorage.getItem('rachel-player-name')
      if (savedName) {
        this.pushEvent("load_saved_name", {name: savedName})
      }
      
      // Save player name to localStorage when it changes
      this.handleEvent("save_player_name", ({name}) => {
        if (name && name.trim()) {
          localStorage.setItem('rachel-player-name', name.trim())
        }
      })
    }
  },
  
  CopyToClipboard: {
    mounted() {
      this.handleEvent("copy_to_clipboard", ({text}) => {
        if (navigator.clipboard && window.isSecureContext) {
          // Use modern clipboard API
          navigator.clipboard.writeText(text).then(() => {
            console.log("Text copied to clipboard:", text)
          }).catch(err => {
            console.error("Failed to copy text: ", err)
            this.fallbackCopy(text)
          })
        } else {
          // Fallback for older browsers or insecure contexts
          this.fallbackCopy(text)
        }
      })
    },
    
    fallbackCopy(text) {
      // Create a temporary textarea element
      const textArea = document.createElement("textarea")
      textArea.value = text
      textArea.style.position = "fixed"
      textArea.style.left = "-999999px"
      textArea.style.top = "-999999px"
      document.body.appendChild(textArea)
      textArea.focus()
      textArea.select()
      
      try {
        document.execCommand('copy')
        console.log("Text copied to clipboard using fallback:", text)
      } catch (err) {
        console.error("Fallback copy failed:", err)
      }
      
      document.body.removeChild(textArea)
    }
  },
  AutoHideFlash: {
    mounted() {
      // Auto-hide flash messages after 5 seconds
      this.timer = setTimeout(() => {
        this.el.classList.add("notification-exit")
        setTimeout(() => {
          this.pushEvent("lv:clear-flash", {key: this.el.id.replace("flash-", "")})
        }, 300)
      }, 5000)
    },
    beforeDestroy() {
      clearTimeout(this.timer)
    }
  },
  
  CardAnimation: {
    mounted() {
      // Only animate on initial mount, not when re-rendering
      if (!this.el.dataset.animated) {
        this.el.dataset.animated = "true"
        this.el.style.opacity = "0"
        this.el.style.transform = "translateY(20px)"
        
        setTimeout(() => {
          this.el.style.transition = "all 0.5s cubic-bezier(0.4, 0, 0.2, 1)"
          this.el.style.opacity = "1"
          this.el.style.transform = "translateY(0)"
        }, this.el.dataset.delay || 0)
      }
    }
  },
  
  WinnerCelebration: {
    mounted() {
      // Prevent duplicate celebrations - only run once per winner
      if (this.el.dataset.celebrated) {
        return
      }
      this.el.dataset.celebrated = 'true'
      
      // Get current theme from document
      const currentTheme = document.documentElement.getAttribute('data-theme') || 'modern-minimalist'
      
      // Theme-specific celebration configurations
      const themeConfigs = {
        'modern-minimalist': {
          colors: ['#007aff', '#4da3ff', '#ffffff', '#f8f9fa'],
          confettiCount: 40,
          animationStyle: 'precise',
          shapes: ['circle', 'square']
        },
        'premium-card-room': {
          colors: ['#d4af37', '#e6c757', '#b8941f', '#ecf0f1'],
          confettiCount: 60,
          animationStyle: 'elegant',
          shapes: ['diamond', 'circle', 'star']
        },
        'warm-social': {
          colors: ['#d2691e', '#f4a460', '#a0522d', '#faf6f2'],
          confettiCount: 80,
          animationStyle: 'bouncy',
          shapes: ['heart', 'circle', 'square']
        }
      }
      
      const config = themeConfigs[currentTheme] || themeConfigs['modern-minimalist']
      
      // Create confetti effect with theme-specific styling
      for (let i = 0; i < config.confettiCount; i++) {
        const confetti = document.createElement('div')
        confetti.className = `confetti confetti-${config.animationStyle}`
        
        // Position and timing
        confetti.style.left = Math.random() * 100 + '%'
        confetti.style.backgroundColor = config.colors[Math.floor(Math.random() * config.colors.length)]
        confetti.style.animationDelay = Math.random() * 3 + 's'
        
        // Theme-specific animation durations
        const baseDuration = config.animationStyle === 'elegant' ? 4 : config.animationStyle === 'bouncy' ? 3 : 2.5
        confetti.style.animationDuration = (Math.random() * 2 + baseDuration) + 's'
        
        // Shape-specific styling
        const shape = config.shapes[Math.floor(Math.random() * config.shapes.length)]
        this.applyShape(confetti, shape)
        
        this.el.appendChild(confetti)
      }
      
      // Add theme-specific celebration messages
      this.addCelebrationMessage(currentTheme)
    },
    
    applyShape(element, shape) {
      switch(shape) {
        case 'circle':
          element.style.borderRadius = '50%'
          break
        case 'diamond':
          element.style.transform = 'rotate(45deg)'
          element.style.borderRadius = '2px'
          break
        case 'star':
          element.innerHTML = '★'
          element.style.backgroundColor = 'transparent'
          element.style.color = element.style.backgroundColor || '#d4af37'
          element.style.fontSize = '12px'
          element.style.textAlign = 'center'
          element.style.lineHeight = '10px'
          break
        case 'heart':
          element.innerHTML = '♥'
          element.style.backgroundColor = 'transparent'
          element.style.color = element.style.backgroundColor || '#d2691e'
          element.style.fontSize = '14px'
          element.style.textAlign = 'center'
          element.style.lineHeight = '10px'
          break
      }
    },
    
    addCelebrationMessage(theme) {
      const messages = {
        'modern-minimalist': ['Victory!', 'Well Played!', 'Success!'],
        'premium-card-room': ['Magnificent!', 'Exquisite Victory!', 'Bravo!'],
        'warm-social': ['Awesome!', 'Great Job!', 'Fantastic!', 'You Rock!']
      }
      
      const themeMessages = messages[theme] || messages['modern-minimalist']
      const message = themeMessages[Math.floor(Math.random() * themeMessages.length)]
      
      const messageEl = document.createElement('div')
      messageEl.className = `celebration-message celebration-message-${theme}`
      messageEl.textContent = message
      messageEl.style.cssText = `
        position: absolute;
        top: 20%;
        left: 50%;
        transform: translateX(-50%);
        font-size: 3rem;
        font-weight: bold;
        color: white;
        text-shadow: 2px 2px 4px rgba(0,0,0,0.5);
        z-index: 1000;
        animation: celebrationMessageBounce 2s ease-in-out;
        pointer-events: none;
      `
      
      this.el.appendChild(messageEl)
      
      // Remove message after animation
      setTimeout(() => {
        if (messageEl.parentNode) {
          messageEl.parentNode.removeChild(messageEl)
        }
      }, 2000)
    },
    
    beforeDestroy() {
      // Reset celebration flag for potential reuse
      if (this.el.dataset.celebrated) {
        delete this.el.dataset.celebrated
      }
    }
  },
  
  SoundEffect: {
    mounted() {
      // Play sound effects for game actions
      const action = this.el.dataset.sound
      if (action && window.AudioContext) {
        // Reuse audio context for better performance
        if (!window.rachelAudioContext) {
          window.rachelAudioContext = new (window.AudioContext || window.webkitAudioContext)()
        }
        
        // Get current theme for theme-specific sounds
        const currentTheme = document.documentElement.getAttribute('data-theme') || 'modern-minimalist'
        
        // Theme-specific sound configurations
        const themeConfigs = {
          'modern-minimalist': {
            waveform: 'sine',
            volume: 0.05,
            frequencies: {
              'card-play': 523.25, // C5 - clean, precise
              'card-draw': 392,    // G4 - subtle
              'win': 783.99,       // G5 - clear victory
              'button-click': 440  // A4 - simple click
            }
          },
          'premium-card-room': {
            waveform: 'triangle',
            volume: 0.08,
            frequencies: {
              'card-play': 261.63, // C4 - deeper, more luxurious
              'card-draw': 329.63, // E4 - rich tone
              'win': 659.25,       // E5 - elegant celebration
              'button-click': 349.23 // F4 - sophisticated
            }
          },
          'warm-social': {
            waveform: 'square',
            volume: 0.07,
            frequencies: {
              'card-play': 587.33, // D5 - bright and friendly
              'card-draw': 493.88, // B4 - warm
              'win': 880,          // A5 - joyful celebration
              'button-click': 523.25 // C5 - upbeat
            }
          }
        }
        
        const config = themeConfigs[currentTheme] || themeConfigs['modern-minimalist']
        const audioContext = window.rachelAudioContext
        const oscillator = audioContext.createOscillator()
        const gainNode = audioContext.createGain()
        
        oscillator.connect(gainNode)
        gainNode.connect(audioContext.destination)
        
        // Configure sound based on theme and action
        oscillator.type = config.waveform
        oscillator.frequency.value = config.frequencies[action] || config.frequencies['button-click']
        gainNode.gain.value = config.volume
        
        // Theme-specific sound durations
        const duration = currentTheme === 'premium-card-room' ? 0.15 : 
                        currentTheme === 'warm-social' ? 0.12 : 0.08
        
        oscillator.start()
        oscillator.stop(audioContext.currentTime + duration)
        
        // Add slight reverb for premium theme
        if (currentTheme === 'premium-card-room') {
          const delay = audioContext.createDelay(0.1)
          const feedback = audioContext.createGain()
          
          delay.delayTime.value = 0.05
          feedback.gain.value = 0.2
          
          oscillator.connect(delay)
          delay.connect(feedback)
          feedback.connect(delay)
          delay.connect(gainNode)
        }
      }
    }
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
  // Improve reliability with better reconnection settings
  reconnectAfterMs: (tries) => {
    // Exponential backoff with jitter: 1s, 2s, 4s, 8s, max 30s
    return Math.min(1000 * Math.pow(2, tries - 1) + Math.random() * 1000, 30000)
  },
  // Increase timeout for slow connections
  timeout: 10000,
  // Better error handling
  onError: (error) => {
    console.error("LiveSocket error:", error)
    window.dispatchEvent(new CustomEvent('phx:live_socket_error'))
  },
  onOpen: () => {
    console.log("LiveSocket connected")
    window.dispatchEvent(new CustomEvent('phx:live_socket_connected'))
  },
  onClose: () => {
    console.log("LiveSocket disconnected")
    window.dispatchEvent(new CustomEvent('phx:live_socket_disconnected'))
  }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

