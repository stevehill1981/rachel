// TouchCard hook for enhanced touch interactions
export const TouchCard = {
  mounted() {
    let touchStartTime = 0;
    let hasMoved = false;
    let startX = 0;
    let startY = 0;
    
    // Touch start handler
    this.el.addEventListener('touchstart', (e) => {
      touchStartTime = Date.now();
      hasMoved = false;
      
      if (e.touches.length === 1) {
        const touch = e.touches[0];
        startX = touch.clientX;
        startY = touch.clientY;
        
        // Add immediate visual feedback
        this.el.classList.add('touching');
        
        // Create ripple effect
        this.createRipple(e.touches[0]);
      }
    }, { passive: true });
    
    // Touch move handler
    this.el.addEventListener('touchmove', (e) => {
      if (e.touches.length === 1) {
        const touch = e.touches[0];
        const deltaX = Math.abs(touch.clientX - startX);
        const deltaY = Math.abs(touch.clientY - startY);
        
        // If moved more than 10px, consider it a scroll/gesture
        if (deltaX > 10 || deltaY > 10) {
          hasMoved = true;
          this.el.classList.remove('touching');
        }
      }
    }, { passive: true });
    
    // Touch end handler
    this.el.addEventListener('touchend', (e) => {
      const touchDuration = Date.now() - touchStartTime;
      
      // Remove visual feedback
      this.el.classList.remove('touching');
      
      // Only trigger if it was a short tap and user didn't move much
      if (!hasMoved && touchDuration < 500) {
        // Prevent the click event from firing (avoid double-tap)
        e.preventDefault();
        
        // Add haptic feedback if available
        if (navigator.vibrate) {
          navigator.vibrate(10); // Very brief vibration
        }
        
        // Trigger the card selection
        const index = this.el.dataset.cardIndex;
        if (index !== undefined) {
          this.pushEvent('select_card', { index });
        }
      }
      
      // Reset state
      hasMoved = false;
    }, { passive: false });
    
    // Handle context menu (long press) to prevent it
    this.el.addEventListener('contextmenu', (e) => {
      e.preventDefault();
    });
  },
  
  createRipple(touch) {
    const rect = this.el.getBoundingClientRect();
    const rippleContainer = this.el.querySelector('.touch-ripple');
    
    if (!rippleContainer) return;
    
    const size = 60;
    const ripple = document.createElement('span');
    ripple.className = 'touch-ripple-effect';
    ripple.style.width = ripple.style.height = size + 'px';
    ripple.style.left = (touch.clientX - rect.left - size / 2) + 'px';
    ripple.style.top = (touch.clientY - rect.top - size / 2) + 'px';
    
    rippleContainer.appendChild(ripple);
    
    // Remove ripple after animation
    setTimeout(() => {
      if (ripple.parentNode) {
        ripple.parentNode.removeChild(ripple);
      }
    }, 600);
  }
};