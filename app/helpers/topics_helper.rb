# frozen_string_literal: true

module TopicsHelper
  # Action configuration for topic action badges and borders
  # Uses DaisyUI badge-soft for subtle colored backgrounds
  ACTION_CONFIG = {
    "approved" => { badge: "badge-soft badge-success", icon: "check-circle", border: "border-l-approved" },
    "denied" => { badge: "badge-soft badge-error", icon: "x-circle", border: "border-l-denied" },
    "tabled" => { badge: "badge-soft badge-warning", icon: "pause-circle", border: "border-l-tabled" },
    "continued" => { badge: "badge-soft badge-warning", icon: "arrow-path", border: "border-l-tabled" }
  }.freeze

  DEFAULT_ACTION_CONFIG = { badge: "badge-ghost", icon: nil, border: "" }.freeze

  # Filter configuration for the topics timeline
  # Each filter has: label, icon (optional), active_class when selected, and count_key
  FILTER_CONFIG = [
    { key: nil, label: "All", icon: nil, active_class: "btn-primary", count_key: :all },
    { key: "with_actions", label: "With Actions", icon: nil, active_class: "btn-primary", count_key: :with_actions },
    { key: "approved", label: "Approved", icon: "check-circle", active_class: "btn-success", count_key: :approved },
    { key: "denied", label: "Denied", icon: "x-circle", active_class: "btn-error", count_key: :denied },
    { key: "tabled", label: "Tabled", icon: "pause-circle", active_class: "btn-warning", count_key: :tabled },
    { key: "continued", label: "Continued", icon: "arrow-path", active_class: "btn-warning", count_key: :continued }
  ].freeze

  # Renders a badge for the topic's action (approved, denied, tabled, continued)
  def action_badge(action)
    return nil if action.blank?

    config = ACTION_CONFIG[action.to_s.downcase] || DEFAULT_ACTION_CONFIG

    content_tag :span, class: "badge badge-sm #{config[:badge]} inline-flex items-center gap-1.5" do
      concat icon(config[:icon], size: "size-[1em]") if config[:icon]
      concat action.to_s.capitalize
    end
  end

  # Returns the CSS border class for a topic's action
  def action_border_class(action)
    config = ACTION_CONFIG[action.to_s.downcase] || DEFAULT_ACTION_CONFIG
    config[:border]
  end

  # Renders filter pill buttons for the topics timeline
  # Parameters:
  #   - town: the current town for building URLs
  #   - current_action: the currently selected action_taken param
  #   - governing_body_id: current governing_body_id filter (preserved across action changes)
  #   - filter_counts: hash of counts by action type from Topic.filter_counts_for_town
  def topic_filter_pills(town:, current_action:, governing_body_id:, filter_counts:)
    safe_join(
      FILTER_CONFIG.map do |filter|
        topic_filter_pill(
          town: town,
          filter: filter,
          current_action: current_action,
          governing_body_id: governing_body_id,
          count: filter_counts[filter[:count_key]] || 0
        )
      end
    )
  end

  private

  def topic_filter_pill(town:, filter:, current_action:, governing_body_id:, count:)
    is_active = current_action.to_s == filter[:key].to_s
    btn_class = is_active ? filter[:active_class] : "btn-ghost"

    link_to town_topics_path(town, action_taken: filter[:key], governing_body_id: governing_body_id),
            class: "btn btn-sm #{btn_class} inline-flex items-center gap-2" do
      concat icon(filter[:icon], size: "w-4 h-4 shrink-0") if filter[:icon]
      concat content_tag(:span, filter[:label])
      concat content_tag(:span, count, class: "opacity-70 text-xs")
    end
  end
end
