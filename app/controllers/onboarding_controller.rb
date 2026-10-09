class OnboardingController < ApplicationController
  before_action :require_verified_user
  before_action :redirect_existing_member

  def new
    @business = Business.new(timezone: "Pacific/Auckland")
  end

  def create
    @business = Current.user.create_workspace!(params.require(:business).permit(:name, :industry, :timezone).to_h.symbolize_keys)
    redirect_to setup_complete_path, status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    raise unless error.record.is_a?(Business)
    @business = error.record
    render :new, status: :unprocessable_content
  end

  private
    def require_verified_user
      redirect_to verification_pending_path unless Current.user.email_verified_at?
    end

    def redirect_existing_member
      redirect_to workspace_path if current_membership
    end
end
