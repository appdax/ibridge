require 'benchmark'
require 'drive'
require 'importer'
require 'unifier'

namespace :import do
  desc 'Import stocks into the db'
  task :stocks, [:drop_feeds] do |_, args|
    args.with_defaults drop_feeds: true
    import_revisions(args[:drop_feeds])
  end
end

private

# Download each new revision and import them into the db.
# Finally unify the feeds and cleanup the collections.
def import_revisions(drop_feeds = true)
  return unless Drive.revisions_to_import?

  puts 'Downloading revisions...'

  time = Benchmark.realtime do
    Drive.each_revision_to_import do |rev, path|
      puts "Downloaded revision #{rev}"
      import_stocks(path)
    end

    unify_stocks(drop_feeds)
  end

  puts "Total time elapsed #{time.round(2)} seconds"
end

# Import the content at the provided path.
#
# @param [ String ] path A relative file path.
#
# @return [ Void ]
def import_stocks(path)
  puts 'Importing stocks...'
  time = Benchmark.realtime { Importer.new.path(path).run }
  puts "Time elapsed #{time.round(2)} seconds"
end

# Unify all stock feeds and cleanup the db.
#
# @param [ Boolean ] drop_feeds See Unifier#drop_feeds for more info.
#
# @return [ Void ]
def unify_stocks(drop_feeds)
  puts 'Unifying stocks...'
  time = Benchmark.realtime { Unifier.new.drop_feeds(drop_feeds).run }
  puts "Time elapsed #{time.round(2)} seconds"
end
