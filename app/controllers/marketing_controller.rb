class MarketingController < ApplicationController
  skip_before_action :require_maestro_subscription,
                     only: %i[home download siage_extension]

  def home
  end

  def download
  end

  def siage_extension
    send_data Siage::ExtensionPackage.bytes,
              filename: Siage::ExtensionPackage.filename,
              type: "application/zip",
              disposition: "attachment"
  end
end
