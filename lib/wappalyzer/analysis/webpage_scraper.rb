module Wappalyzer
  class Analysis
    class WebpageScraper
      DEFAULT_FERRUM_OPTIONS = {
        timeout: 120,
        js_errors: false,
        window_size: [1366, 768]
      }.freeze

      DEFAULT_BROWSER_OPTIONS = {
        'ignore-certificate-errors' => nil,
        'no-sandbox' => nil,
        'disable-gpu' => nil,
        'allow-running-insecure-content' => nil,
        'disable-web-security' => nil,
        'user-data-dir' => ENV.fetch('CHROMIUM_DATA_DIR', '/tmp/chromium')
      }.freeze

      def self.call(url, techs, page: nil)
        new(url, techs, page: page).process
      end

      def initialize(url, techs, page: nil)
        @data = {}
        @page = page
        @techs = techs
        @uri = URI(url)
      end

      def process
        fetch_page
        return {} unless @page

        @data['html'] = @page.body
        @data['url'] = @page.current_url
        @data['meta'] = extract_meta_tags
        @data['headers'] = extract_headers
        @data['scripts'] = extract_scripts
        @data['cookies'] = extract_cookies
        @data['js'] = extract_js_variables
        @data
      end

      protected

      def extract_meta_tags
        meta = @page.css('meta').map do |m|
          [m.attribute('name') || m.attribute('property'), m.attribute('content')]
        end
        group_arr meta
      end

      def extract_headers
        return {} if @page.network.response.nil?

        @page.network.response.headers.map { |k, v| [k.downcase, v.split("\n")] }.to_h
      end

      def extract_scripts
        @page.css('script').map { |m| m.attribute('src') }.compact
      end

      def extract_cookies
        cookies = (@data['headers']['set-cookie'] || []).map { |c| c.split('=', 2) }
        group_arr(cookies)
      end

      def extract_js_variables
        items = {}
        @techs.each do |name, tech|
          next if tech['js'].empty?

          tech['js'].keys.each do |key|
            key = key.gsub(/\[([^\]]+)\]/, '.$1')
            items = evaluate_and_add_js_variable(key, name, items)
          end
        end

        format_js_data_arr_for_processing items
      end

      def fetch_page(inverted: false)
        return if @page.is_a?(Hash)

        @uri.scheme ||= 'http'
        @page ||= fetch_browser

        current = URI(@page.current_url)
        @page.goto(@uri.to_s) if @uri != current
        return @page if @page.network.response
        return if inverted

        change_url_scheme
        fetch_page inverted: true
      end

      def fetch_browser(options = {}, browser_options = {})
        options = DEFAULT_FERRUM_OPTIONS.merge(options)
        browser_options = DEFAULT_BROWSER_OPTIONS.merge(browser_options)
        Ferrum::Browser.new(options.merge(browser_options: browser_options))
      end

      private

      def group_arr(arr, downcase: true)
        arr.group_by(&:first).map do |val|
          [downcase ? val[0].to_s.downcase : val[0], val[1].map(&:last)]
        end.to_h
      end

      def evaluate_and_add_js_variable(key, tech, items)
        if (value = evaluate_js_variable(key))
          items[tech] ||= {}
          items[tech][key] = sanitize_value(value)
        end

        items
      end

      def evaluate_js_variable(key)
        @page.evaluate('window[' + key.split('.').map { |k| "'#{k}'" }.join('][') + ']')
      rescue StandardError
        nil
      end

      def sanitize_value(value)
        value.is_a?(String) || value.is_a?(Numeric) ? value : !value.nil?
      end

      def format_js_data_arr_for_processing(items)
        items.map do |key, val|
          val = val.map { |k, v| [k, [v]] }.to_h
          [key, { 'js' => val }]
        end.to_h
      end

      def change_url_scheme
        @uri.scheme = @uri.scheme == 'http' ? 'https' : 'http'
      end
    end
  end
end
