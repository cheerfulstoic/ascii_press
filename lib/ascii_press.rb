require 'ascii_press/version'

require 'rubypress'
require 'asciidoctor'
require 'logger'
require 'stringio'
require 'json'

require 'active_support/core_ext/enumerable'

module AsciiPress
  # For setting the default logger
  def self.logger=(new_logger)
    @logger = new_logger
  end

  # A default STDOUT logger
  def self.logger
    @logger || Logger.new(STDOUT)
  end

  class Renderer
    class Rendering
      # @return [String] The HTML resulting from the asciidoc
      attr_reader :html

      # @return [Asciidoctor::Document] The document from the +asciidoctor+ gem
      attr_reader :doc

      # @return [Hash] The adoc file's attributes standardized with symbol keys and string values
      attr_reader :data

      # @return [Array <String>] The tags which will be set in +WordPress+
      attr_accessor :tags

      # @return [String] The title that will be used
      attr_accessor :title

      # Create a new {Rendering} object (intended to be used by Syncers like {WordPressSyncer})
      def initialize(html, doc, data)
        @html = html
        @doc = doc
        @data = data
        @title = doc.doctitle
      end

      # @!visibility private
      def attribute_value(name, default = nil)
        doc.attributes[name.to_s] || default
      end

      # @!visibility private
      def list_attribute_value(name, default = [])
        value = attribute_value(name, :VALUE_DOES_NOT_EXIST)
        if value == :VALUE_DOES_NOT_EXIST
          default
        else
          value.split(/\s*,\s*/)
        end
      end

      # @!visibility private
      def attribute_exists?(name)
        doc.attributes.key?(name.to_s)
      end
    end

    # @param options [Hash]
    # @option options [Hash] :asciidoc_options Passed directly to the +Asciidoctor.load+ method.  See the {http://asciidoctor.org/rdoc/Asciidoctor.html AsciiDoctor documentation}
    # @option options [Proc] :before_convertion Proc which is given the asciidoctor text.  Whatever is returned is passed to +Asciidoctor.load+.  See the {http://asciidoctor.org/rdoc/Asciidoctor.html AsciiDoctor documentation}
    # @option options [Proc] :after_conversion Proc which is given the html text after the Asciidoctor conversion.  Whatever is returned will be uploaded to WordPress
    # @option options [Proc] :rendering_proc Proc which is given the {Rendering} object (see below).  Changes made be made to the rendering in-place
    #
    def initialize(options = {})
      @options = options
    end

    # @!visibility private
    def render(adoc_file_path)
      doc = nil
      errors = capture_stderr do
        document_text = File.read(adoc_file_path)
        base_dir = ::File.expand_path(File.dirname(adoc_file_path))
        if before_convertion = @options[:before_convertion]
          document_text = before_convertion.call(document_text)
        end
        doc = Asciidoctor.load(document_text, @options[:asciidoc_options].merge(base_dir: base_dir))
      end
      puts errors.split(/[\n\r]+/).reject {|line| line.match(/out of sequence/) }.join("\n")

      html = doc.convert

      if after_conversion = @options[:after_conversion]
        html = after_conversion.call(html)
      end

      data = doc.attributes.each_with_object({}) do |(key, value), result|
        result[key.to_sym] = value.to_s
      end

      data.reject! {|_, value| value.nil? }

      Rendering.new(html, doc, data).tap do |rendering|
        rendering.tags = rendering.list_attribute_value('tags')
        rendering.tags << 'public' if rendering.attribute_exists?(:public)
        rendering.tags << 'private' if rendering.attribute_exists?(:private)

        if @options[:rendering_proc]
          rendering.tags = @options[:rendering_proc].call(rendering)
        end
      end
    end

    private
    def capture_stderr
      real_stderr, $stderr = $stderr, StringIO.new
      yield
      $stderr.string
    ensure
      $stderr = real_stderr
    end
  end

  class WordPressSyncer
    # Creates a synchronizer object which can be used to synchronize a set of asciidoc files to WordPress posts
    # @param hostname [String] Hostname for WordPress blog
    # @param username [String] Wordpress username
    # @param password [String] Wordpress password
    # @param post_type [String] Wordpress post type to synchronize posts with
    # @param renderer [Renderer] Renderer object which will be used to process asciidoctor files
    # @param options [Hash]
    # @option options [Logger] :logger Logger to be used for informational output.  Defaults to {AsciiPress.logger}
    # @option options [Proc] :filter_proc Proc which is given an +AsciiDoctor::Document+ object and returns +true+ or +false+ to decide if a document should be synchronized
    # @option options [Boolean] :delete_not_found Should posts on the WordPress server which don't match any documents locally get deleted?
    # @option options [Boolean] :generate_tags Should asciidoctor tags be synchronized to WordPress? (defaults to +false+)
    # @option options [String] :post_status The status to assign to posts when they are synchronized.  Defaults to +'draft'+.  See the {https://github.com/zachfeldman/rubypress rubypress} documentation
    def initialize(hostname, username, password, post_type, renderer, options = {})
      @hostname = hostname
      @wp_client = Rubypress::Client.new(host: @hostname, username: username, password: password)
      @post_type = post_type
      @logger = options[:logger] || AsciiPress.logger
      @renderer = renderer || Renderer.new
      @filter_proc = options[:filter_proc] || Proc.new { true }
      @delete_not_found = options[:delete_not_found]
      @generate_tags = options[:generate_tags]
      @options = options

      all_pages = @wp_client.getPosts(filter: {post_type: @post_type, number: 1000})
      @all_pages_by_post_name = all_pages.index_by {|post| post['post_name'] }
      log :info, "Got #{@all_pages_by_post_name.size} pages from the database"
    end

    # @param adoc_file_path [Array <String>] Paths of the asciidoctor files to synchronize
    # @param custom_fields [Hash] Custom fields for WordPress.
    def sync(adoc_file_paths, custom_fields = {})
      synced_post_names = []

      adoc_file_paths.each do |adoc_file_path|
        synced_post_names << sync_file_path(adoc_file_path, custom_fields)
      end

      if @delete_not_found
        (@all_pages_by_post_name.keys - synced_post_names).each do |post_name_to_delete|
          post_id = @all_pages_by_post_name[post_name_to_delete]['post_id']

          log :info, "Deleting missing post_name: #{post_name_to_delete} (post ##{post_id})"

          send_message(:deletePost, blog_id: @hostname, post_id: post_id)
        end

      end
    end

    private

    def sync_file_path(adoc_file_path, custom_fields = {})
      rendering = @renderer.render(adoc_file_path)

      return if !@filter_proc.call(rendering.doc)

      if !(slug = rendering.attribute_value(:slug))
        log :warn, "WARNING: COULD NOT POST DUE TO NO SLUG FOR: #{adoc_file_path}"
        return
      end

      title = rendering.title
      html = rendering.html

      log :info, "Syncing to WordPress: #{title} (slug: #{slug})"

      # log :info, "data: #{rendering.data.inspect}"

      custom_fields_array = custom_fields.merge('adoc_attributes' => rendering.doc.attributes.to_json).map {|k, v| {key: k, value: v} }
      content = {
                  post_type:     @post_type,
                  post_date:     Time.now - 60*60*24,
                  post_content:  html,
                  post_title:    title,
                  post_name:     slug,
                  post_status:   @options[:post_status] || 'draft',
                  custom_fields: custom_fields_array
                }

      content[:terms_names] = {post_tag: rendering.tags} if @generate_tags

      if page = @all_pages_by_post_name[slug]
        if page['custom_fields']
          content[:custom_fields].each do |f|
            found = page['custom_fields'].find { |field| field['key'] == f[:key] }
            f['id'] = found['id'] if found
          end
        end

        post_id = page['post_id'].to_i

        log :info, "Editing Post ##{post_id} on _#{@hostname}_ custom-field #{content[:custom_fields].inspect}"

        send_message(:editPost, blog_id: @hostname, post_id: post_id, content: content)
      else
        log :info, "Making a new post for '#{title}' on _#{@hostname}_"

        send_message(:newPost, blog_id: @hostname, content: content)
      end

      slug
    end

    def new_content_same_as_page?(content, page)
      main_keys_different = %i(post_content post_title post_name post_status).any? do |key|
        content[key] != page[key.to_s]
      end

      page_fields = page['custom_fields'].each_with_object({}) {|field, h| h[field['key']] = field['value'] }
      content_fields = content[:custom_fields].each_with_object({}) {|field, h| h[field[:key].to_s] = field[:value] }

      !main_keys_different && oyyyy
    end

    def log(level, message)
      @logger.send(level, "WORDPRESS: #{message}")
    end

    def send_message(message, *args)
      @wp_client.send(message, *args).tap do |result|
        raise "WordPress #{message} failed!" if !result
      end
    end
  end

  DEFAULT_SLUG_RULES = {
    'Cannot start with `-` or `_`' => -> (slug) { !%w(- _).include?(slug[0]) },
    'Cannot end with `-` or `_`' => -> (slug) { !%w(- _).include?(slug[-1]) },
    'Cannot have multiple `-` in a row' => -> (slug) { !slug.match(/--/) },
    'Must only contain letters, numbers, hyphens, and underscores' => -> (slug) { !!slug.match(/^[a-z0-9\-\_]+$/) },
  }

  def self.slug_valid?(slug, rules = DEFAULT_SLUG_RULES)
    slug && rules.values.all? {|rule| rule.call(slug) }
  end

  def self.violated_slug_rules(slug, rules = DEFAULT_SLUG_RULES)
    return ['No slug'] if slug.nil?

    rules.reject do |desc, rule|
      rule.call(slug)
    end.map(&:first)
  end

  def self.verify_adoc_slugs!(adoc_paths, rules = DEFAULT_SLUG_RULES)
    data = adoc_paths.map do |path|
      doc = Asciidoctor.load(File.read(path))

      slug = doc.attributes['slug']
      if !slug_valid?(slug, rules)
        violations = violated_slug_rules(slug, rules)
        [path, slug, violations]
      end
    end.compact

    if data.size > 0
      require 'colorize'
      data.each do |path, slug, violations|
        puts 'WARNING!!'.red
        puts "The document #{path.light_blue} has the slug #{slug.inspect.light_blue} which in invalid because:"
        violations.each do |violation|
          puts "  - #{violation.yellow}"
        end
      end
      raise 'Invalid slugs.  Cannot continue'
    end
  end
end
