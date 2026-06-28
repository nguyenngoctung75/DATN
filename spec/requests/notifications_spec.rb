require "rails_helper"

RSpec.describe "Notifications", type: :request do
  let(:user) { create(:user) }

  before { login_as user, scope: :user }

  describe "GET /notifications" do
    let!(:notification) { create(:notification, category: "info") }

    it "renders the index" do
      get notifications_path
      expect(response).to have_http_status(:ok)
    end

    it "renders 'Mark all as read' as a POST form, not a GET link" do
      get notifications_path
      # button_to produces a <form method="post" action="/notifications/mark_all_read">
      expect(response.body).to include('action="/notifications/mark_all_read"')
      expect(response.body).to match(%r{<form[^>]*method="post"[^>]*>.*?/notifications/mark_all_read}m)
        .or match(%r{action="/notifications/mark_all_read".*?<input[^>]+name="_method"}m)
      # Regression: must not be a bare anchor that triggers GET
      expect(response.body).not_to include('href="/notifications/mark_all_read"')
    end
  end

  describe "POST /notifications/mark_all_read" do
    let!(:n1) { create(:notification, category: "info") }
    let!(:n2) { create(:notification, category: "info") }

    it "marks all visible notifications as read and redirects (HTML)" do
      expect {
        post mark_all_read_notifications_path
      }.to change { NotificationRead.where(user: user).count }.from(0).to(2)
      expect(response).to have_http_status(:redirect)
    end

    it "returns unread_count 0 (JSON)" do
      post mark_all_read_notifications_path, headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["unread_count"]).to eq(0)
    end

    it "is not reachable via GET (the original 404 cause)" do
      get "/notifications/mark_all_read"
      expect(response).to have_http_status(:not_found)
    end
  end
end
