class WorkspacesController < ApplicationController
  before_action :require_membership

  def show
    @membership = current_membership
    @business = @membership.business unless @membership.role == "staff"
  end
end
