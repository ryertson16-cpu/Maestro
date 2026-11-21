module Documents
  module PdfFont
    FAMILY = "MaestroSans"
    VENDOR = Rails.root.join("vendor/fonts/dejavu")
    SYSTEM = Pathname.new("/usr/share/fonts/truetype/dejavu")

    module_function

    def apply(pdf)
      regular = file("DejaVuSans.ttf")
      bold = file("DejaVuSans-Bold.ttf")
      italic = file("DejaVuSans-Oblique.ttf")
      bold_italic = file("DejaVuSans-BoldOblique.ttf")
      return unless regular && bold

      pdf.font_families.update(
        FAMILY => {
          normal: regular.to_s,
          bold: bold.to_s,
          italic: (italic || regular).to_s,
          bold_italic: (bold_italic || bold).to_s
        }
      )
      pdf.font FAMILY
    end

    def file(name)
      [VENDOR.join(name), SYSTEM.join(name)].find { |path| File.file?(path) }
    end
  end
end
