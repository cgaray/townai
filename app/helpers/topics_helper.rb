# frozen_string_literal: true

module TopicsHelper
  # Action configuration for topic action badges and borders
  ACTION_CONFIG = {
    "approved" => { badge: "badge-success", icon: "check-circle", border: "border-l-approved" },
    "denied" => { badge: "badge-error", icon: "x-circle", border: "border-l-denied" },
    "tabled" => { badge: "badge-warning", icon: "pause-circle", border: "border-l-tabled" },
    "continued" => { badge: "badge-warning", icon: "arrow-path", border: "border-l-tabled" }
  }.freeze

  DEFAULT_ACTION_CONFIG = { badge: "badge-ghost", icon: nil, border: "" }.freeze

  # Renders a badge for the topic's action (approved, denied, tabled, continued)
  def action_badge(action)
    return nil if action.blank?

    config = ACTION_CONFIG[action.to_s.downcase] || DEFAULT_ACTION_CONFIG

    content_tag :span, class: "badge badge-sm badge-with-icon #{config[:badge]}" do
      concat icon(config[:icon], size: "w-3 h-3") if config[:icon]
      concat content_tag(:span, action.to_s.capitalize)
    end
  end

  # Returns the CSS border class for a topic's action
  def action_border_class(action)
    config = ACTION_CONFIG[action.to_s.downcase] || DEFAULT_ACTION_CONFIG
    config[:border]
  end
end
