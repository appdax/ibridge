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

    before { Timecop.freeze(Time.utc(2016, 5, 2, 21, 26, 0)) }

    context 'when unifying the stock' do
      let(:feeds) { db.collections.delete_if { |col| col.name == 'stocks' } }

      before { import_file(importer, 'spec/fixtures/facebook.json') }

      after do
        FileUtils.rm_rf importer.path
        db.collections.each(&:drop)
      end

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

    context 'when importing all stock feeds' do
      before { import_file(importer, 'spec/fixtures/facebook.json') }

      context 'when unifying feeds' do
        before { Unifier.new.run }

        context 'when importing newer intraday feed' do
          before do
            db.collections.each { |col| col.drop unless col.name == 'stocks' }
            import_file(importer, 'spec/fixtures/facebook.intra.json')
          end

          context 'when unifying intraday data' do
            before { Unifier.new.run }

            describe 'unified stock' do
              let!(:stock) { db[:stocks].find.limit(1).first }

              it('should have newer intraday data') do
                expect(stock[:intraday][:meta][:age]).to eq(13)
              end

              it('should still have all its other content') do
                expect(stock[:performance]).to_not be_nil
                expect(stock[:performance]).to_not be_empty
              end
            end
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

def import_file(importer, file)
  json = IO.read(file)

  FileUtils.mkdir_p importer.path
  IO.write File.join(importer.path, 'fb.json'), json

  importer.run
end
