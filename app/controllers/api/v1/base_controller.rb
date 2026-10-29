module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_desk_token!

      private

      def authenticate_desk_token!
        expected = ENV["MAESTRO_DESK_API_TOKEN"].to_s
        given = bearer_token

        unless expected.present? &&
               given.present? &&
               expected.bytesize == given.bytesize &&
               ActiveSupport::SecurityUtils.secure_compare(expected, given)
          render json: { error: "Não autorizado." }, status: :unauthorized
        end
      end

      def bearer_token
        header = request.headers["Authorization"].to_s
        header.delete_prefix("Bearer ").delete_prefix("bearer ").strip
      end
    end
  end
end
