require 'nokogiri'

module Feed2Email
  class OPMLImporter
    def self.import(path)
      require 'feed2email/feed'

      n = 0

      open(path) do |f|
        new(f).import do |uri|
          if feed = Feed[uri: uri]
            warn "Feed already exists: #{feed}"
          else
            feed = Feed.new(uri: uri)

            if feed.save(raise_on_failure: false)
              puts "Imported feed: #{feed}"
              n += 1
            else
              warn "Failed to import feed: #{feed}"
            end
          end
        end
      end

      n
    end

    def initialize(io)
      @io = io
    end

    def import(&blk)
      uris.each(&blk)
    end

    private

    def data
      io.read
    end

    def io; @io end

    def uris
      Nokogiri::XML(data).css('opml body outline').map {|outline|
        outline['xmlUrl']
      }.compact
    end
  end
end
