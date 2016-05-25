require 'client'

# The `Unifier` class does make a join of all specified feeds and stores the
# result under a common stock collection. It does optionally cleanup the
# feed collections if asked for.
#
# @example Run default process.
#   Unifier.new.run
#
# @example Drop feed collections once complete.
#   Unifier.new.drop_feeds(true).run
#
# @example Limit the size of each batch.
#   Unifier.new.batch_size(250).run
class Unifier < Client
  # Initializes the instance and sets all default values.
  #
  # @param [ Int ] batch_size Specifies the size of each batch of documents
  #                           the cursor will return on each GETMORE operation.
  #                           Defaults to: 500
  #
  # @param [ Boolean ] drop_feeds Set to true to drop all feed collections
  #                               after unification.
  #                               Defaults to: false
  #
  # @return [ Unifier ]
  def initialize(batch_size: 500, drop_feeds: false)
    drop_feeds(drop_feeds)
    super(batch_size: batch_size)
  end

  # Set to true to drop all feed collections after unification.
  #
  # @exmple Get the value.
  #   drop_feeds
  #   # => false
  #
  # @example Set the value.
  #   drop_feeds(true)
  #   # => self
  #
  # @param [ Int] value The value to set for.
  #
  # @return [ Int ]
  def drop_feeds(value = nil)
    @drop_feeds = value unless value.nil?
    value.nil? ? (@drop_feeds != false) : self
  end

  # Unifies all feeds of a stock into one stock object. It's recommended to run
  # the unify process only after a successful import.
  #
  # @return [ Void ]
  def run
    return unless db.collection_names.include? 'basics'

    stock_ids.each_slice(batch_size) do |stocks|
      copy_basics(stocks)
      unify_stocks(stocks)
    end

    drop_feed_collections if drop_feeds
  end

  private

  # Copies all documents from basics collection over to the stocks collection.
  #
  # @param [ Array<String> ] ids
  #
  # @return [ Void ]
  def copy_basics(ids)
    store = db[:basics]
    len   = ids.size

    store.find(_id: { '$in': ids }).batch_size(len).each_slice(len) do |basics|
      basics.map! { |stock| { insert_one: stock } }
      db[:stocks].bulk_write(basics, OPTS)
    end
  end

  # Unifies the specified feeds of the specified stocks.
  #
  # @param [ Array<String> ] ids
  # @param [ Array<String> ] feed_names The names of the feed to unify.
  #
  # @return [ Void ]
  def unify_stocks(ids, feed_stores = feed_collections)
    content = feeds_content_for_stocks(ids, feed_stores)
    bulks   = []

    content.each_pair do |id, feeds|
      bulks << { update_one: { filter: { _id: id },
                               update: { '$set': feeds } } }
    end

    db[:stocks].bulk_write(bulks, OPTS)
  end

  # Lazy enumerable of all stock IDS within the specified collection.
  #
  # @example
  #   stock_ids
  #   # => [{ _id: 1 }, { _id: 2} ]
  #
  # @param [ Symbol ] tbl The name of the collection.
  #
  # @return [ Array<Hash> ]
  def stock_ids(tbl = :basics)
    db[tbl].find.batch_size(batch_size).projection(_id: 1).map { |s| s[:_id] }
  end

  # Aggregate all feed content for specified stock in one hash object.
  #
  # @example
  #   feeds_content_for_stock '1234', [:intraday, :performance]
  #   # => { 1234: { intraday: {...}, performance: {...} } }
  #
  # @param [ Array<String> ] ids A list of stock IDs.
  # @param [ Array<String> ] feed_names The names of the feed to aggregate for.
  #
  # @param [ Hash ]
  def feeds_content_for_stocks(ids, stores)
    stores.each_with_object({}) do |store, feeds|
      store.find(_id: { '$in': ids }).batch_size(ids.size).each do |feed|
        id   = feed.delete(:_id)
        name = feed[:meta][:feed]
        feed = feed[:items] if feed[:meta][:multi]

        (feeds[id] ||= {})[name] = feed
      end
    end
  end

  # List of names from all feed collections.
  #
  # @example
  #   all_feed_names
  #   # => ['consorsbank-intraday', 'consorsbank-performance']
  #
  # @return [ Array<String> ]
  def feed_collections
    db.collections.keep_if { |col| col.name =~ /-/ }
  end

  # Drops all feed collections.
  #
  # @return [ Void ]
  def drop_feed_collections
    feed_collections.each(&:drop)
    db[:basics].drop
  end
end
