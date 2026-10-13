class ProfilesController < ApplicationController
  before_action :authenticate_professor!

  def edit
    @professor = current_professor
  end

  def update
    @professor = current_professor

    if @professor.update(profile_params)
      enqueue_whatsapp_welcome
      redirect_to settings_path, notice: profile_updated_notice
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def remove_photo
    current_professor.profile_photo.purge_later
    redirect_to settings_path, notice: "Foto removida com sucesso."
  end

  private

  def enqueue_whatsapp_welcome
    return unless @professor.needs_whatsapp_welcome?

    Lira::DeliverWelcomeWhatsappJob.perform_later(@professor.id)
  end

  def profile_updated_notice
    if @professor.needs_whatsapp_welcome?
      "Perfil atualizado. Se o WhatsApp do Maestro estiver configurado, você receberá as boas-vindas."
    else
      "Perfil atualizado com sucesso."
    end
  end

  def profile_params
    params.require(:professor).permit(
      :name,
      :preferred_name,
      :sex,
      :phone,
      :whatsapp_number,
      :bio,
      :profile_photo
    )
  end
end
