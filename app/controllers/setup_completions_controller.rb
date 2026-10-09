class SetupCompletionsController < ApplicationController
  before_action :require_membership
  before_action :require_owner

  def show
    @business = current_membership.business
  end
end
