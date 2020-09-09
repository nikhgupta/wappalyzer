require_relative 'lib/wappalyzer/version'

Gem::Specification.new do |spec|
  spec.name          = 'wappalyzer'
  spec.version       = Wappalyzer::VERSION
  spec.authors       = ['nikhgupta']
  spec.email         = ['me@nikhgupta.com']

  spec.summary       = 'Analyzes a provided url and returns any services it can detect'
  spec.description   = 'This analyzes a url and tries to guess what software it uses (like server software, CMS, framework, programming language).'
  spec.homepage      = 'https://github.com/nikhgupta/wappalyzer'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/nikhgupta/wappalyzer'
  spec.metadata['changelog_uri'] = 'https://github.com/nikhgupta/wappalyzer'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
