// SuitSelector hook for keyboard navigation and accessibility
export const SuitSelector = {
  mounted() {
    this.currentIndex = 0;
    this.buttons = this.el.querySelectorAll('button[data-suit]');
    
    // Focus the first button
    if (this.buttons.length > 0) {
      this.buttons[0].focus();
    }
    
    // Handle keyboard navigation
    this.handleKeydown = (e) => {
      switch(e.key) {
        case 'ArrowRight':
        case 'ArrowDown':
          e.preventDefault();
          this.moveToNext();
          break;
        case 'ArrowLeft':
        case 'ArrowUp':
          e.preventDefault();
          this.moveToPrevious();
          break;
        case 'Enter':
        case ' ':
          e.preventDefault();
          this.selectCurrent();
          break;
        case 'Escape':
          e.preventDefault();
          // Could add escape functionality if needed
          break;
        case '1':
          e.preventDefault();
          this.selectSuit('hearts');
          break;
        case '2':
          e.preventDefault();
          this.selectSuit('diamonds');
          break;
        case '3':
          e.preventDefault();
          this.selectSuit('clubs');
          break;
        case '4':
          e.preventDefault();
          this.selectSuit('spades');
          break;
      }
    };
    
    document.addEventListener('keydown', this.handleKeydown);
    
    // Trap focus within the dialog
    this.trapFocus();
  },
  
  destroyed() {
    document.removeEventListener('keydown', this.handleKeydown);
  },
  
  moveToNext() {
    this.currentIndex = (this.currentIndex + 1) % this.buttons.length;
    this.updateFocus();
  },
  
  moveToPrevious() {
    this.currentIndex = (this.currentIndex - 1 + this.buttons.length) % this.buttons.length;
    this.updateFocus();
  },
  
  updateFocus() {
    // Update tabindex and focus
    this.buttons.forEach((button, index) => {
      button.tabIndex = index === this.currentIndex ? 0 : -1;
      button.setAttribute('aria-checked', index === this.currentIndex ? 'true' : 'false');
    });
    
    this.buttons[this.currentIndex].focus();
  },
  
  selectCurrent() {
    this.buttons[this.currentIndex].click();
  },
  
  selectSuit(suit) {
    const button = this.el.querySelector(`button[data-suit="${suit}"]`);
    if (button) {
      button.click();
    }
  },
  
  trapFocus() {
    // Get all focusable elements within the dialog
    const focusableElements = this.el.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    
    if (focusableElements.length === 0) return;
    
    const firstElement = focusableElements[0];
    const lastElement = focusableElements[focusableElements.length - 1];
    
    this.el.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') {
        if (e.shiftKey) {
          // Shift + Tab
          if (document.activeElement === firstElement) {
            e.preventDefault();
            lastElement.focus();
          }
        } else {
          // Tab
          if (document.activeElement === lastElement) {
            e.preventDefault();
            firstElement.focus();
          }
        }
      }
    });
  }
};