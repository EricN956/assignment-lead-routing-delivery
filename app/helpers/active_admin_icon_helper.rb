module ActiveAdminIconHelper
  def aa_icon_button(path, icon:, label:, method: :get, class_name: "", data: {})
    options = {
      class: "aa-icon-btn #{class_name}".strip,
      title: label,
      aria: { label: label },
      data: data
    }

    options[:method] = method unless method == :get

    link_to path, options do
      aa_svg_icon(icon).html_safe
    end
  end

  def aa_view_button(path)
    aa_icon_button(path, icon: :eye, label: "View")
  end

  def aa_edit_button(path)
    aa_icon_button(path, icon: :pencil, label: "Edit")
  end

  def aa_delete_button(path)
    aa_icon_button(
      path,
      icon: :trash,
      label: "Delete",
      method: :delete,
      class_name: "aa-icon-btn-danger",
      data: { confirm: "Are you sure?" }
    )
  end

  def aa_new_button(path, label = "Create")
    link_to path,
            class: "aa-icon-btn aa-icon-btn-primary aa-icon-btn-large",
            title: label,
            aria: { label: label } do
      aa_svg_icon(:plus).html_safe
    end
  end

  def aa_svg_icon(name)
    case name.to_sym
    when :eye
      <<~SVG
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
             stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M2 12s3.5-6.5 10-6.5S22 12 22 12s-3.5 6.5-10 6.5S2 12 2 12z"></path>
          <circle cx="12" cy="12" r="3"></circle>
        </svg>
      SVG
    when :pencil
      <<~SVG
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
             stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M12 20h9"></path>
          <path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4 12.5-12.5z"></path>
        </svg>
      SVG
    when :trash
      <<~SVG
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
             stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M3 6h18"></path>
          <path d="M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2"></path>
          <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"></path>
          <path d="M10 11v6"></path>
          <path d="M14 11v6"></path>
        </svg>
      SVG
    when :plus
      <<~SVG
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"
             stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M12 5v14"></path>
          <path d="M5 12h14"></path>
        </svg>
      SVG
    else
      ""
    end
  end
end
