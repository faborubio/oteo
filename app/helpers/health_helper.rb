module HealthHelper
  # Clases Tailwind COMPLETAS (no interpoladas): el JIT solo genera las que ve literales.
  def quota_level(pct)
    return :critical if pct >= 70
    return :warn if pct >= 40

    :ok
  end

  def quota_text_class(pct)
    { critical: "text-red-700", warn: "text-yellow-700", ok: "text-emerald-700" }.fetch(quota_level(pct))
  end

  def quota_bar_class(pct)
    { critical: "bg-red-500", warn: "bg-yellow-500", ok: "bg-emerald-500" }.fetch(quota_level(pct))
  end

  def sync_status_badge(status)
    color = {
      "success" => "bg-emerald-100 text-emerald-800",
      "failed" => "bg-red-100 text-red-800",
      "running" => "bg-blue-100 text-blue-800",
      "pending" => "bg-gray-100 text-gray-600"
    }.fetch(status, "bg-gray-100 text-gray-600")
    content_tag(:span, status, class: "inline-flex px-2 py-0.5 rounded text-xs font-medium #{color}")
  end
end
