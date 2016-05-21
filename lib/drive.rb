require 'forwardable'
require 'singleton'
require 'dropbox_sdk'

# Wrapper around the DropBox client. The class can be used to ask for the last
# imported revision or the missing revisions to import.
# Furthermore it can be used to download a revision to import.
#
# @example Last imported revision.
#   Drive.last_imported_revision
#   # => "2b0479b229d"
#
# @example Revisions to import.
#   Drive.revisions_to_import
#   # => ["2b3479b229d", "2b1479b229d"]
class Drive
  include Singleton
  extend SingleForwardable

  class BadRevisionError < Exception; end

  delegate %i(revisions revisions_to_import) => :instance
  delegate %i(last_imported_revision last_imported_revision=) => :instance
  delegate %i(each_revision_to_import each_revision_to_import?) => :instance

  # Download, unpack and yield for each not yet imported revision. Once the
  # codeblock got executed without raising BadRevisionError, the last imported
  # revision will be updated.
  #
  # @example Import everything new.
  #   each_revision_to_import { |rev| Importer.new(rev) }
  #
  # @example Signal that something went wrong.
  #   each_revision_to_import { raise BadRevisionError }
  #
  # @return [ Void ]
  def each_revision_to_import
    revisions_to_import.each_with_index do |rev, i|
      dir = download_revision(rev)

      next unless dir

      yield rev, dir

      self.last_imported_revision = rev if i == 0
      FileUtils.rm_rf(dir)
    end
  rescue BadRevisionError # rubocop:disable Lint/HandleExceptions
    # Nothing to do here
  end

  # If there are pending revisions ready to import.
  #
  # @return [ Boolean ]
  def revisions_to_import?
    revisions_to_import.any?
  end

  # List of revisions newer then the last imported revision.
  #
  # @return [ Array<String> ]
  def revisions_to_import
    last_rev = last_imported_revision
    revs     = revisions

    return revs unless last_rev
    revs[0...(revs.index(last_rev))]
  rescue ArgumentError
    raise BadRevisionError, last_rev
  end

  # Revision number of the last imported archive.
  #
  # @example When a revision has been imported already.
  #   last_imported_revision
  #   # => "2b0479b229d"
  #
  # @example When no revision has been imported yet.
  #   last_imported_revision
  #   # => nil
  #
  # @return [ String ]
  def last_imported_revision
    client.get_file('revision.txt').chomp
  rescue DropboxError
    nil
  end

  # Assign revision number of the last imported archive.
  #
  # @example To set a revision number
  #   last_imported_revision = "321"
  #
  # @param [ String ] revision The revision number to set for.
  #
  # @return [ Void ]
  def last_imported_revision=(revision)
    raise BadRevisionError, revision unless revisions.include? revision

    client.put_file('revision.txt', revision, true)
  end

  # List of revisions for stock.tar.gz archive.
  #
  # @example Get newest revision as first.
  #   revisions
  #   # => ["3", "2", "1"]
  #
  # @example Get olderst revision as first.
  #   revisions.reverse!
  #   # => ["1", "2", "3"]
  #
  # @return [ Array<String> ]
  def revisions
    client.revisions('stocks.tar.gz')
          .sort_by! { |meta| -meta['revision'] }
          .map! { |meta| meta['rev'] }
  rescue DropboxError
    []
  end

  private

  # Download and unpack the stocks.tar.gz archive of the given revision.
  #
  # @param [ String ] revision If nil, the recent one will be used.
  #
  # @return [ String ] Relative path to the unpacked archive.
  def download_revision(revision = nil)
    FileUtils.mkdir_p 'tmp'
    IO.write 'tmp/stocks.tar.gz', client.get_file('stocks.tar.gz', revision)

    FileUtils.rm_rf 'tmp/stocks'
    `cd tmp && tar xvzf stocks.tar.gz &>/dev/null`
    'tmp/stocks'
  rescue DropboxError
    nil
  ensure
    FileUtils.rm_rf 'tmp/stocks.tar.gz'
  end

  # Dropbox client instance.
  # Throws an error if authentification fails.
  #
  # @return [ DropboxClient ]
  def client
    @client ||= DropboxClient.new ENV.fetch('ACCESS_TOKEN', '')
  end
end
