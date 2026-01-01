import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

// Highlight anchor targets on Turbo navigation
// CSS :target only works on full page loads, so we handle Turbo navigations here
document.addEventListener("turbo:load", () => {
  if (window.location.hash) {
    const target = document.querySelector(window.location.hash)
    if (target) {
      target.classList.add("anchor-highlight")
      // Remove the class after animation completes
      setTimeout(() => target.classList.remove("anchor-highlight"), 3000)
    }
  }
})

export { application }
