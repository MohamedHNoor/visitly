# Moves an emailed link token from the query string into the encrypted session,
# so it stays out of the address bar, browser history and Referer headers.
module LinkToken
  private
    def move_link_token_to_session(key)
      return if params[:token].blank?

      session[key] = params[:token].to_s
      redirect_to request.path
    end

    def link_token(key)
      params[:token].presence || session[key]
    end
end
