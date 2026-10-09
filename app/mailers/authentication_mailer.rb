class AuthenticationMailer < ApplicationMailer
  default from: -> { Rails.application.config.x.authentication_email_from }

  def verification(user, token)
    @url = Rails.application.config.x.authentication_email_origin.chomp("/") + Rails.application.routes.url_helpers.verification_path(token: token)
    mail(to: user.email_address, subject: "Verify your email for Visitly")
  end

  def password_reset(user, token)
    @url = Rails.application.config.x.authentication_email_origin.chomp("/") + Rails.application.routes.url_helpers.edit_password_path(token: token)
    mail(to: user.email_address, subject: "Reset your password for Visitly")
  end
  def invitation(invitation, token)
    @business_name = invitation.business.name
    @role = invitation.role.capitalize
    @url = Rails.application.config.x.authentication_email_origin.chomp("/") + Rails.application.routes.url_helpers.invitation_acceptance_path(token: token)
    mail(to: invitation.email_address, subject: "Your Visitly workspace invitation")
  end
end
