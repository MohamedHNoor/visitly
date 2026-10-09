class AuthenticationMailerPreview < ActionMailer::Preview
  def verification
    AuthenticationMailer.verification(preview_user, "preview-token")
  end

  def password_reset
    AuthenticationMailer.password_reset(preview_user, "preview-token")
  end

  def invitation
    invitation = Invitation.new(business: Business.new(name: "Sample cleaning business"), role: "staff", email_address: "preview@example.test")
    AuthenticationMailer.invitation(invitation, "preview-token")
  end

  private
    def preview_user
      User.new(email_address: "preview@example.test", display_name: "Alex")
    end
end
