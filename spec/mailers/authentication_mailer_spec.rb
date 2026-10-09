require "rails_helper"

RSpec.describe AuthenticationMailer, type: :mailer do
  let(:user) { User.new(email_address: "alex@example.nz", display_name: "<script>unsafe</script>") }

  it "uses canonical-origin links with expiry guidance in both parts" do
    mail = described_class.verification(user, "signed-token")
    expect(mail.to).to eq([ user.email_address ])
    expect(mail.html_part.body.decoded).to include("http://localhost:3000/verification?token=signed-token", "24 hours")
    expect(mail.text_part.body.decoded).to include("24 hours")
  end

  it "renders password-reset links and expiry" do
    mail = described_class.password_reset(user, "signed-token")
    expect(mail.text_part.body.decoded).to include("/password/edit?token=signed-token", "15 minutes")
  end

  it "does not log authentication email bodies" do
    expect(ActionMailer::Base.logger).to be_nil
    expect(described_class.logger).to be_nil
  end

  it "delivers through the production Resend adapter with mocked HTTPS API" do
    original_key = Resend.api_key
    Resend.api_key = "test-key"
    response = { id: "mock-provider-id", error: nil }
    allow(Resend::Emails).to receive(:send).and_return(response)
    mail = described_class.verification(user, "signed-token").message
    mail.delivery_method(Resend::Mailer)
    mail.deliver
    expect(Resend::Emails).to have_received(:send).with(hash_including(to: [ user.email_address ], subject: "Verify your email for Visitly"), options: {})
    expect(mail.message_id).to eq("mock-provider-id")
  ensure
    Resend.api_key = original_key
  end
end
