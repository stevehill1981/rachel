// SpectatorDashboard hook for enhanced spectator experience
export const SpectatorDashboard = {
  mounted() {
    this.commentaryFeed = this.el.querySelector('#commentary-feed');
    this.showCards = false;
    this.showStats = false;
    
    // Auto-scroll commentary feed to latest comment
    this.scrollToLatest();
    
    // Set up periodic updates for dynamic elements
    this.updateInterval = setInterval(() => {
      this.updateTimestamps();
    }, 1000);
    
    // Add keyboard shortcuts for spectator controls
    this.handleKeyboard = (e) => {
      if (e.target.tagName.toLowerCase() === 'input') return;
      
      switch(e.key) {
        case 'c':
        case 'C':
          e.preventDefault();
          this.toggleCards();
          break;
        case 's':
        case 'S':
          e.preventDefault();
          this.toggleStats();
          break;
        case 'r':
        case 'R':
          e.preventDefault();
          this.refreshView();
          break;
      }
    };
    
    document.addEventListener('keydown', this.handleKeyboard);
    
    // Handle spectator control events
    this.handleEvent("toggle_cards", () => {
      this.toggleCards();
    });
    
    this.handleEvent("toggle_stats", () => {
      this.toggleStats();
    });
    
    // Handle new commentary
    this.handleEvent("new_commentary", (data) => {
      this.addCommentary(data.comment);
    });
    
    // Visual enhancements
    this.addVisualEffects();
  },
  
  updated() {
    // Scroll to latest commentary when new content is added
    this.scrollToLatest();
    
    // Refresh visual effects
    this.addVisualEffects();
  },
  
  destroyed() {
    clearInterval(this.updateInterval);
    document.removeEventListener('keydown', this.handleKeyboard);
  },
  
  toggleCards() {
    this.showCards = !this.showCards;
    this.pushEvent('spectator_toggle_cards', { show: this.showCards });
    
    // Visual feedback
    this.showToast(this.showCards ? 'Cards shown' : 'Cards hidden');
  },
  
  toggleStats() {
    this.showStats = !this.showStats;
    this.pushEvent('spectator_toggle_stats', { show: this.showStats });
    
    // Visual feedback
    this.showToast(this.showStats ? 'Statistics shown' : 'Statistics hidden');
  },
  
  refreshView() {
    this.pushEvent('spectator_refresh', {});
    this.showToast('View refreshed');
  },
  
  scrollToLatest() {
    if (this.commentaryFeed) {
      // Smooth scroll to the top (latest comments are at top)
      this.commentaryFeed.scrollTo({
        top: 0,
        behavior: 'smooth'
      });
    }
  },
  
  addCommentary(comment) {
    if (!this.commentaryFeed) return;
    
    // Create new comment element
    const commentEl = document.createElement('div');
    commentEl.className = 'p-2 rounded-lg text-sm bg-blue-500/20 border border-blue-400/30 animation-slide-in';
    
    const timestamp = new Date().toLocaleTimeString('en-US', { 
      hour12: false,
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    });
    
    commentEl.innerHTML = `
      <span class="text-gray-300 text-xs mr-2">${timestamp}</span>
      <span class="text-white">${this.escapeHtml(comment)}</span>
    `;
    
    // Add to top of feed
    this.commentaryFeed.insertBefore(commentEl, this.commentaryFeed.firstChild);
    
    // Animate in
    commentEl.style.opacity = '0';
    commentEl.style.transform = 'translateY(-10px)';
    
    requestAnimationFrame(() => {
      commentEl.style.transition = 'all 0.3s ease-out';
      commentEl.style.opacity = '1';
      commentEl.style.transform = 'translateY(0)';
    });
    
    // Remove old comments to prevent memory issues
    const comments = this.commentaryFeed.children;
    if (comments.length > 50) {
      for (let i = comments.length - 1; i >= 50; i--) {
        comments[i].remove();
      }
    }
    
    // Update older comment styling
    Array.from(comments).forEach((comment, index) => {
      if (index > 0) {
        comment.className = comment.className.replace('bg-blue-500/20 border border-blue-400/30', 'bg-white/5');
      }
    });
  },
  
  updateTimestamps() {
    const timestamps = this.el.querySelectorAll('[data-timestamp]');
    timestamps.forEach(el => {
      const timestamp = new Date(el.dataset.timestamp);
      const now = new Date();
      const diff = Math.floor((now - timestamp) / 1000);
      
      let timeStr;
      if (diff < 60) {
        timeStr = `${diff}s ago`;
      } else if (diff < 3600) {
        timeStr = `${Math.floor(diff / 60)}m ago`;
      } else {
        timeStr = timestamp.toLocaleTimeString('en-US', { 
          hour12: false,
          hour: '2-digit',
          minute: '2-digit'
        });
      }
      
      el.textContent = timeStr;
    });
  },
  
  addVisualEffects() {
    // Add pulse effect to current player indicators
    const currentPlayerElements = this.el.querySelectorAll('[data-current-player="true"]');
    currentPlayerElements.forEach(el => {
      el.classList.add('animate-pulse');
    });
    
    // Add excitement-based visual effects
    const excitementLevel = this.el.dataset.excitement;
    const dashboard = this.el.querySelector('.spectator-dashboard');
    
    if (dashboard) {
      dashboard.classList.remove('excitement-low', 'excitement-medium', 'excitement-high', 'excitement-extreme');
      
      if (excitementLevel) {
        dashboard.classList.add(`excitement-${excitementLevel}`);
      }
    }
  },
  
  showToast(message) {
    // Create toast notification
    const toast = document.createElement('div');
    toast.className = 'fixed top-4 right-4 bg-blue-600 text-white px-4 py-2 rounded-lg shadow-lg z-50 transition-all duration-300';
    toast.textContent = message;
    
    document.body.appendChild(toast);
    
    // Animate in
    requestAnimationFrame(() => {
      toast.style.transform = 'translateX(0)';
      toast.style.opacity = '1';
    });
    
    // Remove after 3 seconds
    setTimeout(() => {
      toast.style.transform = 'translateX(100%)';
      toast.style.opacity = '0';
      
      setTimeout(() => {
        if (toast.parentNode) {
          toast.parentNode.removeChild(toast);
        }
      }, 300);
    }, 3000);
  },
  
  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
};