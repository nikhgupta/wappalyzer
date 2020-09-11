module Wappalyzer
  class Analysis
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

      pipe_in :WebpageScraper, url, page: page
      pipe_in :Processor
      pipe_in :Formatter
      pipe_in :ImplicationResolver
      pipe_in :PostFormatter

      @data
    end

    private

    def read_techs
      @techs = Wappalyzer.data(cache: @cache)
    end

    def pipe_in(name, *args, **options)
      klass = Wappalyzer::Analysis.const_get(name)
      args.push(@data) if @data
      args.push(@techs)
      @data = klass.call(*args, **options)
    end
  end
end
