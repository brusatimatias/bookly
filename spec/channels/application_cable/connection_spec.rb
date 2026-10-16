require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  it "identifies the signed in user" do
    user = create(:user)
    cookies.signed[:session_id] = user.sessions.create!.id

    connect

    expect(connection.current_user).to eq(user)
  end

  it "accepts customers without an account, anonymously" do
    connect

    expect(connection.current_user).to be_nil
  end
end
