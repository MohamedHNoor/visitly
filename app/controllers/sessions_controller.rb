class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { render :new, status: :too_many_requests, locals: { error: "Too many attempts. Please try again in a few minutes." } }

  def new
  end

  def create
    user = User.authenticate_by(params.permit(:email_address, :password))
    signed_in = false
    if user
      user.with_lock do
        # Serialize credential rechecking/session creation with password resets.
        if user.authenticate(params[:password])
          start_new_session_for(user)
          signed_in = true
        end
      end
    end
    if signed_in
      redirect_to after_sign_in_path_for(user)
    else
      render :new, status: :unprocessable_content, locals: { error: "Email or password is incorrect." }
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, status: :see_other
  end

  private
    def after_sign_in_path_for(user)
      return verification_pending_path unless user.email_verified_at?
      return workspace_path if user.membership

      session[:invitation_token] ? invitation_acceptance_path : new_onboarding_path
    end
end
