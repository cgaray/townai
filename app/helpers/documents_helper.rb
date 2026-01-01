module DocumentsHelper
  # Section header with icon and optional count badge
  def section_header(title, icon_name: nil, count: nil, icon_class: "text-primary")
    content_tag :h2, class: "text-xl font-bold flex items-center gap-2" do
      concat icon(icon_name, size: "w-5 h-5", class: icon_class) if icon_name
      concat title
      concat content_tag(:span, count, class: "badge badge-ghost badge-sm font-normal") if count
    end
  end

  # Document type badge for timeline items
  def document_type_badge(doc_type)
    badge_class = case doc_type.to_s.downcase
    when "agenda" then "badge-primary"
    when "minutes" then "badge-secondary"
    else "badge-ghost"
    end

    icon_name = doc_type.to_s.downcase == "minutes" ? "document-text" : "list-bullet"

    content_tag :span, class: "badge px-2.5 py-2.5 gap-1.5 #{badge_class}" do
      concat icon(icon_name, size: "w-3 h-3")
      concat(doc_type&.capitalize || "Document")
    end
  end

  # Status configuration for document processing states
  # Uses DaisyUI badge-soft for subtle colored backgrounds
  STATUS_CONFIG = {
    "complete" => { badge: "badge-soft badge-success", icon: "check-circle" },
    "failed" => { badge: "badge-soft badge-error", icon: "x-circle" },
    "pending" => { badge: "badge-ghost", icon: "clock-pending" }
  }.freeze

  DEFAULT_STATUS_CONFIG = { badge: "badge-soft badge-warning", icon: "arrow-path" }.freeze

  def status_badge(status)
    config = STATUS_CONFIG[status.to_s] || DEFAULT_STATUS_CONFIG
    is_extracting = status.to_s.match?(/extracting/)

    content_tag :span, class: "badge badge-sm #{config[:badge]}" do
      if is_extracting
        concat content_tag(:span, "", class: "loading loading-spinner loading-xs")
      else
        concat icon(config[:icon], size: "size-[1em]")
      end
      concat status.to_s.humanize
    end
  end

  def status_icon_name(status)
    config = STATUS_CONFIG[status.to_s] || DEFAULT_STATUS_CONFIG
    config[:icon]
  end

  def document_type_icon(type, size: :md)
    icon_name = case type.to_s.downcase
    when "agenda" then "agenda"
    when "minutes" then "minutes"
    else "document"
    end

    icon_in_circle(icon_name, type: type, size: size)
  end

  def document_type_border_class(type)
    case type.to_s.downcase
    when "agenda" then "border-t-agenda"
    when "minutes" then "border-t-minutes"
    else "border-t-default"
    end
  end

  def role_badge(role)
    return nil if role.blank?

    # Highlight common leadership roles, otherwise use neutral styling
    badge_class = case role.to_s.downcase
    when "chair", "chairman", "chairwoman", "chairperson" then "badge-primary"
    when "vice-chair", "vice chair", "vice-chairman" then "badge-primary"
    when "clerk", "secretary" then "badge-secondary"
    when "staff" then "badge-accent"
    else "badge-ghost"
    end

    # Titleize the role for display, but handle hyphenated roles
    display_role = role.to_s.split(/[-\s]/).map(&:capitalize).join(" ").gsub(" - ", "-")

    content_tag :span, display_role, class: "badge badge-sm badge-outline #{badge_class}"
  end

  def avatar_initials(name)
    return "?" if name.blank?

    parts = name.to_s.split
    if parts.length >= 2
      "#{parts.first[0]}#{parts.last[0]}".upcase
    else
      name[0..1].upcase
    end
  end

  def avatar_color_class(name)
    return "bg-base-300 text-base-content" if name.blank?

    colors = [
      "bg-primary/20 text-primary",
      "bg-secondary/20 text-secondary",
      "bg-accent/20 text-accent",
      "bg-info/20 text-info",
      "bg-success/20 text-success",
      "bg-warning/20 text-warning"
    ]

    # Use a hash of the name to consistently assign the same color
    index = name.to_s.bytes.sum % colors.length
    colors[index]
  end

  # Returns the DaisyUI size class for avatars
  # :sm = w-8 (32px), :md = w-10 (40px), :lg = w-12 (48px), :xl = w-16 (64px)
  def avatar_size_class(size)
    case size
    when :sm then "w-8 text-xs"
    when :lg then "w-12 text-base"
    when :xl then "w-16 text-lg"
    else "w-10 text-sm"  # :md default
    end
  end

  # Renders a DaisyUI avatar with initials
  # Uses DaisyUI's avatar-placeholder which handles centering automatically
  def avatar(name, size: :md)
    size_class = avatar_size_class(size)
    color_class = avatar_color_class(name)
    initials = avatar_initials(name)

    content_tag :div, class: "avatar avatar-placeholder" do
      content_tag :div, class: "#{color_class} #{size_class} rounded-full" do
        content_tag :span, initials
      end
    end
  end
end
