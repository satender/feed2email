require 'logger'
require 'net/smtp'
require 'pathname'
require 'feed2email/config'
require 'feed2email/database'

module Feed2Email
  def self.config
    @config ||= Config.new(config_path)
  end

  def self.config_path
    root.join('config.yml').to_s
  end

  def self.database_path
    root.join('feed2email.db').to_s
  end

  def self.logger
    return @logger if @logger

    if config['log_path'] == true
      logdev = $stdout
    elsif config['log_path'] # truthy but not true (a path)
      logdev = File.expand_path(config['log_path'])
    end

    @logger = Logger.new(logdev, config['log_shift_age'],
                         config['log_shift_size'].megabytes)
    @logger.level = Logger.const_get(config['log_level'].upcase)
    @logger
  end

  def self.setup_database
    @db ||= Database.new(
      adapter:       'sqlite',
      database:      database_path,
      loggers:       [logger],
      sql_log_level: :debug
    )
  end

  def self.smtp_connection
    return @smtp if @smtp

    @smtp = Net::SMTP.new(config['smtp_host'], config['smtp_port'])
    @smtp.enable_starttls if config['smtp_starttls']
    @smtp.start('localhost',
      config['smtp_user'],
      config['smtp_pass'],
      config['smtp_auth'].to_sym
    )
    at_exit { @smtp.finish }

    @smtp
  end

  def self.root
    @root ||= Pathname.new(ENV['HOME']).join('.feed2email')
  end
end
