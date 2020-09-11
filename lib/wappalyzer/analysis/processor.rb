module Wappalyzer
  class Analysis
    class Processor
      MAPPING = {
        one_to_one: %i[url html css robots cert_issuer],
        one_to_many: %i[scripts],
        many_to_many: %i[cookies meta headers js]
      }.freeze

      def self.call(data, techs)
        new(data, techs).process
      end

      def initialize(data, techs)
        @data = data
        @techs = techs
      end

      def process
        @techs.map do |_, tech|
          MAPPING.map do |method, fields|
            fields.map do |field|
              data = field != :js ? @data : @data['js'][tech['name']]
              send(method, tech, data, field.to_s)
            end
          end
        end.flatten.compact
      end

      private

      def one_to_one(tech, data, field)
        tech[field].map do |pattern|
          add_tech_if_regex_match(field, pattern, tech, data[field])
        end
      end

      def one_to_many(tech, data, field)
        (data[field] || []).map do |value|
          tech[field].map do |pattern|
            add_tech_if_regex_match(field, pattern, tech, value)
          end
        end
      end

      def many_to_many(tech, data, field)
        return if !data || !data[field]

        (tech[field] || []).map do |key, patterns|
          patterns.map do |pattern|
            items = select_items_for_maybe_regex_key(key, field, pattern, data)
            items.map do |value|
              add_tech_if_regex_match(field, pattern, tech, value, key)
            end
          end
        end
      end

      def add_tech_if_regex_match(field, pattern, tech, value, key = nil)
        regex = Regexp.new(pattern['regex'], Regexp::IGNORECASE)
        return unless value
        return if value != true && value !~ regex

        { 'key' => key, 'tech' => tech, 'field' => field,
          'pattern' => pattern, 'version' => version_for(pattern, value) }
      end

      def select_items_for_maybe_regex_key(key, field, pattern, data)
        items = data[field].fetch(key, [])
        return items unless pattern['key_regex']

        (data[field] || []).select do |k|
          k =~ Regexp.new(key, Regexp::IGNORECASE)
        end.values.flatten
      end

      def version_for(pattern, value)
        return if pattern['version'].to_s.strip.empty?

        matches = Regexp.new(pattern['regex'], Regexp::IGNORECASE).match(value)
        return unless matches

        resolved = pattern['version']
        matches.captures.each.with_index do |match, index|
          resolved = resolve_version(pattern['version'], match, index + 1)
        end
        resolved
      end

      def resolve_version(version, match, index)
        r = Regexp.new("\\\\#{index}(?:\\?([^:]+):(.*))$")
        ternary = r.match(version)
        if ternary && ternary[1]
          version = version.sub(ternary[0], match ? ternary[1] : ternary[2])
        end
        version.strip.gsub(Regexp.new("\\\\#{index}"), match || '')
      end
    end
  end
end
