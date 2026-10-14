module IconHelper
  ICONS = {
    people: <<~SVG,
      <circle cx="7" cy="8.4" r="2"/>
      <path d="M3.6 16.7c.35-2.15 1.6-3.35 3.4-3.35 1.1 0 2.05.5 2.7 1.35"/>
      <circle cx="17" cy="8.4" r="2"/>
      <path d="M14.3 14.7c.65-.85 1.6-1.35 2.7-1.35 1.8 0 3.05 1.2 3.4 3.35"/>
      <circle cx="12" cy="7.3" r="2.4"/>
      <path d="M7.3 17.4c.5-2.55 2.15-3.95 4.7-3.95s4.2 1.4 4.7 3.95"/>
    SVG
    calendar: <<~SVG,
      <rect x="4" y="6" width="16" height="14" rx="2"/>
      <path d="M8 4v4M16 4v4M4 10h16"/>
      <path d="M8 14h2.2M12.2 14h2.2M8 17h2.2"/>
    SVG
    clipboard: <<~SVG,
      <rect x="6" y="5.5" width="12" height="15" rx="2"/>
      <rect x="9" y="3.2" width="6" height="4" rx="1"/>
      <path d="M9 11.2h6M9 14.2h6M9 17.2h4"/>
    SVG
    sliders: <<~SVG,
      <path d="M5 7h14M5 12h14M5 17h14"/>
      <circle cx="9" cy="7" r="1.7"/>
      <circle cx="15" cy="12" r="1.7"/>
      <circle cx="11" cy="17" r="1.7"/>
    SVG
    folder: <<~SVG,
      <path d="M3.8 9h6.1l1.6 2.1H20.2v8.2a1.6 1.6 0 0 1-1.6 1.6H5.4A1.6 1.6 0 0 1 3.8 19.3V9z"/>
      <path d="M3.8 9V7.6A1.6 1.6 0 0 1 5.4 6h4.2l1.4 1.8"/>
    SVG
    cards: <<~SVG,
      <rect x="7.2" y="6.2" width="12.2" height="13.5" rx="1.6"/>
      <path d="M6.2 8.2V7.4A1.6 1.6 0 0 1 7.8 5.8h9"/>
      <rect x="4.6" y="4.4" width="12.2" height="13.5" rx="1.6"/>
    SVG
    chart: <<~SVG,
      <path d="M5 19V11.5M10 19V7M15 19v-6.5M20 19V9"/>
    SVG
    bell: <<~SVG,
      <path d="M6.2 16.8h11.6l-1.1-1.2V11a4.7 4.7 0 0 0-9.4 0v4.6z"/>
      <path d="M10.2 16.8a1.8 1.8 0 0 0 3.6 0"/>
      <path d="M12 4.2V5.4"/>
    SVG
    warning: <<~SVG,
      <path d="M12 4.2 21.2 19.6H2.8L12 4.2z"/>
      <path d="M12 10v5"/>
      <circle cx="12" cy="17.4" r="0.85" fill="currentColor" stroke="none"/>
    SVG
    lock: <<~SVG,
      <rect x="6" y="10.8" width="12" height="9" rx="1.7"/>
      <path d="M8.4 10.8V8.2a3.6 3.6 0 0 1 7.2 0v2.6"/>
    SVG
    sync: <<~SVG,
      <path d="M16.8 7.2A6.8 6.8 0 0 1 12 19"/>
      <path d="M7.2 16.8A6.8 6.8 0 0 1 12 5"/>
      <path d="M16.2 4.2v3.2h3.2"/>
      <path d="M7.8 19.8v-3.2H4.6"/>
    SVG
    share: <<~SVG,
      <circle cx="6.2" cy="12" r="2.1"/>
      <circle cx="17.4" cy="6.4" r="2.1"/>
      <circle cx="17.4" cy="17.6" r="2.1"/>
      <path d="M8.2 11.2 15.4 7.4M8.2 12.8l7.2 3.8"/>
    SVG
    check: <<~SVG,
      <circle cx="12" cy="12" r="8.2"/>
      <path d="M8.2 12.2 10.8 14.8 15.8 9.4"/>
    SVG
    mail: <<~SVG,
      <rect x="3.5" y="6.5" width="17" height="11.5" rx="1.8"/>
      <path d="M4.2 7.8 12 13.2 19.8 7.8"/>
    SVG
    chat: <<~SVG,
      <path d="M5 6.5h14a1.8 1.8 0 0 1 1.8 1.8v8.2A1.8 1.8 0 0 1 19 18.3h-5.2L8.4 21.2v-2.9H5A1.8 1.8 0 0 1 3.2 16.5V8.3A1.8 1.8 0 0 1 5 6.5z"/>
      <path d="M8 11h8M8 14h5"/>
    SVG
    pin: <<~SVG,
      <path d="M12 21s6.2-6.1 6.2-10.4A6.2 6.2 0 0 0 5.8 10.6C5.8 14.9 12 21 12 21z"/>
      <circle cx="12" cy="10.4" r="2.1"/>
    SVG
    user: <<~SVG,
      <circle cx="12" cy="8" r="3.2"/>
      <path d="M5.2 19c.6-3.2 2.8-5 6.8-5s6.2 1.8 6.8 5"/>
    SVG
    eye: <<~SVG,
      <path d="M2.6 12s3.6-6.4 9.4-6.4S21.4 12 21.4 12 17.8 18.4 12 18.4 2.6 12 2.6 12z"/>
      <circle cx="12" cy="12" r="3"/>
    SVG
    eye_off: <<~SVG,
      <path d="M3.2 3.2 20.8 20.8"/>
      <path d="M9.1 5.3A10.6 10.6 0 0 1 12 5.6c5.8 0 9.4 6.4 9.4 6.4a16 16 0 0 1-3.3 3.9"/>
      <path d="M6.1 7.8A16 16 0 0 0 2.6 12s3.6 6.4 9.4 6.4c1.1 0 2.2-.2 3.2-.6"/>
      <path d="M9.9 9.9A3 3 0 0 0 14 14"/>
    SVG
    moon: <<~SVG,
      <path d="M16.2 3.4A8.6 8.6 0 1 0 20.6 16.2 6.6 6.6 0 0 1 16.2 3.4z"/>
    SVG
    sun: <<~SVG,
      <circle cx="12" cy="12" r="3.6"/>
      <path d="M12 3.2v2.2M12 18.6v2.2M4.8 4.8l1.6 1.6M17.6 17.6l1.6 1.6M3.2 12h2.2M18.6 12h2.2M4.8 19.2l1.6-1.6M17.6 6.4l1.6-1.6"/>
    SVG
    arrow: <<~SVG,
      <path d="M5 12h12.4"/>
      <path d="M13.2 6.4 19.6 12l-6.4 5.6"/>
    SVG
    search: <<~SVG,
      <circle cx="11" cy="11" r="6.2"/>
      <path d="M16 16.4 20.2 20.6"/>
    SVG
    target: <<~SVG,
      <circle cx="12" cy="12" r="8.2"/>
      <circle cx="12" cy="12" r="4.4"/>
      <circle cx="12" cy="12" r="1.2" fill="currentColor" stroke="none"/>
      <path d="M12 3.8v2.4M12 17.8v2.4M3.8 12h2.4M17.8 12h2.4"/>
    SVG
  }.freeze

  IMAGE_ICONS = {
    monitoring: { file: "monitoring-icon.png", alt: "" },
    clipboard: { file: "activities-icon.png", alt: "" },
    activities: { file: "activities-icon.png", alt: "" },
    diary: { file: "diary-icon.png", alt: "" },
    diario: { file: "diary-icon.png", alt: "" },
    classrooms: { file: "classrooms-icon.png", alt: "" },
    turmas: { file: "classrooms-icon.png", alt: "" },
    students: { file: "students-icon.png", alt: "" },
    alunos: { file: "students-icon.png", alt: "" },
    target: { file: "projects-icon.png", alt: "" },
    projects: { file: "projects-icon.png", alt: "" },
    courses: { file: "courses-icon.png", alt: "" },
    cursos: { file: "courses-icon.png", alt: "" },
    share: { file: "siage-icon.png", alt: "" },
    siage: { file: "siage-icon.png", alt: "" },
    bell: { file: "notices-icon.png", alt: "" },
    avisos: { file: "notices-icon.png", alt: "" },
    notices: { file: "notices-icon.png", alt: "" }
  }.freeze

  def maestro_icon(name, html_class: nil, size: nil)
    key = name.to_s.to_sym
    classes = [
      "maestro-icon",
      ("maestro-icon-#{size}" if size),
      html_class
    ].compact.join(" ")

    if (image = IMAGE_ICONS[key])
      return image_tag(
        image[:file],
        class: "#{classes} maestro-icon-image maestro-icon-#{key}",
        alt: image[:alt],
        aria: { hidden: true }
      )
    end

    inner = ICONS[key]
    return if inner.blank?

    content_tag(:span, class: classes, "aria-hidden": true) do
      raw(
        %(<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" ) +
          %(stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round">) +
          inner +
          %(</svg>)
      )
    end
  end
end
