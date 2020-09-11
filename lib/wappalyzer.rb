require 'pry'
require 'json'
require 'ferrum'
require 'httparty'
require 'active_support/core_ext/string/inflections'

require 'wappalyzer/version'

require 'wappalyzer/builder/rule_parser'
require 'wappalyzer/builder'

require 'wappalyzer/analysis/webpage_scraper'
require 'wappalyzer/analysis/processor'
require 'wappalyzer/analysis/formatter'
require 'wappalyzer/analysis/post_formatter'
require 'wappalyzer/analysis/implication_resolver'
require 'wappalyzer/analysis'

module Wappalyzer
  CACHE_PATH = File.join(ENV['HOME'], '.wappalyzer.json')
  class Error < StandardError; end

  def self.update!(**options, &block)
    Wappalyzer::Builder.update!(**options, &block)
  end

  def self.data(cache: nil)
    Wappalyzer::Builder.data(cache: cache)
  end

  def self.analyze(url, cache: nil, refresh: false, page: nil)
    Wappalyzer::Analysis.run(url, cache: cache, refresh: refresh, page: page)
  end
end
