class InvitationAcceptancesController < ApplicationController
  include LinkToken
  skip_before_action :require_authentication, only: :show
  before_action -> { move_link_token_to_session(:invitation_token) }, only: :show
  rate_limit to: 10, within: 10.minutes, only: :create, with: -> { @message = "Too many attempts. Try again in ten minutes."; load_invitation; render :show, status: :too_many_requests }

  def show
    Current.session = Session.find_by(id: cookies.signed[:session_id])
    load_invitation
    @blocker = acceptance_blocker
  end

  def create
    load_invitation
    if @invitation&.accept!(Current.user, params[:token])
      session.delete(:invitation_token)
      redirect_to workspace_path, status: :see_other, notice: "Invitation accepted."
    else
      @message = "This invitation cannot be accepted. Check that you have verified the invited email and do not already belong to a workspace."
      render :show, status: :unprocessable_content
    end
  end

  private
    def load_invitation
      @token = link_token(:invitation_token).to_s
      @invitation = Invitation.find_by(token_digest: Invitation.digest(@token))
    end

    # Mirrors the checks in Invitation#accept! so a signed-in user who cannot
    # accept is told why instead of being offered a button that will fail.
    def acceptance_blocker
      return unless Current.user && @invitation&.available?

      if Current.user.email_address != @invitation.email_address
        "This invitation was sent to a different email address. Sign out, then sign in with the invited email."
      elsif Current.user.membership
        "This account already belongs to a workspace, so it can’t accept another invitation."
      elsif !Current.user.email_verified_at?
        "Verify your email address before accepting this invitation."
      end
    end
end
