module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :current_membership
  end

  private
    def require_authentication
      Current.session = Session.find_by(id: cookies.signed[:session_id])
      redirect_to new_session_path unless Current.session
    end

    def current_membership
      Current.user&.membership
    end

    def require_membership
      head :forbidden unless current_membership&.status == "active" && Current.user.email_verified_at?
    end

    def require_owner
      head :forbidden unless current_membership&.role == "owner"
    end

    def start_new_session_for(user)
      # Carry only a pending invitation link across the reset, so an invitee who
      # signs in from the invitation page can be returned to it.
      invitation_token = session[:invitation_token]
      reset_session
      session[:invitation_token] = invitation_token if invitation_token
      Current.session = user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
      cookies.signed[:session_id] = { value: Current.session.id, httponly: true, same_site: :lax, secure: Rails.env.production? }
    end

    def terminate_session
      Current.session&.destroy!
      cookies.delete(:session_id)
      reset_session
      Current.reset
    end
end
