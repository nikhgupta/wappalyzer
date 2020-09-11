module Wappalyzer
  class Builder
    JSON_URL = 'https://raw.githubusercontent.com/AliasIO/wappalyzer/master/src/technologies.json'.freeze

    def self.update!(**options, &block)
      new(**options, &block).run
    end

    def self.data(cache: nil)
      cache ||= Wappalyzer::CACHE_PATH
      JSON.parse File.read(cache)
    end

    def initialize(cache: nil, remote: nil, ours: nil, &block)
      @ours = ours
      @remote = remote || JSON_URL
      @cache = cache || Wappalyzer::CACHE_PATH
      @block = block

      @categories = {}
      @technologies = {}
    end

    def run
      fetch_remote
      fetch_ours

      save_json
    end

    protected

    def fetch_remote
      response = HTTParty.get(@remote)
      json = JSON.parse(response.body)
      @categories = json['categories'].map { |k, v| [k.to_i, v] }.to_h

      parse json
    end

    def fetch_ours
      return if !@ours || @ours.strip.to_s.empty?

      json = File.exist?(@ours) ? File.read(@ours) : @ours
      json = JSON.parse(json)

      parse json
    end

    def save_json
      File.open(@cache, 'w') { |f| f.puts @technologies.to_json }
      @cache
    end

    private

    def parse(json)
      data = json['technologies'].map do |name, item|
        item = parse_each(name, item)
        item = @block.call(name, item, @categories) if @block
        [name, item] # .reject { |_k, v| !v || v.empty? }]
      end.to_h

      @technologies.merge!(data)
    end

    def parse_each(name, data)
      Wappalyzer::Builder::RuleParser.call(data).merge(
        name: name,
        cpe: data['cpe'],
        slug: name.parameterize,
        website: data['website'],
        description: data['description'],
        icon: data['icon'] || 'default.svg',
        categories: @categories.values_at(*data['cats'])
      )
    end
  end
end
