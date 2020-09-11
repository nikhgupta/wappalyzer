module Wappalyzer
  class Builder
    class RuleParser
      REQUIRE_PARSING = {
        case_sensitive: %i[js],
        case_insensitive: %i[
          url headers cookies html css cert_issuer robots meta scripts
          implies excludes
        ]
      }.freeze

      def self.call(data)
        new(data).process
      end

      def initialize(data)
        @data = data
        @parsed = {}
      end

      def process
        REQUIRE_PARSING.each do |key, fields|
          case_sensitive = key == :case_sensitive
          fields.each do |f|
            @parsed[f] = transform(@data[f.to_s], case_sensitive: case_sensitive)
          end
        end

        @parsed
      end

      private

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
end
