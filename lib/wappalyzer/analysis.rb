module Wappalyzer
  class Analysis
    MAPPING = {
      om: %w[scripts],
      mm: %w[cookies meta headers],
      oo: %w[url html css robots cert_issuer]
    }.freeze

    USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.97 Safari/537.36'.freeze

    class << self
      def run(url, cache: nil, page: nil, refresh: false)
        @instance ||= new(cache: cache, refresh: refresh)
        @instance.run(url, page: page)
      end
    end

    def initialize(cache: nil, refresh: false)
      @cache = cache
      @refresh = refresh
      read_techs unless @refresh
    end

    def run(url, page: nil)
      @techs = read_techs if @refresh

      data = fetch_page_data(url, page)
      data = run_detections(data)
      data = sanitize_detected_data(data)
      data = resolve_implications(data)
      post_sanitize_detected_data(data)
    end

    def read_techs
      @techs = Wappalyzer.data(cache: @cache)
    end

    def fetch_browser
      Ferrum::Browser.new(
        timeout: 30,
        js_errors: false,
        window_size: [1366, 768],
        browser_options: {
          'ignore-certificate-errors' => nil,
          'no-sandbox' => nil,
          'disable-gpu' => nil,
          'allow-running-insecure-content' => nil,
          'disable-web-security' => nil,
          'user-data-dir' => ENV.fetch('CHROMIUM_DATA_DIR', '/tmp/chromium')
        }
      )
    end

    def fetch_page(url, page)
      return page if page.is_a?(Hash)

      uri = URI(url)
      uri = URI("http://#{url}/") unless uri.scheme
      page ||= fetch_browser

      current = URI(page.current_url)
      page.goto(uri) if uri != current

      page
    end

    def fetch_page_data(url, page)
      page = fetch_page(url, page)

      data = { 'url' => page.current_url, 'html' => page.body }
      data['meta'] = group_arr(page.css('meta').map { |m| [m.attribute('name') || m.attribute('property'), m.attribute('content')] })
      data['headers'] = page.network.response.headers.map { |k, v| [k.downcase, v.split("\n")] }.to_h
      data['scripts'] = page.css('script').map { |m| m.attribute('src') }.compact
      data['cookies'] = group_arr((data['headers']['set-cookie'] || []).map { |c| c.split('=', 2) })
      data['js'] = js_data(page)
      data
    end

    protected

    def run_detections(data)
      items = []
      @techs.each do |_, tech|
        items.push(one_to_one(tech, data, 'url'))
        items.push(one_to_one(tech, data, 'html'))
        items.push(one_to_one(tech, data, 'css'))
        items.push(one_to_one(tech, data, 'robots'))
        items.push(one_to_one(tech, data, 'cert_issuer'))
        items.push(one_to_many(tech, data, 'scripts'))
        items.push(many_to_many(tech, data, 'cookies'))
        items.push(many_to_many(tech, data, 'meta'))
        items.push(many_to_many(tech, data, 'headers'))
        items.push(many_to_many(tech, data['js'][tech['name']], 'js'))
      end
      items.flatten.compact
    end

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
          items = data[field][key]

          if pattern['key_regex']
            items = data[field].select do |k|
              k =~ Regexp.new(key, Regexp::IGNORECASE)
            end.values.flatten
          end

          (items || []).map do |value|
            add_tech_if_regex_match(field, pattern, tech, value, key)
          end
        end
      end
    end

    def add_tech_if_regex_match(field, pattern, tech, value, key = nil)
      regex = Regexp.new(pattern['regex'], Regexp::IGNORECASE)
      return unless value
      return if value != true && value !~ regex

      {
        'key' => key,
        'tech' => tech,
        'field' => field,
        'pattern' => pattern,
        'version' => version_for(pattern, value)
      }
    end

    def js_data(page)
      items = {}
      @techs.map do |name, tech|
        next if !tech['js'] || tech['js'].empty?

        tech['js'].keys.map do |key|
          key = key.gsub(/\[([^\]]+)\]/, '.$1')
          value =
            begin
              page.evaluate('window[' + key.split('.').map { |k| "'#{k}'" }.join('][') + ']')
            rescue StandardError
              nil
            end
          next unless value

          value = value.is_a?(String) || value.is_a?(Numeric) ? value : !!value
          items[name] ||= {}
          items[name][key] = value
        end
      end

      items.map { |k, v| [k, { 'js' => v.map { |a, b| [a, [b]] }.to_h }] }.to_h
    end

    private

    def version_for(pattern, value)
      return if pattern['version'].to_s.strip.empty?

      matches = Regexp.new(pattern['regex'], Regexp::IGNORECASE).match(value)
      return unless matches

      resolved = pattern['version']
      matches.captures.each.with_index do |match, index|
        r = Regexp.new("\\\\#{index + 1}(?:\\?([^:]+):(.*))$")
        ternary = r.match(pattern['version'])
        if ternary && ternary[1]
          resolved = pattern['version'].sub(ternary[0], match ? ternary[1] : ternary[2])
        end
        resolved = resolved.strip.gsub(Regexp.new("\\\\#{index + 1}"), match || '')
      end
      resolved
    end

    def sanitize_detected_data(data)
      data.group_by { |a| a['tech']['name'] }.map do |name, tech|
        confidence = tech.map { |r| r['pattern']['confidence'] }.sum
        versions = tech.map { |r| r['version'] }.reject { |a| a.nil? || a.empty? }
        tech = {
          'name' => tech[0]['tech']['name'],
          'confidence' => confidence,
          'versions' => versions,
          'tech' => tech[0]['tech'],
          'raw' => tech.map { |a| a.except('tech') }
        }
        [name, tech]
      end.to_h
    end

    def resolve_implications(data)
      implications = @techs.select { |_, info| info['implies'].any? || info['excludes'].any? }
      return data if implications.empty?

      implies = {}
      data.each do |name, info|
        (info['tech']['implies'] || []).each do |imp|
          raw = {
            'key' => name,
            'field' => 'implied',
            'pattern' => { 'confidence' => imp['confidence'], 'version' => '' }
          }
          if data[imp['value']] && data[imp['value']]['raw']
            data[imp['value']]['raw'].push(raw)
          else
            implies[imp['value']] = {
              'name' => imp['value'],
              'confidence' => imp['confidence'],
              'versions' => [],
              'implied' => true,
              'tech' => @techs[imp['value']],
              'raw' => [raw]
            }
          end
        end
        (info['tech']['excludes'] || []).each do |imp|
          raw = {
            'key' => name,
            'field' => 'excluded',
            'pattern' => { 'confidence' => -imp['confidence'], 'version' => '' }
          }
          data[imp['value']]['raw'].push(raw) if data[imp['value']] && data[imp['value']]['raw']
        end
      end

      data.merge(implies)
    end

    def post_sanitize_detected_data(data)
      data = data.map do |id, info|
        confidence = info['raw'].map { |r| r['field'] == 'implied' || r['field'] == 'excluded' ? 0 : r['pattern']['confidence'].to_i }
        zero_confidence = info['raw'].map { |r| r['pattern']['confidence'] }.count(&:zero?)
        posi_confidence = info['raw'].map { |r| r['pattern']['confidence'] }.count { |c| c >= 0 }
        confidence += [25] * zero_confidence if zero_confidence.positive? && zero_confidence < posi_confidence
        confidence = confidence.sum

        versions = info['raw'].map { |r| r['version'] }.reject { |a| a.nil? || a.empty? }
        info['raw'] = info['raw'].map { |a| a.except('pattern').merge(a['pattern']).merge('version' => a['version'] || '') }
        [id, info.merge('confidence' => confidence, 'versions' => versions, 'best_version' => best_version_for(info['raw']))]
      end.to_h

      data.map do |_id, info|
        implied = info['raw'].detect { |i| i['field'] == 'implied' }
        info['confidence'] += (implied['confidence'] * data[implied['key']]['confidence'] / 100.0).to_i if implied
        if (excluded = info['raw'].detect { |i| i['field'] == 'excluded' }) && data[excluded['key']]
          info['confidence'] += (excluded['confidence'] * data[excluded['key']]['confidence'] / 100.0).to_i
        end
        info # if info['confidence'].positive?
      end.compact.sort_by { |info| info['confidence'] / (info['implied'] ? 1.5 : 1) }.reverse
    end

    def best_version_for(raw, field: nil)
      grouped = raw.group_by { |a| a['version'] }
      by_conf = grouped.map { |k, v| [k, v.map { |a| a['confidence'] }.inject(0, :+)] }.to_h
      return if by_conf.empty?

      max_v = by_conf.values.max
      maxed = by_conf.select { |_k, v| v == max_v }
      return maxed.keys.first if maxed.count == 1

      by_count = grouped.map { |k, v| [k, v.count] }.to_h
      max_c = by_count.values.max
      maxed = by_count.select { |_k, v| v == max_c }
      return maxed.keys.first if maxed.count == 1

      unless field
        %w[js scripts].each do |f|
          specific = raw.select { |a| a['field'] == f && !a['version'].empty? }
          version = best_version_for(specific, field: f)
          return version if version
        end
      end

      version = raw.detect { |k| !k['version'].empty? }
      version ? version['version'] : nil
    end

    def group_arr(arr, downcase: true)
      arr.group_by(&:first).map do |val|
        [downcase ? val[0].to_s.downcase : val[0], val[1].map(&:last)]
      end.to_h
    end
  end
end
