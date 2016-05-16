RSpec.describe Drive do
  let(:drive) { Drive.instance }

  context 'when revisions are [3, 2, 1]' do
    before do
      allow(drive).to receive(:revisions).and_return [3, 2, 1]
      allow(drive).to receive(:last_imported_revision).and_return last_rev
    end

    context 'and last imported revision is nil' do
      let(:last_rev) { nil }

      describe '#revisions_to_import' do
        subject { drive.revisions_to_import }
        it { is_expected.to eq(drive.revisions) }
      end
    end

    context 'and last imported revision is 1' do
      let(:last_rev) { 1 }

      describe '#revisions_to_import' do
        subject { drive.revisions_to_import }
        it { is_expected.to eq([3, 2]) }
      end
    end

    context 'and last imported revision is revent revision' do
      let(:last_rev) { 3 }

      describe '#revisions_to_import' do
        subject { drive.revisions_to_import }
        it { is_expected.to be_empty }
      end
    end

    context 'and last imported revision is unknown' do
      let(:last_rev) { 4 }

      describe '#revisions_to_import' do
        it { expect { drive.revisions_to_import }.to raise_error(Drive::BadRevisionError) }
      end

      describe '#last_imported_revision=' do
        it { expect { drive.last_imported_revision = last_rev }.to raise_error(Drive::BadRevisionError) }
      end
    end
  end

  describe '#revisions' do
    subject { drive.revisions }

    context 'when received in unordered order' do
      let(:revs) { JSON.parse IO.read('spec/fixtures/revisions.json') }

      before do
        allow_any_instance_of(DropboxClient).to(receive(:revisions))
                                            .and_return(revs)
      end

      it('should be ordered by date') do
        is_expected.to eq(%w(2b3479b229d 2b1479b229d 2b0479b229d))
      end
    end

    context 'when stocks archive does not exist' do
      before { stub_request(:get, /revisions/).to_return status: 404 }
      it { is_expected.to be_empty }
    end
  end

  describe '#last_imported_revision' do
    subject { drive.last_imported_revision }

    context 'when revision.txt does exist' do
      let(:rev) { '2b0479b229d' }
      before { stub_request(:get, /files/).to_return body: rev }
      it('should return the revision') { is_expected.to eq(rev) }
    end

    context 'when revisions.txt does not exist' do
      before { stub_request(:get, /files/).to_return status: 404 }
      it { is_expected.to be_nil }
    end
  end

  describe '#each_revision_to_import' do
    before do
      tar = IO.read 'spec/fixtures/stocks.tar.gz'

      allow(drive).to receive(:revisions).and_return [3, 2, 1]
      allow(drive).to receive(:last_imported_revision).and_return nil

      @stub_1 = stub_request(:get, /stocks.tar.gz\?rev=1/).to_return body: tar
      @stub_2 = stub_request(:get, /stocks.tar.gz\?rev=2/).to_return body: tar
      @stub_3 = stub_request(:get, /stocks.tar.gz\?rev=3/).to_return body: tar

      @stub_rev = stub_request(:put, /revision.txt\?overwrite=true/)
                  .with(body: '3').to_return body: '{}'
    end

    context 'when having 3 revisions to import' do
      let(:each_rev) { ->(b) { drive.each_revision_to_import(&b) } }
      let(:args) { [[3, String], [2, String], [1, String]] }

      it('should yield 3 times') do
        expect(&each_rev).to yield_control.exactly(3).times
      end

      it('should yield with newest revision first') do
        expect(&each_rev).to yield_successive_args(*args)
      end
    end

    context 'after each revision has been processed' do
      before { drive.each_revision_to_import {} }

      it('should have downloaded the archive for each revision') do
        expect(@stub_3).to have_been_requested
        expect(@stub_2).to have_been_requested
        expect(@stub_1).to have_been_requested
      end

      it('should have updated the last revision number') do
        expect(@stub_rev).to have_been_requested.times(1)
      end

      it('should have cleaned up the tmp dir') do
        expect(File).to_not exist('tmp/stocks')
        expect(File).to_not exist('tmp/stocks.tar.gz')
      end
    end

    context 'when aborting process' do
      before do
        drive.each_revision_to_import { raise Drive::BadRevisionError }
      end

      it('should have downloaded the archive for each revision') do
        expect(@stub_3).to have_been_requested
        expect(@stub_2).to_not have_been_requested
        expect(@stub_1).to_not have_been_requested
      end

      it('should not have updated the last revision number') do
        expect(@stub_rev).to_not have_been_requested
      end
    end
  end
end
