# Wappalyzer

This is a Ruby port of [Wappalyzer](https://github.com/ElbertF/Wappalyzer),
which identifies technologies on websites. It detects content management
systems, ecommerce platforms, JavaScript frameworks, analytics tools and
[much more](https://www.wappalyzer.com/technologies).

This port does provide some additional options, and nicer parsing of
technologies listed by Wappalyzer.

I found a few ports in Ruby, but Wappalyzer now uses Chrome browser to test
technologies, and most of these ports were not using this browser for tests.
With this port, I am using [Ferrum](https://github.com/rubycdp/ferrum) for
tests, which is really really fast.

Futhermore, most ports cached a copy of `technologies.json` provided by
Wappalyzer, which becomes outdated after a while. With this port, this json
will be downloaded and cached for the user (and can be updated on demand).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'wappalyzer', github: 'nikhgupta/wappalyzer', branch: 'master'
```

And then execute:

```shell
bundle install
```

## Usage

### Analysis

To analyze a website, use:

```ruby
Wappalyzer.analyze "https://codewithsense.com/" # a web page
Wappalyzer.analyze "codewithsense.com" # or, just the domain
```

Note that, technologies data is cached in memory for speeding up queries after
the first fun (rather than reading the JSON file each time from disk). To force
reading technologies data from disk for an analysis, you can use:

```ruby
Wappalyzer.analyze "codewithsense.com", refresh: true
```

### Analysis - Avoid spawing browser process

If you already have the data for a page, you can:

```ruby
# This does not spawn a browser process, but does not score technologies
# on the page via Javascript detection.
Wappalyzer.analyze "codewithsense.com", page: {
  meta: { generator: ['WordPress'] },
  headers: { server: ['Nginx'] },
  scripts: ['jquery-3.0.0.js'],
  cookies: { awselb: [''] },
  html: '<div ng-app="">'
}
```

If you want to score technologies on the page with Javascript detection, you
should pass in `Ferrum` instance for browser (or page):

```ruby
page.goto("codewithsense.com") # inside your pipeline

# browser will navigate to the URL being analyzed if thats not the current page.
Wappalyzer.analyze "codewithsense.com", page: page
```

### Analysis - Custom Browser Options

The above option can also be used to provide your own browser object with custom
configuration options, e.g.

```ruby
# will navigate to codewithsense.com
Wappalyzer.analyze "codewithsense.com", page: Ferrum::Browser.new(
  timeout: 30, js_errors: false, window_size: [1366, 768],
  browser_options: {
    'ignore-certificate-errors' => nil,
    'no-sandbox' => nil,
    'disable-gpu' => nil,
    'allow-running-insecure-content' => nil,
    'disable-web-security' => nil,
    'user-data-dir' => ENV.fetch('CHROMIUM_DATA_DIR', '/tmp/chromium')
  }
) # default options
```

### Technologies Data

To get data regarding all available technologies, use:

```ruby
Wappalyzer.data
```

`technologies.json` will be downloaded and cached automatically on first analysis.
You can manually update the cached json, using:

```ruby
Wappalyzer.update! # caches to ~/.wappalyzer.json
```

You can customize the rules before they are cached to disk. To do so, you can use:

```ruby
# add the last category to all technologies
# NOTE: this block will also be run for `ours` option.
Wappalyzer.update! do |name, data, categories|
  data[:categories] += categories.last
  data # do not forget to return this back
end
```

If you prefer to store the downloaded `technologies.json` at a custom path, you should
pass the path to both the above commands:

```ruby
Wappalyzer.update!(cache: "/path/to/some.json")

# after:
Wappalyzer.data(cache: "/path/to/some.json")
Wappalyzer.analyze("codewithsense.com", cache: "/path/to/some.json")
```

If for some reason, Wappalyzer updates the URL for this json file, or if you want to use
an alternate `technologies.json`, you can use:

```ruby
Wappalyzer.update!(remote: "https://url.to/a/different.json")
```

You can also provide a local json/file that contains some additional rules:

```ruby
Wappalyzer.update!(ours: "/path/to/additional/rules.json")

json = '{"technologies":{"DAN Domains":{"cats":[30],"meta":{"author":"DAN.COM"},"website":"https://dan.com","description":"DAN.COM"}}}'
Wappalyzer.update!(ours: json)
```

Finally, o'course, you can combine all the options above for `update!`
method. Remember to use `cache` option for `analyze` and `data` method too,
if you are using a custom path.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then,
run `rake spec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then
run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/nikhgupta/wappalyzer. This project is intended to be a
safe, welcoming space for collaboration, and contributors are expected to
adhere to the [code of conduct](https://github.com/nikhgupta/wappalyzer/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Wappalyzer project's codebases, issue trackers,
chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/nikhgupta/wappalyzer/blob/master/CODE_OF_CONDUCT.md).
