require 'hashdiff'

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

  describe '#run' do
    let!(:importer) { Importer.new path: 'tmp/data' }
    let!(:db) { importer.send(:db) }

    before do
      json = IO.read('spec/fixtures/facebook.json')

      FileUtils.mkdir_p importer.path
      IO.write File.join(importer.path, 'fb.json'), json

      importer.path('tmp/data').run
    end

    after do
      FileUtils.rm_rf importer.path
      db.collections.each(&:drop)
    end

    context 'when unifying the stock' do
      let(:feeds) { db.collections.delete_if { |col| col.name == 'stocks' } }

      context 'when keeping feed collections' do
        before { Unifier.new.drop_feeds(false).run }
        describe 'feed collections' do
          it { expect(feeds).to_not be_empty }
        end
      end

      context 'when dropping feed collections after' do
        before { Unifier.new.drop_feeds(true).run }

        describe 'feed collections' do
          it { expect(feeds).to be_empty }
        end

        describe 'unified stock' do
          let(:unified) { db[:stocks].find.limit(1).first }
          let(:expected) do
            content = IO.read('spec/fixtures/facebook.unified.yaml')
            YAML.load content
          end

          it('should be equal to facebook.unified.yaml') do
            expect(HashDiff.diff(unified, expected)).to be_empty
          end
        end
      end
    end

    context 'when unifying 2 times without import between' do
      before do
        2.times { Unifier.new.drop_feeds(true).run }
      end

      describe 'stocks collection' do
        subject { db[:stocks].find.to_a }
        it { is_expected.to_not be_empty }
      end
    end
  end
end
