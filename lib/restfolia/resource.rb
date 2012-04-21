module Restfolia

  # Public: Resource is the representation of JSON response. It transforms
  # all JSON attributes in attributes and all JSON objects in Resources.
  # Resource provides a "links" method, to help with hypermedia navigation.
  #
  # Examples
  #
  #   resource = Resource.new(:attr_test => "test")
  #   resource.attr_test  # => "test"
  #   resource.links  # => []
  #
  #   resource = Resource.new(:attr_test => {:nested => "nested"},
  #                           :links => {:href => "http://service.com",
  #                                      :rel => "self",
  #                                      :type => "application/json"})
  #   resource.attr_test  # => #<Restfolia::Resource ...>
  #   resource.links  # => [#<Restfolia::EntryPoint ...>]
  #
  #   resource = Resource.new(:attr_test => "test",
  #                           :attr_tags => ["tag1", "tag2"],
  #                           :attr_array_obj => [{:nested => "nested"}],
  #                           :links => [{:href => "http://service.com",
  #                                       :rel => "contacts",
  #                                       :type => "application/json"},
  #                                      {:href => "http://another.com",
  #                                       :rel => "relations",
  #                                       :type => "application/json"}
  #                                     ])
  #   resource.attr_test  # => "test"
  #   resource.attr_tags  # => ["tag1", "tag2"]
  #   resource.attr_array_obj  # => [#<Restfolia::Resource ...>]
  #   resource.links  # => [#<Restfolia::EntryPoint ...>, #<Librarian::EntryPoint ...>]
  #   resource.links("relations").get  # => #<Restfolia::Resource ...>
  #
  #
  # By default, "links" method, expects from JSON to be the following format:
  #   "links" : { "href" : "http://fakeurl.com/some/service",
  #               "rel" : "self",
  #               "type" : "application/json"
  #             }
  #
  class Resource

    # Public: Returns the Hash that represents parsed JSON.
    attr_reader :_json

    # Public: Initialize a Resource.
    #
    # json - Hash that represents parsed JSON.
    #
    # Raises ArgumentError if json parameter is not a Hash object.
    def initialize(json)
      unless json.is_a?(Hash)
        raise(ArgumentError, "json parameter have to be a Hash object", caller)
      end
      @_json = json

      #Add json keys as methods of Resource
      #http://blog.jayfields.com/2008/02/ruby-replace-methodmissing-with-dynamic.html
      @_json.each do |method, value|
        next if self.respond_to?(method)  #avoid method already defined
        value = look_for_resource(value)

        (class << self; self; end).class_eval do
          define_method(method) do |*args|
            value
          end
        end
      end
    end

    # Public: Read links from Resource. Links are optional.
    # See Resource root doc for details.
    #
    # rel - Optional String parameter. Filter links by rel attribute.
    #
    # Returns Empty Array or Array of EntryPoints, if "rel" is informed
    # it returns nil or an instance of EntryPoint.
    def links(rel = nil)
      @links ||= parse_links(@_json)

      return nil if @links.empty? && !rel.nil?
      return @links if @links.empty? || rel.nil?

      @links.detect { |ep| ep.rel == rel }
    end

    protected

    # Internal: Parse links from hash. Always normalize to return
    # an Array of EntryPoints. Check if link has :href and :rel
    # keys.
    #
    # Returns Array of EntryPoints or Empty Array if :links not exist.
    # Raises RuntimeError if link doesn't have :href and :rel keys.
    def parse_links(json)
      links = json[:links]
      return [] if links.nil?

      links = [links] unless links.is_a?(Array)
      links.map do |link|
        if link[:href].nil? || link[:rel].nil?
          msg = "Invalid hash link: #{link.inspect}"
          raise(RuntimeError, msg, caller)
        end
        EntryPoint.new(link[:href], link[:rel])
      end
    end

    # Internal: Check if value is eligible to become a Restfolia::Resource.
    # If value is Array object, looks inner contents, using rules below.
    # If value is Hash object, it becomes a Restfolia::Resource.
    # Else return itself.
    #
    # value - object to be checked.
    #
    # Returns value itself or Restfolia::Resource.
    def look_for_resource(value)
      if value.is_a?(Array)
        value = value.inject([]) do |resources, array_obj|
          resources << look_for_resource(array_obj)
        end
      elsif value.is_a?(Hash)
        value = Resource.new(value)
      end
      value
    end

  end

end