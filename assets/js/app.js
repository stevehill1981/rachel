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

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Hooks for custom client-side behavior
const Hooks = {
  TouchCard,
  SuitSelector,
  SpectatorDashboard,
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
      // Create confetti effect
      const colors = ['#3b82f6', '#8b5cf6', '#ec4899', '#10b981', '#f59e0b']
      const confettiCount = 50
      
      for (let i = 0; i < confettiCount; i++) {
        const confetti = document.createElement('div')
        confetti.className = 'confetti'
        confetti.style.left = Math.random() * 100 + '%'
        confetti.style.backgroundColor = colors[Math.floor(Math.random() * colors.length)]
        confetti.style.animationDelay = Math.random() * 3 + 's'
        confetti.style.animationDuration = (Math.random() * 3 + 2) + 's'
        this.el.appendChild(confetti)
      }
    }
  },
  
  SoundEffect: {
    mounted() {
      // Play sound effects for game actions
      const action = this.el.dataset.sound
      if (action && window.AudioContext) {
        // Simple sound generation (can be replaced with actual sound files)
        const audioContext = new (window.AudioContext || window.webkitAudioContext)()
        const oscillator = audioContext.createOscillator()
        const gainNode = audioContext.createGain()
        
        oscillator.connect(gainNode)
        gainNode.connect(audioContext.destination)
        
        switch(action) {
          case 'card-play':
            oscillator.frequency.value = 523.25 // C5
            gainNode.gain.value = 0.1
            break
          case 'card-draw':
            oscillator.frequency.value = 392 // G4
            gainNode.gain.value = 0.05
            break
          case 'win':
            oscillator.frequency.value = 783.99 // G5
            gainNode.gain.value = 0.15
            break
        }
        
        oscillator.start()
        oscillator.stop(audioContext.currentTime + 0.1)
      }
    }
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
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

