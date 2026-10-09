# Looks up the account and sends the reset email outside the request, so the
# response takes the same time whether or not the address belongs to an account.
class PasswordResetDeliveryJob < ApplicationJob
  include AuthenticationDelivery

  queue_as :default
  # The argument is an email address; keep it out of job logs.
  self.log_arguments = false

  def perform(email_address)
    user = User.find_by(email_address: email_address)
    return unless user

    token = user.issue_reset_token!
    deliver_authentication_email { AuthenticationMailer.password_reset(user, token) }
  end
end
