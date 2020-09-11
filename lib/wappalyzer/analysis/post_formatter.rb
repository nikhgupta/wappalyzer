module Wappalyzer
  class Analysis
    class PostFormatter < Formatter
      def self.call(data, techs)
        new(data, techs).process
      end

      def initialize(data, techs)
        @data = data
        @techs = techs
      end

      def process
        boost_confidence_and_transform
        adjust_confidence_for_references

        @data = @data.values.sort_by do |info|
          info['confidence'] / (info['implied'] ? 1.5 : 1) * -1
        end
      end

      protected

      def boost_confidence_and_transform
        @data = @data.transform_values do |info|
          info['raw'] = info['raw'].map do |r|
            r.except('pattern').merge(r['pattern']).merge('version' => r['version'])
          end
          info.merge(
            'confidence' => boosted_confidence(info['raw']),
            'versions' => collect_versions(info['raw']),
            'best_version' => find_best_version(info['raw'])
          )
        end
      end

      def adjust_confidence_for_references
        @data = @data.transform_values do |info|
          info['confidence'] += boost_multiplier_via_referred(info['raw'], 'implied')
          info['confidence'] -= boost_multiplier_via_referred(info['raw'], 'excluded', check: true)
          info
        end
      end

      def find_best_version(raw)
        version ||= find_best_version_via_field(raw, nil)
        version ||= find_best_version_via_field(raw, 'js')
        version ||= find_best_version_via_field(raw, 'scripts')
        return version if version

        version = raw.detect { |k| k['version'] }
        version ? version['version'] : nil
      end

      private

      def pure_confidence(item)
        return 0 if %w[implied excluded].include?(item['field'])

        item['confidence'].to_i
      end

      def count_confidence_values_with(raw)
        raw = raw.map do |r|
          r['confidence'] unless %w[implied excluded].include?(r['field'])
        end
        raw.compact.count { |c| yield(c) }
      end

      def boosted_confidence(raw)
        zeroes = count_confidence_values_with(raw, &:zero?)
        positives = count_confidence_values_with(raw, &:positive?)
        boost = positives.positive? ? 25 * zeroes : 0
        boost + raw.map { |r| pure_confidence(r) }.sum
      end

      def boost_multiplier_via_referred(raw, key, check: false)
        ref = raw.detect { |r| r['field'] == key }
        return 0 if !ref || (check && !@data[ref['key']])

        (ref['confidence'] * @data[ref['key']]['confidence'] / 100.0).to_i
      end

      def find_best_version_via_field(raw, field = nil)
        raw = raw.select { |r| r['version'] && (!field || r['field'] == field) }

        version = find_best_version_by_grouping(raw) do |v|
          v.map { |r| r['confidence'] }.inject(0, :+)
        end

        version || find_best_version_by_grouping(raw, &:count)
      end

      def find_best_version_by_grouping(raw)
        grouped = raw.group_by { |a| a['version'] }.transform_values { |v| yield(v) }
        return if grouped.empty?

        max_v = grouped.values.max
        maxed = grouped.select { |_k, v| v == max_v }
        maxed.keys.first if maxed.count == 1
      end
    end
  end
end
