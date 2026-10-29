module Api
  module V1
    class DeskController < BaseController
      def health
        render json: { ok: true, service: "maestro-desk" }
      end

      def product
        render json: Desk::Catalog.product
      end

      def professor
        whatsapp = params[:whatsapp].to_s
        if Lira::Phone.digits(whatsapp).blank?
          render json: { error: "Informe o WhatsApp do professor." }, status: :unprocessable_entity
          return
        end

        render json: Desk::Lookup.new(whatsapp).payload
      end

      def create_message
        message = DeskMessage.new(message_params)
        message.professor ||= Professor.find_by_whatsapp(message.whatsapp_number)

        if message.save
          render json: {
            ok: true,
            id: message.id,
            professor_id: message.professor_id,
            found: message.professor_id.present?
          }, status: :created
        else
          render json: { error: message.errors.full_messages.to_sentence },
                 status: :unprocessable_entity
        end
      end

      private

      def message_params
        raw = params.permit(:whatsapp, :whatsapp_number, :name, :email, :text, :body, :direction, :intent, :external_id)
        {
          whatsapp_number: raw[:whatsapp_number].presence || raw[:whatsapp],
          name: raw[:name],
          email: raw[:email],
          body: raw[:body].presence || raw[:text],
          direction: raw[:direction],
          intent: raw[:intent],
          external_id: raw[:external_id]
        }
      end
    end
  end
end
