class PasswordsController < ApplicationController
  include LinkToken
  skip_before_action :require_authentication
  before_action -> { move_link_token_to_session(:password_reset_token) }, only: :edit
  rate_limit to: 3, within: 10.minutes, only: :create, with: -> { @notice = "Too many requests. Try again in ten minutes."; render :new, status: :too_many_requests }
  rate_limit to: 10, within: 10.minutes, only: :update, with: -> { @valid = false; render :edit, status: :too_many_requests }

  def new
  end

  def create
    PasswordResetDeliveryJob.perform_later(params[:email_address].to_s.strip.downcase)
    @notice = "If an account exists, we will attempt to send a reset link. If no email arrives, please try again."
    render :new
  end

  def edit
    @token = link_token(:password_reset_token)
    @user = User.find_by_token_for(:password_recovery, @token)
    @valid = @user.present?
  end

  def update
    @token = params[:token]
    @user = User.find_by_token_for(:password_recovery, @token)
    @valid = @user.present?
    if @user && @user.reset_password!(@token, params.require(:user).permit(:password, :password_confirmation))
      cookies.delete(:session_id)
      reset_session
      Current.reset
      redirect_to new_session_path, notice: "Password updated. Sign in with your new password."
    else
      @valid = @user.present? && User.find_by_token_for(:password_recovery, @token).present?
      render :edit, status: :unprocessable_content
    end
  end
end
