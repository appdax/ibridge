require 'client'
require 'json'

# The `Importer` class handles the logic to import the newest stock updates.
# New stocks will be added while outdated stock feeds will be updated.
#
# The basic stock informations like the name, the WKN or ISIN number gets
# added to the basics-collection regardless of the source.
#
# All other feeds gets inserted into own collections. If the collection does
# not exist at the time, it will be added on the fly.
# See `collection_name_for_feed` for how the collection will be named.
#
# @example Run default process.
#   Importer.new.run
#
# @example Limit the size of each batch.
#   Importer.new.batch_size(250).run
#
# @example Switch import folder.
#   Importer.new.path('tmp/stocks').run
#
# @example List all files for import.
#   Importer.new.path('tmp/stocks').files_to_import
#   # => ['tmp/stocks/stock1.json', 'tmp/stocks/stock2.json']
class Importer < Client
  # Initialize the importer by assigning all default values.
  #
  # @param [ Int ] batch_size Specifies the size of each batch of documents
  #                           the cursor will return on each GETMORE operation.
  #                           Defaults to: 100
  #
  # @param [ String ] path Specifies the folder with the json files
  #                        to import into the db.
  #
  # @return [ Importer ]
  def initialize(batch_size: 500, path: 'tmp/stocks')
    path(path)
    super(batch_size: batch_size)
  end

  # Path to the folder with the json files to import into the db.
  #
  # @exmple Get the value.
  #   path
  #   # => 'tmp/stocks'
  #
  # @example Set the value.
  #   path('tmp/value')
  #   # => self
  #
  # @param [ Int] value The value to set for.
  #
  # @return [ Int ]
  def path(value = nil)
    @path = value unless value.nil?
    @path ||= 'tmp/stocks'
    value.nil? ? @path : self
  end

  # Files for import found under the provided path.
  #
  # @return [ Array<String> ] Array for file names.
  def files_to_import
    Dir[File.join(path, '*.json')]
  end

  # Iterate through each JSON file and import its content.
  #
  # @return [ Void ]
  def run
    files_to_import.each_slice(batch_size, &method(:import_files))
  end

  private

  # Bulk import the content of the specified files.
  #
  # @param [ Array<String> ] files Relative paths to the JSON files.
  #
  # @return [ Void ]
  def import_files(files)
    stocks = files.map! { |f| JSON.parse(IO.read(f), symbolize_names: true) }

    import_stocks(stocks)
  end

  # Bulk import of the provided stock data.
  #
  # @param [ Array<Hash> ] stocks The data to import.
  #
  # @return [ Void ]
  def import_stocks(stocks)
    basics = basics_of_stocks(stocks)
    feeds  = feeds_of_stocks(stocks)

    import_basics(basics) if basics.any?

    feeds.each { |analyses| import_feeds(analyses) if analyses.any? }
  end

  # Bulk import of basic stock info.
  #
  # @example Import basic data.
  #   import_basics [isin: 'AGP8696W1045', wkn: 789125]
  #
  # @param [ Array<Hash> ] basics The basic stock data.
  #
  # @return [ Void ]
  def import_basics(basics)
    timestamp = Time.now.utc

    basics.map! { |stock| { insert_one: stock.merge!(updated_at: timestamp) } }

    db[:basics].bulk_write(basics, OPTS)
  end

  # Bulk import of stock data for one feed type.
  #
  # @example Import feed data.
  #   import_feed 'screener', [macd: 1, interest: 3]
  #
  # @param [ Array<Hash> ] feeds The feed data.
  #
  # @return [ Void ]
  def import_feeds(feeds)
    table = collection_name_for_feed(feeds[0])

    feeds.map! do |feed|
      {
        replace_one: {
          replacement: feed, upsert: true,
          filter: { _id: feed[:_id], 'meta.age': { '$gte': feed[:meta][:age] } }
        }
      }
    end

    db[table].bulk_write(feeds, OPTS)
  end

  # Extract the basic infos of the specified stocks.
  #
  # @param [ Array<Hash> ] stocks Array of stock objects.
  #
  # @return [ Array<Hash> ]
  def basics_of_stocks(stocks)
    stocks.map do |stock|
      basics = stock[:basic]
      basics.merge!(_id: basics[:isin])
    end
  end

  # Extract the feed infos of the specified stocks.
  #
  # @param [ Array<Hash> ] stocks Array of stock objects.
  #
  # @return [ Hash ]
  def feeds_of_stocks(stocks)
    stocks.each_with_object({}) do |stock, feeds|
      id = { _id: stock[:basic][:isin] }

      stock[:feeds].each do |feed|
        (feeds[feed[:meta][:feed]] ||= []) << feed.merge!(id)
      end
    end.values
  end

  # Name of the collection to use for the specified feed.
  #
  # @param [ Hash ] The feed object.
  #
  # @return [ String ]
  def collection_name_for_feed(feed)
    "#{feed[:meta][:source]}-#{feed[:meta][:feed]}"
  end
end
