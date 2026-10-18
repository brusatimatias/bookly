module ApplicationCable
  # Customers on the public booking page have no account, so connections may be
  # anonymous. Streams are still private: Turbo only subscribes to signed
  # stream names, which only come in a rendered page, and they only carry
  # "refresh" signals (each page reloads itself with its viewer's permissions).
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = Session.find_by(id: cookies.signed[:session_id])&.user
    end
  end
end
