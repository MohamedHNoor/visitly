class InvitationsController < ApplicationController
  include AuthenticationDelivery
  before_action :require_membership
  before_action :require_owner

  def index
    @invitations = current_membership.business.invitations.order(created_at: :desc)
    @invitation = Invitation.new
  end

  def create
    token = SecureRandom.urlsafe_base64(32)
    # Role is assigned explicitly rather than mass-assigned; the model only allows scheduler or staff.
    @invitation = current_membership.business.invitations.build(params.require(:invitation).permit(:email_address))
    @invitation.role = params.dig(:invitation, :role).to_s
    @invitation.assign_attributes(inviting_membership: current_membership, token_digest: Invitation.digest(token), expires_at: 7.days.from_now)
    if @invitation.save
      deliver_invitation(@invitation, token)
    else
      @invitations = current_membership.business.invitations.order(created_at: :desc)
      render :index, status: :unprocessable_content
    end
  end

  def resend
    invitation = current_membership.business.invitations.find(params[:id])
    if token = invitation.rotate_token!
      deliver_invitation(invitation, token)
    else
      redirect_to invitations_path, alert: "Accepted or revoked invitations cannot be resent."
    end
  end

  def destroy
    current_membership.business.invitations.find(params[:id]).revoke!
    redirect_to invitations_path, status: :see_other, notice: "Invitation closed. Accepted memberships are unchanged."
  end

  private
    def deliver_invitation(invitation, token)
      delivered = deliver_authentication_email { AuthenticationMailer.invitation(invitation, token) }
      redirect_to invitations_path, notice: delivered ? "Invitation sent." : "Invitation saved, but email is unavailable. Use Resend to try again."
    end
end
