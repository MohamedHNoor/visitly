class RegistrationsController < ApplicationController
  include AuthenticationDelivery
  skip_before_action :require_authentication
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { @user = User.new; @notice = "Too many attempts. Try again in ten minutes."; render :new, status: :too_many_requests }

  def new
    @user = User.new
  end

  def create
    @user = User.new(params.require(:user).permit(:display_name, :email_address, :password, :password_confirmation))
    if @user.save
      start_new_session_for(@user)
      token = @user.issue_verification_token!
      delivered = deliver_authentication_email { AuthenticationMailer.verification(@user, token) }
      redirect_to verification_pending_path, notice: delivered ? "Check your email to verify your account." : "Your account was saved, but email is unavailable. Please retry sending your verification link."
    else
      render :new, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    @user.errors.add(:email_address, "is already registered")
    render :new, status: :unprocessable_content
  end
end
