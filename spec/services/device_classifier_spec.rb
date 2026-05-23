require 'rails_helper'

RSpec.describe DeviceClassifier do
  describe '.match?' do
    context 'when device_name is blank' do
      it { expect(described_class.match?('', 'pc')).to be false }
      it { expect(described_class.match?(nil, 'sp')).to be false }
    end

    context 'PC category' do
      it 'matches chrome desktop' do
        expect(described_class.match?('Chrome 120', 'pc')).to be true
      end

      it 'matches stg environment' do
        expect(described_class.match?('stg_vn', 'pc')).to be true
      end

      it 'excludes android devices' do
        expect(described_class.match?('Android Chrome', 'pc')).to be false
      end

      it 'excludes iOS devices' do
        expect(described_class.match?('iPhone Safari', 'pc')).to be false
      end
    end

    context 'SP category' do
      it 'matches android' do
        expect(described_class.match?('Android 14', 'sp')).to be true
      end

      it 'matches iPhone' do
        expect(described_class.match?('iPhone 15', 'sp')).to be true
      end

      it 'matches testflight' do
        expect(described_class.match?('TestFlight SP', 'sp')).to be true
      end
    end

    context 'APP category' do
      it 'matches app keyword' do
        expect(described_class.match?('APP v2.1.0', 'app')).to be true
      end

      it 'matches android with version number' do
        expect(described_class.match?('Android 2.3.1', 'app')).to be true
      end
    end

    context 'unknown category' do
      it 'returns true only when device name equals category' do
        expect(described_class.match?('staging', 'staging')).to be true
        expect(described_class.match?('production', 'staging')).to be false
      end
    end
  end
end
