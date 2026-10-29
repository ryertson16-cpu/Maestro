class MarketingController < ApplicationController
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
