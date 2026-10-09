class VerificationsController < ApplicationController
  include AuthenticationDelivery
  include LinkToken
  skip_before_action :require_authentication, only: %i[show update]
  before_action -> { move_link_token_to_session(:verification_token) }, only: :show
  rate_limit to: 3, within: 10.minutes, only: :create, with: -> { redirect_to verification_pending_path, alert: "Too many requests. Try again in ten minutes." }

  def pending
    redirect_to Current.user.membership ? workspace_path : new_onboarding_path if Current.user.email_verified_at?
  end

  def create
    if Current.user.email_verified_at?
      redirect_to Current.user.membership ? workspace_path : new_onboarding_path
    else
      token = Current.user.issue_verification_token!
      delivered = deliver_authentication_email { AuthenticationMailer.verification(Current.user, token) }
      redirect_to verification_pending_path, notice: delivered ? "Check your email for the new link." : "Email is unavailable. Please try again."
    end
  end

  def show
    @token = link_token(:verification_token)
    @valid = User.find_by_token_for(:email_verification, @token).present?
  end

  def update
    user = User.find_by_token_for(:email_verification, params[:token])
    if user && user.verify_email!(params[:token])
      session.delete(:verification_token)
      redirect_to new_session_path, notice: "Email verified. Sign in to continue."
    else
      @token = params[:token]
      @valid = false
      render :show, status: :unprocessable_content
    end
  end
end
