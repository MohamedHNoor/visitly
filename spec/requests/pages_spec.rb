require "rails_helper"

RSpec.describe "Marketing homepage", type: :request do
  before { get root_path }

  it "renders the homepage with the hero heading and logo" do
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Less admin.")
    expect(response.body).to include('alt="Visitly"')
    expect(response.body).to include('lang="en-NZ"')
  end

  it "renders each section anchor" do
    %w[main features industries pricing faq].each do |anchor|
      expect(response.body).to include(%(id="#{anchor}"))
    end
  end

  it "lists the approved plans with GST-exclusive NZD prices" do
    body = response.body

    { "Solo" => 29, "Team" => 49, "Growth" => 99 }.each do |plan, price|
      expect(body).to include(">#{plan}</h3>")
      expect(body).to include("NZ$#{price}")
    end
    expect(body.scan("/ month excl. GST").size).to eq(3)
    expect(body).to include("1 active bookable staff member", "Up to 5 active bookable staff", "Unlimited active bookable staff")
    expect(body).not_to include(">Custom</h3>", "Contact us for a quote", "NZ$89")
  end

  it "describes the approved post-trial access policy" do
    expect(response.body).to include(
      "read-only for seven days",
      "For the following seven days you can only download or delete your data",
      "14 days after the trial ends",
      "Confirmed visits are never automatically cancelled"
    )
  end

  it "omits stale prototype copy" do
    [ "30 days of read-only", "seven-day transition", "Design concept", "DESIGN PROTOTYPE",
      "Explore the demo", "GST treatment to be confirmed" ].each do |stale|
      expect(response.body).not_to include(stale)
    end
  end

  it "does not link to routes that are not built yet" do
    %w[#login #signup #contact #privacy #terms #dashboard /dashboard #book].each do |target|
      expect(response.body).not_to include(%(href="#{target}))
    end
  end
  it "connects trial calls to action and desktop/mobile sign-in links" do
    document = Nokogiri::HTML(response.body)
    trial_links = document.css("a").select { |link| link.text.start_with?("Start") }
    expect(trial_links.size).to eq(4)
    expect(trial_links.map { |link| link["href"] }.uniq).to eq([ new_registration_path ])
    expect(document.css("a[href='/login']").size).to eq(2)
    get new_session_path
    expect(response).to have_http_status(:ok)
    get new_registration_path
    expect(response).to have_http_status(:ok)
  end
end
