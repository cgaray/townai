module DocumentsHelper
  def status_badge(status)
    badge_class = case status.to_s
    when "complete" then "badge-success"
    when "failed" then "badge-error"
    when "pending" then "badge-ghost"
    else "badge-warning"
    end

    icon_name = status_icon_name(status)
    icon_class = status.to_s.match?(/extracting/) ? "animate-spin-slow" : ""

    content_tag :span, class: "badge badge-with-icon #{badge_class}" do
      concat icon(icon_name, size: "w-3.5 h-3.5", class: icon_class)
      concat content_tag(:span, status.to_s.humanize)
    end
  end

  def status_icon_name(status)
    case status.to_s
    when "complete" then "check-circle"
    when "failed" then "x-circle"
    when "pending" then "clock-pending"
    else "arrow-path"
    end
  end

  def status_color(status)
    case status.to_s
    when "complete" then "text-success"
    when "failed" then "text-error"
    when "pending" then "text-base-content/50"
    else "text-warning"
    end
  end

  def status_bg(status)
    case status.to_s
    when "complete" then "bg-success/10"
    when "failed" then "bg-error/10"
    when "pending" then "bg-base-200"
    else "bg-warning/10"
    end
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

  def action_badge(action)
    return nil if action.blank?

    badge_class = case action.to_s.downcase
    when "approved" then "badge-success"
    when "denied" then "badge-error"
    when "tabled", "continued" then "badge-warning"
    else "badge-ghost"
    end

    icon_name = case action.to_s.downcase
    when "approved" then "check-circle"
    when "denied" then "x-circle"
    when "tabled" then "pause-circle"
    when "continued" then "arrow-path"
    else nil
    end

    content_tag :span, class: "badge badge-sm badge-with-icon #{badge_class}" do
      if icon_name
        concat icon(icon_name, size: "w-3 h-3")
      end
      concat content_tag(:span, action.to_s.capitalize)
    end
  end

  def action_border_class(action)
    case action.to_s.downcase
    when "approved" then "border-l-approved"
    when "denied" then "border-l-denied"
    when "tabled", "continued" then "border-l-tabled"
    else ""
    end
  end

  def role_badge(role)
    return nil if role.blank?

    badge_class = case role.to_s.downcase
    when "chair" then "badge-primary"
    when "clerk" then "badge-secondary"
    when "staff" then "badge-accent"
    else "badge-ghost"
    end

    content_tag :span, role.to_s.capitalize, class: "badge badge-sm badge-outline #{badge_class}"
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
end
