# feed2email [![Gem Version](https://badge.fury.io/rb/feed2email.svg)](http://badge.fury.io/rb/feed2email) [![Build Status](https://travis-ci.org/agorf/feed2email.png?branch=master)](https://travis-ci.org/agorf/feed2email)

feed2email is a [headless][] RSS/Atom feed aggregator that sends feed entries
via email. It was initially written as a replacement of [rss2email][] and aims
to be simple, fast and easy to use.

[headless]: http://en.wikipedia.org/wiki/Headless_software
[rss2email]: http://www.allthingsrss.com/rss2email/

## Features

* Command-line feed management (add, remove, enable/disable)
* Feed fetching caching (_Last-Modified_ and _ETag_ HTTP headers)
* [Feed autodiscovery](http://www.rssboard.org/rss-autodiscovery)
* [OPML][] import/export of feed subscriptions
* Email sending with SMTP, [Sendmail][] (or compatible [MTA][]) or by writing to
  a file
* _text/html_ and _text/plain_ (Markdown) multipart emails
* Permanent redirection support for feed URLs

[OPML]: http://en.wikipedia.org/wiki/OPML
[Sendmail]: http://en.wikipedia.org/wiki/Sendmail
[MTA]: http://en.wikipedia.org/wiki/Message_transfer_agent

## Installation

As a [gem][] from [RubyGems][]:

~~~ sh
$ gem install feed2email
~~~

If the above command fails due to missing headers, make sure the following
packages for [curb][] and [sqlite3][] gems are installed. For Debian, issue:

~~~ sh
$ sudo apt-get install libcurl4-openssl-dev libsqlite3-dev
~~~

**Warning:** If you are updating from an earlier version of feed2email, make
sure you run `feed2email-migrate` to migrate its data before using it.

[gem]: http://rubygems.org/gems/feed2email
[RubyGems]: http://rubygems.org/
[curb]: https://rubygems.org/gems/curb
[sqlite3]: https://rubygems.org/gems/sqlite3

## Configuration

Through a [YAML][] file at `~/.feed2email/config.yml`.

Edit it with the `config` command:

~~~ sh
$ # same as "f2e c"
$ feed2email config
~~~

**Note:** The command will fail if the `EDITOR` environmental variable is not
set.

Each line in the configuration file contains a key-value pair. Each key-value
pair is separated with a colon, e.g.: `foo: bar`

[YAML]: http://en.wikipedia.org/wiki/YAML

### General options

* `recipient` (required) is the email address to send email to
* `sender` (required) is the email address to send email from (can be any)
* `send_method` (optional) is the method to send email with and can be `file`
  (default), `sendmail` or `smtp`
* `send_delay` (optional) is the number of seconds to wait between each email to
  avoid SMTP server throttling errors (default is `10`; use `0` to disable)
* `max_entries` (optional) is the maximum number of entries to process per feed
  (default is `20`; use `0` for unlimited)

### Logging options

* `log_path` (optional) is the _absolute_ path to the log file (default is
  `true` which logs to standard output; use `false` to disable logging)
* `log_level` (optional) is the logging verbosity level and can be `fatal`
  (least verbose), `error`, `warn`, `info` (default) or `debug` (most verbose)
* `log_shift_age` (optional) is the number of _old_ log files to keep or the
  frequency of rotation (`daily`, `weekly`, `monthly`; default is `0` so only
  the current log file is kept)
* `log_shift_size` (optional) is the maximum log file size in _megabytes_ and it
  only applies when `log_shift_age` is a number greater than zero (default is
  `1`)

### Sending options

#### File

This method simply writes emails to a file (named after the `recipient` config
option) in a path that you specify.

* `mail_path` (optional) is the path to write emails in (default is `~/Mail/`)

#### Sendmail

For this method you need to have [Sendmail][] or an [MTA][] with a
Sendmail-compatible interface (e.g. [msmtp][], [Postfix][]) set up and working
in your system.

* `sendmail_path` (optional) is the path to the Sendmail binary (default is
  `/usr/sbin/sendmail`)

[msmtp]: http://msmtp.sourceforge.net/
[Postfix]: http://en.wikipedia.org/wiki/Postfix_(software)

#### SMTP

For this method you need to have access to an SMTP service. [Mailgun][] has a
free plan.

* `smtp_host` (required) is the SMTP service hostname to connect to
* `smtp_port` (required) is the SMTP service port to connect to
* `smtp_user` (required) is the username of your email account
* `smtp_pass` (required) is the password of your email account (see the warning
   below)
* `smtp_starttls` (optional) controls STARTTLS (default is `true`; can also be
  `false`)
* `smtp_auth` (optional) controls the authentication method (default is `login`;
   can also be `plain` or `cram_md5`)

**Warning:** Unless it has correct restricted permissions, anyone with access in
your system will be able to read `config.yml` and your password. To prevent
this, feed2email will not run and complain if it detects the wrong permissions.
To set the correct permissions, issue `chmod 600 ~/.feed2email/config.yml`.

[Mailgun]: http://www.mailgun.com/

## Use

### Managing feeds

Add some feeds:

~~~ sh
$ feed2email add https://github.com/agorf/feed2email/commits.atom
Added feed:   1 https://github.com/agorf/feed2email/commits.atom
$ # same as "feed2email add https://github.com/agorf.atom"
$ f2e a https://github.com/agorf.atom
Added feed:   2 https://github.com/agorf.atom
~~~

Passing a website URL to the `add` command will have feed2email autodiscover any
feeds in that page:

~~~ sh
$ f2e add http://www.rubyinside.com/
0: http://www.rubyinside.com/feed/ "Ruby Inside" (application/rss+xml)
Please enter a feed to subscribe to: 0
Added feed:   3 http://www.rubyinside.com/feed/
$ f2e add http://thechangelog.com/137/
0: http://thechangelog.com/137/feed/ "The Changelog » #137: Better GitHub Issues with HuBoard and Ryan Rauh Comments Feed" (application/rss+xml)
1: http://thechangelog.com/feed/ "RSS 2.0 Feed" (application/rss+xml)
Please enter a feed to subscribe to: 1
Added feed:   4 http://thechangelog.com/feed/
$ # cancel autodiscovery by pressing Ctrl-C
$ f2e add http://thechangelog.com/137/
0: http://thechangelog.com/137/feed/ "The Changelog » #137: Better GitHub Issues with HuBoard and Ryan Rauh Comments Feed" (application/rss+xml)
Please enter a feed to subscribe to: ^C
~~~

**Note:** When autodiscovering feeds, feed2email lists only those that don't
already exist in your feed subscriptions.

The feed list so far:

~~~ sh
$ # same as "f2e l"
$ feed2email list
  1 https://github.com/agorf/feed2email/commits.atom
  2 https://github.com/agorf.atom
  3 http://www.rubyinside.com/feed/
  4 http://thechangelog.com/feed/

Subscribed to 4 feeds
~~~

A feed can be disabled so that it is not processed when `feed2email process`
runs with the `toggle` command:

~~~ sh
$ # same as "f2e t 1"
$ feed2email toggle 1
Toggled feed:   1 DISABLED https://github.com/agorf/feed2email/commits.atom
~~~

It can be enabled with the `toggle` command again:

~~~ sh
$ # same as "feed2email toggle 1"
$ f2e t 1
Toggled feed:   1 https://github.com/agorf/feed2email/commits.atom
~~~

It can also be removed from feed subscriptions permanently:

~~~ sh
$ # same as "f2e r 1"
$ feed2email remove 1
Remove feed:   1 https://github.com/agorf/feed2email/commits.atom
Are you sure? (yes/no) yes
Removed
~~~

### Migrating to/from feed2email

feed2email supports importing and exporting feed subscriptions as [OPML][]. This
makes it easy to migrate to and away from feed2email anytime you want.

Export feed subscriptions to `feeds.xml`:

~~~ sh
$ # same as "f2e e feeds.xml"
$ feed2email export feeds.xml
This may take a bit. Please wait...
Exported 3 feed subscriptions to feeds.xml
~~~

Import feed subscriptions from `feeds.xml`:

~~~ sh
$ # same as "f2e i feeds.xml"
$ feed2email import feeds.xml
Importing...
Feed already exists:   2 https://github.com/agorf.atom
Feed already exists:   3 http://www.rubyinside.com/feed/
Feed already exists:   4 http://thechangelog.com/feed/
~~~

Nothing was imported since all feeds already exist. Let's remove them first and
then try again:

~~~ sh
$ f2e r 2
Remove feed:   2 https://github.com/agorf.atom
Are you sure? (yes/no) yes
Removed
$ f2e r 3
Remove feed:   3 http://www.rubyinside.com/feed/
Are you sure? (yes/no) yes
Removed
$ f2e r 4
Remove feed:   4 http://thechangelog.com/feed/
Are you sure? (yes/no) yes
Removed
$ f2e l
No feeds
$ feed2email import feeds.xml
Importing...
Imported feed:   1 https://github.com/agorf.atom
Imported feed:   2 http://www.rubyinside.com/feed/
Imported feed:   3 http://thechangelog.com/feed/
Imported 3 feed subscriptions from feeds.xml
~~~

### Running

~~~ sh
$ # same as "f2e p"
$ feed2email process
~~~

When run, feed2email will go through your feed list, fetch each feed (if
necessary) and send an email for each new entry. Output is logged to the
standard output, unless configured otherwise.

When a new feed is detected (which is the case when feed2email runs for the
first time on your feed list), all of its entries are skipped and no email is
sent. This is so that you don't get spammed when you add a feed for the first
time.

### Getting help

Issue `feed2email help` (`f2e h`) or just `feed2email` (`f2e`) at any point to
get helpful text on how to use feed2email.

## Contributing

Using feed2email and want to help? [Let me know](http://agorf.gr/) how you use
it and if you have any ideas on how to improve it.

## License

Licensed under the MIT license (see [LICENSE.txt][license]).

[license]: https://github.com/agorf/feed2email/blob/master/LICENSE.txt

## Author

Aggelos Orfanakos, <http://agorf.gr/>
