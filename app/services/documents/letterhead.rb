require "tempfile"

module Documents
  class Letterhead
    def initialize(professor)
      @professor = professor
      @tempfiles = []
    end

    def draw(pdf, title:, subtitle: nil, variant: :standard)
      if variant.to_sym == :official
        draw_official(pdf, title: title, subtitle: subtitle)
      else
        draw_standard(pdf, title: title, subtitle: subtitle)
      end
    rescue StandardError => error
      Rails.logger.warn("[PDF] letterhead: #{error.class} #{error.message}")
    end

    def cleanup
      @tempfiles.each do |file|
        file.close
        file.unlink
      rescue StandardError
        nil
      end
    end

    private

    def draw_standard(pdf, title:, subtitle: nil)
      top = pdf.cursor
      crest = image_file(@professor.school&.crest)
      photo = image_file(@professor.profile_photo)

      if crest
        pdf.image crest.path, at: [0, top], fit: [58, 72]
      end

      if photo
        pdf.image photo.path, at: [pdf.bounds.width - 46, top], fit: [46, 46]
      end

      pdf.fill_color "5B4BDB"
      pdf.text title, size: 16, style: :bold, align: :center

      school_line = [
        @professor.school&.name,
        @professor.school&.regional_label
      ].compact.join(" · ")

      if school_line.present?
        pdf.move_down 4
        pdf.fill_color "20263D"
        pdf.text school_line, size: 9, align: :center
      end

      if subtitle.present?
        pdf.move_down 4
        pdf.fill_color "20263D"
        pdf.text subtitle, size: 10, align: :center
      end

      pdf.move_down 6
      pdf.fill_color "707891"
      pdf.text(
        "#{@professor.name.presence || @professor.email}  ·  #{I18n.l(Date.current)}",
        size: 8,
        align: :center
      )

      pdf.move_down 16
      pdf.fill_color "000000"
    end

    def draw_official(pdf, title:, subtitle: nil)
      top = pdf.cursor
      crest = image_file(@professor.school&.crest)
      indent = crest ? 70 : 0
      header_height = 78

      pdf.bounding_box([0, top], width: pdf.bounds.width, height: header_height) do
        if crest
          pdf.image crest.path, at: [0, header_height], fit: [58, 72]
        end

        pdf.bounding_box(
          [indent, header_height],
          width: pdf.bounds.width - indent
        ) do
          pdf.fill_color "1F4E79"
          pdf.text "GOVERNO DO ESTADO DA PARAÍBA",
                   size: 9,
                   style: :bold,
                   align: :center

          pdf.move_down 2
          pdf.fill_color "20263D"
          pdf.text "SECRETARIA DE ESTADO DA EDUCAÇÃO E DA CIÊNCIA E TECNOLOGIA",
                   size: 8,
                   align: :center

          school_name = @professor.school&.name
          if school_name.present?
            pdf.move_down 4
            pdf.text school_name, size: 11, style: :bold, align: :center
          end

          gre = @professor.school&.regional_label
          if gre.present?
            pdf.move_down 2
            pdf.text gre, size: 8, align: :center
          end
        end
      end

      pdf.move_down 6
      pdf.stroke_color "1F4E79"
      pdf.line_width 1
      pdf.stroke_horizontal_rule
      pdf.move_down 12

      pdf.fill_color "1F4E79"
      pdf.text title.to_s.upcase, size: 14, style: :bold, align: :center

      if subtitle.present?
        pdf.move_down 4
        pdf.fill_color "20263D"
        pdf.text subtitle, size: 11, align: :center
      end

      pdf.move_down 14
      pdf.fill_color "000000"
      pdf.stroke_color "000000"
    end

    def image_file(attachment)
      return unless attachment&.attached?

      ext = attachment.content_type.to_s.include?("png") ? ".png" : ".jpg"
      tempfile = Tempfile.new(["maestro-doc", ext])
      tempfile.binmode
      tempfile.write(attachment.blob.download)
      tempfile.flush
      @tempfiles << tempfile
      tempfile
    rescue StandardError
      nil
    end
  end
end
