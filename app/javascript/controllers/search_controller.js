import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "input", "results", "resultsList", "tabs",
    "emptyState", "loading", "noResults",
    "countAll", "countDocuments", "countTopics", "countPeople", "countBodies",
    "viewAllLink"
  ]

  static values = {
    debounceMs: { type: Number, default: 150 }
  }

  connect() {
    this.selectedIndex = -1
    this.currentType = ""
    this.debounceTimer = null
    
    // Listen for Cmd+K / Ctrl+K globally
    this.boundHandleGlobalKeydown = this.handleGlobalKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleGlobalKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleGlobalKeydown)
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
  }

  handleGlobalKeydown(event) {
    // Cmd+K or Ctrl+K to open search
    if ((event.metaKey || event.ctrlKey) && event.key === "k") {
      event.preventDefault()
      this.open()
    }
  }

  open() {
    const modal = this.element
    if (modal.showModal) {
      modal.showModal()
      this.inputTarget.focus()
      this.inputTarget.select()
    }
  }

  close() {
    const modal = this.element
    if (modal.close) {
      modal.close()
    }
  }

  onInput() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    
    this.debounceTimer = setTimeout(() => {
      this.search()
    }, this.debounceMsValue)
  }

  async search() {
    const query = this.inputTarget.value.trim()
    
    if (!query) {
      this.showEmptyState()
      this.resetCounts()
      this.updateViewAllLink("")
      return
    }

    this.showLoading()
    this.updateViewAllLink(query)

    try {
      const params = new URLSearchParams({ q: query })
      if (this.currentType) params.append("type", this.currentType)
      
      const response = await fetch(`/search/quick?${params}`)
      const data = await response.json()
      
      this.updateCounts(data.counts, data.total)
      
      if (data.results.length > 0) {
        this.renderResults(data.results)
      } else {
        this.showNoResults()
      }
    } catch (error) {
      console.error("Search error:", error)
      this.showNoResults()
    }
  }

  updateViewAllLink(query) {
    if (this.hasViewAllLinkTarget) {
      const params = new URLSearchParams()
      if (query) params.append("q", query)
      if (this.currentType) params.append("type", this.currentType)
      const queryString = params.toString()
      this.viewAllLinkTarget.href = `/search${queryString ? '?' + queryString : ''}`
    }
  }

  renderResults(results) {
    this.hideAllStates()
    this.resultsListTarget.classList.remove("hidden")
    
    this.resultsListTarget.innerHTML = results.map((result, index) => 
      this.renderResultItem(result, index)
    ).join("")
    
    this.selectedIndex = -1
  }

  renderResultItem(result, index) {
    const iconName = this.getIconName(result.entity_type)
    const typeLabel = this.getTypeLabel(result.entity_type)
    
    return `
      <a href="${result.url}" 
         class="block p-3 hover:bg-base-200 transition-colors search-result ${index === this.selectedIndex ? 'bg-base-200' : ''}"
         data-index="${index}"
         data-action="mouseenter->search#onResultHover click->search#close">
        <div class="flex items-start gap-3">
          <div class="flex-shrink-0 w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-primary">
              ${this.getIconPath(iconName)}
            </svg>
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2">
              <span class="text-xs text-base-content/50">${typeLabel}</span>
            </div>
            <div class="font-medium text-sm truncate">${this.escapeHtml(result.title)}</div>
            ${result.subtitle ? `<div class="text-xs text-base-content/60 truncate">${this.escapeHtml(result.subtitle)}</div>` : ''}
            ${result.snippet ? `<div class="text-xs text-base-content/70 mt-1 line-clamp-1">${result.snippet}</div>` : ''}
          </div>
        </div>
      </a>
    `
  }

  getIconName(entityType) {
    const icons = {
      document: "document",
      topic: "list",
      person: "user",
      governing_body: "building"
    }
    return icons[entityType] || "document"
  }

  getIconPath(iconName) {
    const paths = {
      document: '<path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />',
      list: '<path stroke-linecap="round" stroke-linejoin="round" d="M8.25 6.75h12M8.25 12h12m-12 5.25h12M3.75 6.75h.007v.008H3.75V6.75Zm.375 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0ZM3.75 12h.007v.008H3.75V12Zm.375 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Zm-.375 5.25h.007v.008H3.75v-.008Zm.375 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z" />',
      user: '<path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0ZM4.501 20.118a7.5 7.5 0 0 1 14.998 0A17.933 17.933 0 0 1 12 21.75c-2.676 0-5.216-.584-7.499-1.632Z" />',
      building: '<path stroke-linecap="round" stroke-linejoin="round" d="M12 21v-8.25M15.75 21v-8.25M8.25 21v-8.25M3 9l9-6 9 6m-1.5 12V10.332A48.36 48.36 0 0 0 12 10c-2.59 0-5.126.203-7.5.597V21m15 0H3m0 0h18" />'
    }
    return paths[iconName] || paths.document
  }

  getTypeLabel(entityType) {
    const labels = {
      document: "Document",
      topic: "Topic",
      person: "Person",
      governing_body: "Governing Body"
    }
    return labels[entityType] || "Result"
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  updateCounts(counts, total) {
    this.countAllTarget.textContent = total
    this.countDocumentsTarget.textContent = counts.document || 0
    this.countTopicsTarget.textContent = counts.topic || 0
    this.countPeopleTarget.textContent = counts.person || 0
    this.countBodiesTarget.textContent = counts.governing_body || 0
  }

  resetCounts() {
    this.countAllTarget.textContent = "0"
    this.countDocumentsTarget.textContent = "0"
    this.countTopicsTarget.textContent = "0"
    this.countPeopleTarget.textContent = "0"
    this.countBodiesTarget.textContent = "0"
  }

  setType(event) {
    const newType = event.currentTarget.dataset.type
    this.currentType = newType
    
    // Update active tab styling
    this.tabsTarget.querySelectorAll("button").forEach(btn => {
      btn.classList.remove("search-tab-active", "btn-primary")
      btn.classList.add("btn-ghost")
    })
    event.currentTarget.classList.add("search-tab-active", "btn-primary")
    event.currentTarget.classList.remove("btn-ghost")
    
    // Update view all link and re-run search with new filter
    this.updateViewAllLink(this.inputTarget.value.trim())
    this.search()
  }

  selectNext() {
    const results = this.resultsListTarget.querySelectorAll(".search-result")
    if (results.length === 0) return
    
    this.selectedIndex = Math.min(this.selectedIndex + 1, results.length - 1)
    this.updateSelection(results)
  }

  selectPrev() {
    const results = this.resultsListTarget.querySelectorAll(".search-result")
    if (results.length === 0) return
    
    this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
    this.updateSelection(results)
  }

  updateSelection(results) {
    results.forEach((result, index) => {
      if (index === this.selectedIndex) {
        result.classList.add("bg-base-200")
        result.scrollIntoView({ block: "nearest" })
      } else {
        result.classList.remove("bg-base-200")
      }
    })
  }

  onResultHover(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    if (!isNaN(index)) {
      this.selectedIndex = index
      const results = this.resultsListTarget.querySelectorAll(".search-result")
      this.updateSelection(results)
    }
  }

  handleKeydown(event) {
    if (event.key === "Enter") {
      if (event.metaKey || event.ctrlKey) {
        // Cmd/Ctrl+Enter: go to full results page
        event.preventDefault()
        this.goToViewAll()
      } else {
        // Enter: go to selected result
        event.preventDefault()
        this.goToSelected()
      }
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.selectPrev()
    } else if (event.key === "ArrowDown") {
      event.preventDefault()
      this.selectNext()
    }
  }

  goToSelected() {
    const results = this.resultsListTarget.querySelectorAll(".search-result")
    if (this.selectedIndex >= 0 && this.selectedIndex < results.length) {
      results[this.selectedIndex].click()
    } else if (results.length > 0) {
      // If nothing selected, go to first result
      results[0].click()
    }
  }

  goToViewAll() {
    if (this.hasViewAllLinkTarget && this.inputTarget.value.trim()) {
      window.location.href = this.viewAllLinkTarget.href
    }
  }

  showEmptyState() {
    this.hideAllStates()
    this.emptyStateTarget.classList.remove("hidden")
  }

  showLoading() {
    this.hideAllStates()
    this.loadingTarget.classList.remove("hidden")
  }

  showNoResults() {
    this.hideAllStates()
    this.noResultsTarget.classList.remove("hidden")
  }

  hideAllStates() {
    this.emptyStateTarget.classList.add("hidden")
    this.loadingTarget.classList.add("hidden")
    this.noResultsTarget.classList.add("hidden")
    this.resultsListTarget.classList.add("hidden")
  }
}
