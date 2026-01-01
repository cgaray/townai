# frozen_string_literal: true

module AuditLogsHelper
  # ============================================================================
  # CONFIGURATION CONSTANTS
  # ============================================================================

  # Admin audit log action badges and borders
  # Borders indicate the resource category (blue=user, purple=person, green=document)
  # Badges are neutral (ghost) for routine actions, only colored for destructive/warning actions
  ADMIN_ACTION_CONFIG = {
    # User actions - blue border
    "user_create" => { badge: "badge-ghost", icon: "user-plus", border: "border-l-user-action", label: "User Created" },
    "user_update" => { badge: "badge-ghost", icon: "pencil", border: "border-l-user-action", label: "User Updated" },
    "user_delete" => { badge: "badge-soft badge-error", icon: "user-minus", border: "border-l-user-action", label: "User Deleted" },
    "user_role_change" => { badge: "badge-ghost", icon: "shield-check", border: "border-l-user-action", label: "Role Changed" },
    "user_magic_link" => { badge: "badge-ghost", icon: "link", border: "border-l-user-action", label: "Magic Link Sent" },

    # Person actions - purple border
    "person_merge" => { badge: "badge-ghost", icon: "arrows-right-left", border: "border-l-person-action", label: "Person Merged" },
    "person_unmerge" => { badge: "badge-ghost", icon: "arrow-path", border: "border-l-person-action", label: "Person Unmerged" },
    "person_link" => { badge: "badge-ghost", icon: "link", border: "border-l-person-action", label: "Person Linked" },
    "person_unlink" => { badge: "badge-ghost", icon: "link", border: "border-l-person-action", label: "Person Unlinked" },

    # Document actions - green border
    "document_retry" => { badge: "badge-ghost", icon: "arrow-path", border: "border-l-document-action", label: "Retry" },
    "document_delete" => { badge: "badge-soft badge-error", icon: "trash", border: "border-l-document-action", label: "Deleted" },
    "document_reextract" => { badge: "badge-ghost", icon: "arrow-path", border: "border-l-document-action", label: "Re-extracted" },
    "document_bulk_retry" => { badge: "badge-ghost", icon: "arrow-path", border: "border-l-document-action", label: "Bulk Retry" },
    "document_update" => { badge: "badge-ghost", icon: "pencil", border: "border-l-document-action", label: "Updated" },

    # Topic actions - green border (same as documents)
    "topic_update" => { badge: "badge-ghost", icon: "pencil", border: "border-l-document-action", label: "Topic Updated" },
    "topic_delete" => { badge: "badge-soft badge-error", icon: "trash", border: "border-l-document-action", label: "Topic Deleted" },

    # System actions - no border
    "search_rebuild" => { badge: "badge-ghost", icon: "arrow-path", border: "", label: "Search Index Rebuilt" },
    "index_rebuild" => { badge: "badge-ghost", icon: "arrow-path", border: "", label: "Index Rebuilt" },
    "cache_clear" => { badge: "badge-ghost", icon: "trash", border: "", label: "Cache Cleared" },
    "system_action" => { badge: "badge-ghost", icon: "cog", border: "", label: "System Action" }
  }.freeze

  DEFAULT_ADMIN_CONFIG = { badge: "badge-ghost", icon: "clipboard-document-list", border: "", label: nil }.freeze

  # Authentication log configuration
  AUTH_ACTION_CONFIG = {
    "success" => { badge: "badge-soft badge-success", icon: "check-circle", border: "border-l-auth-success" },
    "failed" => { badge: "badge-soft badge-error", icon: "x-circle", border: "border-l-auth-failed" }
  }.freeze

  DEFAULT_AUTH_CONFIG = { badge: "badge-ghost", icon: "information-circle", border: "" }.freeze

  # Document event log configuration
  DOC_EVENT_CONFIG = {
    "success" => { badge: "badge-soft badge-success", icon: "check-circle", border: "border-l-doc-success" },
    "failure" => { badge: "badge-soft badge-error", icon: "x-circle", border: "border-l-doc-failure" }
  }.freeze

  DEFAULT_DOC_CONFIG = { badge: "badge-ghost", icon: "document", border: "" }.freeze

  # Filter configuration for admin logs
  ADMIN_FILTER_CONFIG = [
    { key: nil, label: "All", icon: nil, active_class: "btn-primary", count_key: :all },
    { key: "user", label: "Users", icon: "users", active_class: "btn-info", count_key: :users },
    { key: "person", label: "People", icon: "identification", active_class: "btn-secondary", count_key: :people },
    { key: "document", label: "Documents", icon: "document", active_class: "btn-success", count_key: :documents }
  ].freeze

  # Filter configuration for auth logs
  AUTH_FILTER_CONFIG = [
    { key: nil, label: "All", icon: nil, active_class: "btn-primary", count_key: :all },
    { key: "success", label: "Success", icon: "check-circle", active_class: "btn-success", count_key: :success },
    { key: "failed", label: "Failed", icon: "x-circle", active_class: "btn-error", count_key: :failed }
  ].freeze

  # Filter configuration for document events
  DOC_EVENT_FILTER_CONFIG = [
    { key: nil, label: "All", icon: nil, active_class: "btn-primary", count_key: :all },
    { key: "success", label: "Success", icon: "check-circle", active_class: "btn-success", count_key: :success },
    { key: "failed", label: "Failed", icon: "x-circle", active_class: "btn-error", count_key: :failed },
    { key: "extraction", label: "Extractions", icon: "arrow-path", active_class: "btn-info", count_key: :extraction }
  ].freeze

  # ============================================================================
  # ADMIN LOG HELPERS
  # ============================================================================

  # Renders a badge for admin audit log actions
  def admin_action_badge(action)
    return nil if action.blank?

    config = ADMIN_ACTION_CONFIG[action.to_s] || DEFAULT_ADMIN_CONFIG
    label = config[:label] || action.to_s.humanize

    content_tag :span, class: "badge badge-sm #{config[:badge]} inline-flex items-center gap-1.5" do
      concat icon(config[:icon], size: "size-[1em]") if config[:icon]
      concat label
    end
  end

  # Returns the CSS border class for an admin action
  def admin_action_border_class(action)
    config = ADMIN_ACTION_CONFIG[action.to_s] || DEFAULT_ADMIN_CONFIG
    config[:border]
  end

  # Renders filter pills for admin logs with icons and counts
  def admin_log_filter_pills(current_filter:, filter_counts:)
    safe_join(
      ADMIN_FILTER_CONFIG.map do |filter|
        filter_pill(
          path: admin_admin_logs_path(action_type: filter[:key]),
          filter: filter,
          current_value: current_filter,
          count: filter_counts[filter[:count_key]] || 0
        )
      end
    )
  end

  # Formats the state/params JSON into a readable description
  def format_log_description(log)
    data = parse_log_data(log.new_state) || parse_log_data(log.params) || parse_log_data(log.previous_state)
    return nil unless data

    case log.action
    when "person_merge"
      "Merged #{data['source_count'] || 'multiple'} records into one"
    when "person_unmerge"
      "Split person back into separate records"
    when "person_link", "person_unlink"
      nil # Just show the resource type
    when "user_role_change"
      "#{data['previous_role']} → #{data['new_role']}" if data["previous_role"] && data["new_role"]
    when "document_retry", "document_reextract"
      data["reason"] if data["reason"]
    end
  end

  # ============================================================================
  # AUTHENTICATION LOG HELPERS
  # ============================================================================

  # Renders a badge for authentication log status
  def auth_status_badge(log)
    status = log.success? ? "success" : (log.failed? ? "failed" : nil)
    config = AUTH_ACTION_CONFIG[status] || DEFAULT_AUTH_CONFIG

    content_tag :span, class: "badge badge-sm #{config[:badge]} inline-flex items-center gap-1.5" do
      concat icon(config[:icon], size: "size-[1em]") if config[:icon]
      concat log.action_display_name
    end
  end

  # Returns the CSS border class for an authentication log
  def auth_status_border_class(log)
    status = log.success? ? "success" : (log.failed? ? "failed" : nil)
    config = AUTH_ACTION_CONFIG[status] || DEFAULT_AUTH_CONFIG
    config[:border]
  end

  # Renders filter pills for auth logs with icons and counts
  def auth_log_filter_pills(current_filter:, filter_counts:)
    safe_join(
      AUTH_FILTER_CONFIG.map do |filter|
        filter_pill(
          path: admin_authentication_logs_path(status: filter[:key]),
          filter: filter,
          current_value: current_filter,
          count: filter_counts[filter[:count_key]] || 0
        )
      end
    )
  end

  # ============================================================================
  # DOCUMENT EVENT LOG HELPERS
  # ============================================================================

  # Renders a badge for document event log status
  def doc_event_badge(log)
    status = log.success? ? "success" : (log.failure? ? "failure" : nil)
    config = DOC_EVENT_CONFIG[status] || DEFAULT_DOC_CONFIG

    content_tag :span, class: "badge badge-sm #{config[:badge]} inline-flex items-center gap-1.5" do
      concat icon(config[:icon], size: "size-[1em]") if config[:icon]
      concat log.event_type.humanize
    end
  end

  # Returns the CSS border class for a document event log
  def doc_event_border_class(log)
    status = log.success? ? "success" : (log.failure? ? "failure" : nil)
    config = DOC_EVENT_CONFIG[status] || DEFAULT_DOC_CONFIG
    config[:border]
  end

  # Renders filter pills for document event logs with icons and counts
  def doc_event_filter_pills(current_filter:, filter_counts:)
    safe_join(
      DOC_EVENT_FILTER_CONFIG.map do |filter|
        filter_pill(
          path: admin_document_events_path(status: filter[:key]),
          filter: filter,
          current_value: current_filter,
          count: filter_counts[filter[:count_key]] || 0
        )
      end
    )
  end

  private

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  def parse_log_data(json_string)
    return nil if json_string.blank?
    JSON.parse(json_string)
  rescue JSON::ParserError
    nil
  end

  def filter_pill(path:, filter:, current_value:, count:)
    is_active = current_value.to_s == filter[:key].to_s
    btn_class = is_active ? filter[:active_class] : "btn-ghost"

    link_to path, class: "btn btn-sm #{btn_class} inline-flex items-center gap-2" do
      concat icon(filter[:icon], size: "w-4 h-4 shrink-0") if filter[:icon]
      concat content_tag(:span, filter[:label])
      concat content_tag(:span, count, class: "opacity-70 text-xs")
    end
  end
end
