# AsciiPress

AsciiPress is a gem which is designed to make it easy to publish a set of [asciidoc](http://asciidoctor.org/) files to a specific `post_type` in a WordPress site.  You can see an example in action in the [`render.rb` file](https://github.com/neo4j-contrib/developer-resources/blob/gh-pages/render.rb) to generate the Neo4j developer website.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ascii_press'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ascii_press

## Usage

The main API to synchronize documents with WordPress in the `WordPressSyncer`.  To create a new `WordPressSyncer` you need to provide a hostname, username, password, and a `AsciiPress::Renderer` object.  The following is an example:

```ruby
WP_HOSTNAME = 'fakepress.com'
WP_USERNAME = 'fake'
WP_PASSWORD = 'pass'
WP_POST_TYPE = 'faq'

# Available keys for options are:
# `:asciidoc_options`: Passed directly to the `Asciidoctor.load` method
# `:before_convertion`: Proc which is given the asciidoctor text.  Whatever is returned is passed to `Asciidoctor.load`
# `:after_conversion`: Proc which is given the html text after the Asciidoctor conversion.  Whatever is returned will be uploaded to WordPress
# `:extra_tags_proc`: Proc which is given the `AsciiPress::Renderer::Rendering` object (see below).  Whatever is returned will be used as the WordPress Post's tags
renderer = AsciiPress::Renderer.new(extra_tags_proc: -> (rendering) { ['tag-for-all'] }, asciidoc_options: {attributes: 'allow-uri-read'})

wp_syncer = AsciiPress::WordPressSyncer.new(WP_HOSTNAME, WP_USERNAME, WP_PASSWORD, renderer, WP_POST_TYPE
                                         post_type: ENV['BLOG_POST_TYPE'],
                                         logger: LOGGER,
                                         delete_not_found: delete_not_found,
                                         generate_tags: true,
                                         filter_proc: filter_proc)
```

### `AsciiPress::Renderer::Rendering`

Provides the following methods:

 * `html` The HTML resulting from the asciidoc
 * `doc` The `Asciidoctor::Document` object from the `asciidoctor` gem
 * `data` The adoc file's attributes standardized with symbol keys and string values
 * `tags` The tags which will be set in `WordPress`


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/ascii_press. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

