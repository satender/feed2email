require 'feedzirra'
require 'forwardable'
require 'net/http'
require 'open-uri'
require 'stringio'
require 'uri'
require 'zlib'
require 'feed2email/core_ext'
require 'feed2email/entry'
require 'feed2email/feed_history'
require 'feed2email/feed_meta'
require 'feed2email/feeds'

module Feed2Email
  class Feed
    extend Forwardable

    class << self
      extend Forwardable

      def_delegators :Feed2Email, :config, :log
    end

    def self.process_all
      feed_uris.each_with_index do |uri, i|
        feed = new(uri)
        feed.process
        feed_uris[i] = feed.uri # persist possible permanent redirect
      end

      feed_uris.sync
    end

    def self.feed_uris
      return @feed_uris if @feed_uris

      log :debug, 'Loading feed subscriptions...'
      @feed_uris = Feeds.new(File.join(CONFIG_DIR, 'feeds.yml'))
      log :info, "Subscribed to #{'feed'.pluralize(feed_uris.size)}"
      @feed_uris
    end

    attr_reader :uri

    def initialize(uri)
      @uri = uri
    end

    def process
      log :info, "Processing feed #{uri} ..."

      return unless fetch_and_parse_feed

      if entries.any?
        process_entries
        history.sync
        meta.sync
      else
        log :warn, 'Feed does not have entries'
      end
    end

    private

    def fetch_feed
      log :debug, 'Fetching feed...'

      begin
        handle_permanent_redirection

        open(uri, fetch_feed_options) do |f|
          if f.meta['last-modified'] || meta.has_key?(:last_modified)
            meta[:last_modified] = f.meta['last-modified']
          end

          if f.meta['etag'] || meta.has_key?(:etag)
            meta[:etag] = f.meta['etag']
          end

          return decode_content(f.read, f.meta['content-encoding'])
        end
      rescue OpenURI::HTTPError => e
        if e.message == '304 Not Modified'
          log :info, 'Feed not modified; skipping...'
          return false
        end

        raise
      rescue => e
        log :error, 'Failed to fetch feed'
        log_exception(e)
        return false
      end
    end

    def handle_permanent_redirection
      parsed_uri = URI.parse(uri)
      http = Net::HTTP.new(parsed_uri.host, parsed_uri.port)
      http.use_ssl = (parsed_uri.scheme == 'https')
      response = http.head(parsed_uri.request_uri)

      if response.code == '301' && response['location'] =~ %r{\Ahttps?://}
        self.uri = response['location']
        log :warn, "Got permanently redirected! Updated feed location to #{uri}"
      end
    end

    def decode_content(data, content_encoding)
      case content_encoding
      when 'gzip'
        gz = Zlib::GzipReader.new(StringIO.new(data))
        xml = gz.read
        gz.close
      when 'deflate'
        xml = Zlib::Inflate.inflate(data)
      else
        xml = data
      end

      xml
    end

    def fetch_feed_options
      options = {
        'User-Agent' => "feed2email/#{VERSION}",
        'Accept-Encoding' => 'gzip, deflate',
      }

      if meta[:last_modified]
        options['If-Modified-Since'] = meta[:last_modified]
      end

      if meta[:etag]
        options['If-None-Match'] = meta[:etag]
      end

      options
    end

    def parse_feed(xml_data)
      log :debug, 'Parsing feed...'

      begin
        Feedzirra::Feed.parse(xml_data)
      rescue => e
        log :error, 'Failed to parse feed'
        log_exception(e)
        return false
      end
    end

    def fetch_and_parse_feed
      if xml_data = fetch_feed
        @data = parse_feed(xml_data)
      end

      @data && @data.respond_to?(:entries)
    end

    def uri=(uri)
      history.uri = uri
      meta.uri = uri
      @uri = uri
    end

    def entries
      @entries ||= data.entries.first(max_entries).map {|entry_data|
        Entry.new(entry_data, uri, title)
      }
    end

    def log(*args)
      Feed2Email::Feed.log(*args) # delegate
    end

    def max_entries
      config['max_entries'].to_i
    end

    def process_entries
      log :info, "Processing #{'entry'.pluralize(entries.size, 'entries')}..."
      entries.each {|entry| process_entry(entry) }
    end

    def process_entry(entry)
      log :info, "Processing entry #{entry.uri} ..."

      if history.any?
        if history.include?(entry.uri)
          log :debug, 'Skipping old entry...'
        else
          # Sleep between entry processing to avoid Net::SMTPServerBusy errors
          if config['send_delay'] > 0
            log :debug,
              "Sleeping for #{'second'.pluralize(config['send_delay'])}"
            sleep(config['send_delay'])
          end

          log :debug, 'Sending new entry...'

          begin
            entry.send_mail
          rescue => e
            log_exception(e)
          end

          if e.nil? # no errors
            history << entry.uri
          end

          e = nil
        end
      else
        log :debug, 'Skipping new feed entry...'
        history << entry.uri
      end
    end

    def history
      @history ||= FeedHistory.new(uri)
    end

    def meta
      @meta ||= FeedMeta.new(uri)
    end

    def log_exception(error)
      log :error, "#{error.class}: #{error.message.strip}"
      error.backtrace.each {|line| log :debug, line }
    end

    def_delegator :data, :title, :title

    def_delegator :Feed2Email, :config, :config

    def data; @data end
  end
end
