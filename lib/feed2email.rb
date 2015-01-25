require 'pathname'
require 'feed2email/config'
require 'feed2email/database'
require 'feed2email/logger'
require 'feed2email/smtp_connection'

module Feed2Email
  def self.config
    @config ||= Config.new(config_path)
  end

  def self.config_path
    root.join('config.yml').to_s
  end

  def self.database
    @database ||= Database.new(
      adapter:       'sqlite',
      database:      database_path,
      loggers:       [logger],
      sql_log_level: :debug
    )
  end

  def self.database_path
    root.join('feed2email.db').to_s
  end

  def self.logger
    @logger ||= Logger.new(
      config['log_path'], config['log_level'], config['log_shift_age'],
      config['log_shift_size']
    ).logger
  end

  def self.root
    @root ||= Pathname.new(ENV['HOME']).join('.feed2email')
  end

  def self.smtp_connection
    @smtp_connection ||= SMTPConnection.new(
      config.slice(*config.keys.grep(/\Asmtp_/))
    )
  end
end
