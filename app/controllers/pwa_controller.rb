class PwaController < ApplicationController
  skip_forgery_protection

  def manifest
    render template: "pwa/manifest",
           content_type: "application/manifest+json",
           layout: false
  end

  def service_worker
    render template: "pwa/service-worker",
           content_type: "application/javascript",
           layout: false
  end
end
