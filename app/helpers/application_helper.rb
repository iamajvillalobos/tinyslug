module ApplicationHelper
  # Header nav link with hover/current-page underline states per the design spec.
  def nav_link_to(name, path, extra_class: nil)
    state =
      if current_page?(path)
        "text-hyperlink underline"
      else
        "text-ink-muted hover:text-hyperlink hover:underline"
      end

    link_to name, path, class: [
      "text-sm underline-offset-[3px] transition-colors duration-150",
      state,
      extra_class
    ].compact.join(" ")
  end
end
