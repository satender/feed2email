require 'sequel'

module Feed2Email
  class Database
    def initialize(connect_options)
      Sequel::Model.db = Sequel.connect(connect_options)
      setup_schema
    end

    private

    def connection; Sequel::Model.db end

    def setup_schema
      connection.create_table? :feeds do
        primary_key :id
        String :uri, null: false, unique: true
        TrueClass :enabled, null: false, default: true
        String :etag
        String :last_modified
        Time :last_processed_at
      end

      connection.create_table? :entries do
        primary_key :id
        foreign_key :feed_id, :feeds, null: false, index: true,
                                      on_delete: :cascade
        String :uri, null: false, unique: true
      end
    end
  end
end