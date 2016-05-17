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

renderer = AsciiPress::Renderer.new(extra_tags_proc: -> (rendering) { ['tag-for-all'] },
                                    asciidoc_options: {attributes: 'allow-uri-read'})

syncer = AsciiPress::WordPressSyncer.new(WP_HOSTNAME, WP_USERNAME, WP_PASSWORD, renderer, WP_POST_TYPE
                                         post_type: ENV['BLOG_POST_TYPE'],
                                         logger: LOGGER,
                                         delete_not_found: delete_not_found,
                                         generate_tags: true,
                                         filter_proc: filter_proc)

adoc_file_paths = `find . -name "*.adoc"`.split(/[\n\r]+/)
syncer.sync(adoc_file_paths)
```

See the [API documentation](http://www.rubydoc.info/github/cheerfulstoic/ascii_press/master) for more details on arguments and options

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/ascii_press. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

