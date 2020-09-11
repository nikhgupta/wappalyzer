module Wappalyzer
  class Analysis
    class Formatter
      def self.call(data, techs)
        new(data, techs).process
      end

      def initialize(data, techs)
        @data = data
        @techs = techs
      end

      def process
        @data.group_by { |a| a['tech']['name'] }.transform_values do |tech|
          {
            'name' => tech[0]['tech']['name'],
            'confidence' => sum_of_confidence(tech),
            'versions' => collect_versions(tech),
            'tech' => tech[0]['tech'],
            'raw' => tech.map { |a| a.except('tech') }
          }
        end
      end

      private

      def sum_of_confidence(tech)
        tech.map { |r| r['pattern']['confidence'] }.sum
      end

      def collect_versions(tech)
        tech.map { |r| r['version'] }.reject { |a| a.nil? || a.empty? }
      end
    end
  end
end
