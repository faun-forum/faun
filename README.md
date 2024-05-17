# Faun Forum

Faun is a minimalistic directory-based forum and asset catalog engine for small communities. It is
a self-hosting solution which can run locally or in any server environment without any hassle.

Faun works with local directory in a file system, avoiding complexity of database connections. Faun
directory has a special structure-by-convention, which allows the forum to be used with no software
at all: just with a file browser and any text editor supporting markdown and YAML.

The web app is made with pure HTML and CSS: no javascript. Thus, it can easily be browsed with Tor
and privacy-preserving browsers. It also uses no cookies and thus avoids spam of banners and other
sorts of confirmation dialogs.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add faun

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install faun

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. 
You can also run `bin/faun` for an command-line tool and `bin/faund` to run a web server.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new 
version, update the version number in `version.rb`, and then run `bundle exec rake release`, which
will create a git tag for the version, push git commits and the created tag, and push the `.gem`
file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/faun-forum/faun.
