require 'fakefs/spec_helpers'

RSpec.describe Importer do
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

    describe 'path:' do
      subject { client.path }

      context 'when initialized without path' do
        let(:client) { described_class.new }
        describe('#path') { it { is_expected.to_not be_nil } }
      end

      context 'when initialized with path "tmp"' do
        let(:client) { described_class.new path: 'tmp' }
        describe('#path') { it { is_expected.to eq('tmp') } }
      end
    end
  end

  describe '#files_to_import' do
    context 'when assigning an non existing folder' do
      let(:importer) { Importer.new path: 'abd/dfbfg' }
      subject { importer.files_to_import }
      it { is_expected.to be_empty }
    end

    context 'when assigning an file instead of an folder' do
      let(:importer) { Importer.new path: 'abc.txt' }
      subject { importer.files_to_import }
      it { is_expected.to be_empty }
    end

    context 'when assigning an file instead of an folder' do
      let(:importer) { Importer.new path: 'abc.txt' }
      subject { importer.files_to_import }
      it { is_expected.to be_empty }
    end

    context 'when assigning an folder with 2 files' do
      include FakeFS::SpecHelpers
      let(:importer) { Importer.new path: 'tmp/data' }
      subject { importer.files_to_import.count }

      before do
        FileUtils.mkdir_p importer.path
        File.write File.join(importer.path, 'f1.json'), ''
        File.write File.join(importer.path, 'f2.json'), ''
        File.write File.join(importer.path, 'f3.txt'), ''
      end

      it { is_expected.to eq(2) }
    end
  end

  describe '#run' do
    let!(:json) { IO.read 'spec/fixtures/facebook.json' }
    let!(:importer) { Importer.new path: 'tmp/data' }
    let!(:db) { importer.send(:client) }

    before do
      FileUtils.mkdir_p importer.path
      IO.write File.join(importer.path, 'fb.json'), json
      importer.run
    end

    after do
      FileUtils.rm_rf importer.path
      db.collections.each(&:drop)
    end

    context 'when importing one stock' do
      describe 'basics feed count' do
        it { expect(db[:basics].count).to eq(1) }
      end

      describe 'intraday feed count' do
        it { expect(db['consorsbank-intraday'].count).to eq(1) }
      end

      describe 'performance feed count' do
        it { expect(db['consorsbank-performance'].count).to eq(1) }
      end

      describe 'factset feed count' do
        it { expect(db['consorsbank-factset'].count).to eq(1) }
      end

      describe 'technical-analysis feed count' do
        it { expect(db['consorsbank-technicalanalysis'].count).to eq(1) }
      end

      describe 'trading-central feed count' do
        it { expect(db['consorsbank-tradingcentral'].count).to eq(1) }
      end

      describe 'screener feed count' do
        it { expect(db['consorsbank-thescreener'].count).to eq(1) }
      end
    end

    context 'when importing older stock data' do
      let!(:older_json) do
        data = JSON.parse(json)

        data['analyses'][0]['meta']['age'] = 1_000
        data['analyses'][0]['upgrades']    = 1_000

        JSON.generate(data)
      end

      before do
        IO.write File.join(importer.path, 'newer.json'), older_json
        importer.run
      end

      it('should keep the newer stock') do
        stock = db['consorsbank-factset'].find(_id: 'US30303M1027').first

        expect(stock['meta']['age']).to_not eq(1_000)
        expect(stock['upgrades']).to_not    eq(1_000)
      end
    end

    context 'when importing stock data of same age' do
      let!(:newer_json) do
        data = JSON.parse(json)

        data['analyses'][0]['upgrades'] = 2_000

        JSON.generate(data)
      end

      before do
        IO.write File.join(importer.path, 'newer.json'), newer_json
        importer.run
      end

      it('should have updated stock') do
        stock = db['consorsbank-factset'].find(_id: 'US30303M1027').first
        expect(stock['upgrades']).to eq(2_000)
      end
    end

    context 'when importing newer stock data' do
      let!(:newer_json) do
        data = JSON.parse(json)

        data['analyses'][0]['meta']['age'] = 0
        data['analyses'][0]['upgrades']    = 1_000

        JSON.generate(data)
      end

      before do
        IO.write File.join(importer.path, 'newer.json'), newer_json
        importer.run
      end

      it('should have updated stock') do
        stock = db['consorsbank-factset'].find(_id: 'US30303M1027').first

        expect(stock['meta']['age']).to eq(0)
        expect(stock['upgrades']).to    eq(1_000)
      end
    end
  end
end
