require "timeout"

module AuthenticationDelivery
  private
    def deliver_authentication_email
      Timeout.timeout(10) { yield.deliver_now }
      true
    rescue Resend::Error, Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => error
      # Provider messages can contain recipients or credentials; record only the class.
      Rails.logger.warn("Authentication email unavailable: #{error.class.name}")
      false
    end
end
