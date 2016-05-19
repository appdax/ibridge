RSpec.describe Unifier do
  it { is_expected.to be_a(Client) }

  context 'initialization' do
    describe 'batch_size:' do
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

    describe 'drop_feeds:' do
      subject { client.drop_feeds }

      context 'when initialized without drop_feeds' do
        let(:client) { described_class.new }
        describe('#drop_feeds') { it { is_expected.to be_falsy } }
      end

      context 'when initialized with a value' do
        let(:client) { described_class.new drop_feeds: true }
        describe('#drop_feeds') { it { is_expected.to be_truthy } }
      end
    end
  end
end
