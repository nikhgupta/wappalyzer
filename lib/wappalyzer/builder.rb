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
        item = sanitize(name, item)
        item = @block.call(name, item, @categories) if @block
        [name, item] # .reject { |_k, v| !v || v.empty? }]
      end.to_h

      @technologies.merge!(data)
    end

    def sanitize(name, data)
      {
        name: name,
        description: data['description'],
        categories: @categories.values_at(*data['cats']),
        slug: name.parameterize,
        url: transform(data['url']),
        headers: transform(data['headers']),
        cookies: transform(data['cookies']),
        html: transform(data['html']),
        css: transform(data['css']),
        cert_issuer: transform(data['cert_issuer']),
        robots: transform(data['robots']),
        meta: transform(data['meta']),
        scripts: transform(data['scripts']),
        js: transform(data['js'], case_sensitive: true),
        implies: transform(data['implies']),
        excludes: transform(data['excludes']),
        icon: data['icon'] || 'default.svg',
        website: data['website'],
        cpe: data['cpe']
      }
    end

    def transform(patterns, case_sensitive: false)
      return [] if !patterns || patterns.empty?

      patterns = { main: patterns } if patterns.is_a?(String) || patterns.is_a?(Array)
      parsed = {}
      patterns.each do |key, val|
        val = [val].flatten.map { |p| parse_pattern(p) }
        parsed[case_sensitive ? key : key.downcase] = val
      end
      parsed[:main] || parsed
    end

    def parse_pattern(pattern, regex: false)
      attrs = {}
      pattern.split('\\;').each.with_index do |attr, i|
        if i.positive?
          attrs.merge!(attr.split(':')[0].to_sym => attr.split(':', 2)[1])
        elsif regex
          regex = regex.gsub('\/', '\\/').gsub('[^]', '.').gsub('[\\s\\S]*', '.*')
          attrs.merge!(value: attr, regex: Regexp.new(regex, Regexp::IGNORECASE))
        else
          attr = attr.gsub('\/', '\\/').gsub('[^]', '.').gsub('[\\s\\S]*', '.*')
          attrs.merge!(value: attr, regex: attr)
        end
      end
      attrs[:confidence] = attrs[:confidence].to_i if attrs[:confidence]
      { confidence: 100, version: '', value: '', regex: '' }.merge(attrs.reject { |_k, v| v.nil? })
    end
  end
end
