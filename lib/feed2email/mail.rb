module Feed2Email
  SENDMAIL = ENV['SENDMAIL'] || '/usr/sbin/sendmail'

  class Mail
    def initialize(entry)
      @entry = entry
    end

    def body
      body_data = {
        :uri     => @entry.uri.escape_html,
        :title   => @entry.title.escape_html,
        :content => @entry.content,
      }
      %{
        <html>
        <body>
        <h1><a href="%{uri}">%{title}</a></h1>
        %{content}
        <p><a href="%{uri}">%{uri}</a></p>
        <p>--<br>
        Sent by <a href="https://github.com/agorf/feed2email">feed2email
        #{VERSION}</a> at #{Time.now}</p>
        </body>
        </html>
      }.gsub(/^\s+/, '') % body_data
    end

    def from
      from_data = {
        :name  => @entry.feed.title,
        :email => @entry.author,
      }

      if from_data[:email].nil? || from_data[:email]['@'].nil?
        from_data[:email] = to
      end

      '"%{name}" <%{email}>' % from_data
    end

    def html_part
      part = ::Mail::Part.new
      part.content_type = 'text/html; charset=UTF-8'
      part.body = body
      part
    end

    def mail
      ::Mail.new.tap do |m|
        m.from      = from
        m.to        = to
        m.subject   = subject
        m.html_part = html_part
      end
    end

    def send
      open("|#{SENDMAIL} #{to}", 'w') do |f|
        f.write(mail)
      end
    end

    def subject
      @entry.title
    end

    def to
      @entry.feed.options[:recipient]
    end
  end
end
