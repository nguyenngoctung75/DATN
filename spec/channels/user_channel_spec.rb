require 'rails_helper'

RSpec.describe UserChannel, type: :channel do
  let(:user) { create(:user) }

  describe '#subscribed' do
    context 'with an authenticated user' do
      before { stub_connection current_user: user }

      it 'confirms the subscription' do
        subscribe
        expect(subscription).to be_confirmed
      end

      it 'streams from the global notifications broadcast' do
        subscribe
        expect(subscription.streams).to include('notifications')
      end

      it 'streams from the per-user broadcast' do
        subscribe
        expect(subscription.streams).to include(UserChannel.broadcasting_for(user))
      end
    end
  end

  describe '#unsubscribed' do
    before { stub_connection current_user: user }

    it 'stops all streams without raising' do
      subscribe
      expect { unsubscribe }.not_to raise_error
    end
  end
end
