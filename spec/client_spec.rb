RSpec.describe Client do
  context 'initialization' do
    subject { client.batch_size }

    context 'when initialized without batch_size' do
      let(:client) { described_class.new }
      describe('#batch_size') { it { is_expected.to_not be_nil } }
    end

    context 'when initialized with batch_size of 10' do
      let(:client) { described_class.new batch_size: 10 }
      describe('#batch_size') { it { is_expected.to eq(10) } }
    end
  end

  describe '#batch_size' do
    let(:client) { described_class.new }

    context 'when setting a value' do
      subject { client.batch_size(250) }
      it('should return self') { is_expected.to be(client) }
    end

    context 'when setting zero' do
      subject { client.batch_size }
      before { client.batch_size(0) }
      it('should return 1') { is_expected.to be(1) }
    end

    context 'when setting a negative value' do
      subject { client.batch_size }
      before { client.batch_size(-2) }
      it('should return 1') { is_expected.to be(1) }
    end

    context 'when getting a value' do
      subject { client.batch_size }
      before { client.batch_size(1) }
      it('should return the value') { is_expected.to eq(1) }
    end
  end

  describe '#client' do
    it('should not be public') do
      expect(described_class.protected_instance_methods).to include(:client)
    end
  end
end
