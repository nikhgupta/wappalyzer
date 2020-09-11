module Wappalyzer
  class Analysis
    class ImplicationResolver
      def self.call(data, techs)
        new(data, techs).process
      end

      def initialize(data, techs)
        @data = data
        @techs = techs
        @implies = {}
      end

      def references
        @techs.select { |_, info| info['implies'].any? || info['excludes'].any? }
      end

      def process
        return @data if references.empty?

        @data.each do |name, info|
          info['tech'].fetch('implies', []).each do |imp|
            resolve_implication(imp, name)
          end

          info['tech'].fetch('excludes', []).each do |imp|
            resolve_exclusion(imp, name)
          end
        end

        @data.merge!(@implies)
      end

      private

      def resolve_exclusion(imp, referer)
        raw = {
          'key' => referer,
          'field' => 'excluded',
          'pattern' => { 'confidence' => imp['confidence'], 'version' => '' }
        }
        return unless data_has_reference_with_raw_field?(imp)

        @data[imp['value']]['raw'].push(raw)
      end

      def resolve_implication(imp, referer)
        raw = {
          'key' => referer,
          'field' => 'implied',
          'pattern' => { 'confidence' => imp['confidence'], 'version' => '' }
        }
        return @data[imp['value']]['raw'].push(raw) if data_has_reference_with_raw_field?(imp)

        @implies[imp['value']] = {
          'name' => imp['value'], 'confidence' => imp['confidence'],
          'implied' => true, 'versions' => [], 'raw' => [raw], 'tech' => @techs[imp['value']]
        }
      end

      def data_has_reference_with_raw_field?(ref)
        @data[ref['value']] && @data[ref['value']]['raw']
      end
    end
  end
end
