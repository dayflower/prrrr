# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'prrrr/version'

Gem::Specification.new do |spec|
  spec.name          = "prrrr"
  spec.version       = Prrrr::VERSION
  spec.authors       = ["dayflower"]
  spec.email         = ["daydream.trippers@gmail.com"]

  spec.summary       = %q{Making GitHub release from pull requests}
  spec.description   = %q{Making GitHub release from pull requests}
  spec.homepage      = "https://github.com/dayflower/prrrr"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = %w[
    Gemfile
    LICENSE.txt
    README.md
    Rakefile
    bin/console
    bin/setup
    lib/prrrr.rb
    lib/prrrr/repository.rb
    lib/prrrr/util.rb
    lib/prrrr/version.rb
    lib/prrrr/web.rb
    static/css/blaze.min.css
    static/img/loading.gif
    static/js/main.js
    view/text/pr.erb
    view/web/created.erb
    view/web/error_403.erb
    view/web/error_404.erb
    view/web/error_bad_compare.erb
    view/web/failed.erb
    view/web/form.erb
    view/web/index.erb
    view/web/login.erb
    view/web/repo.erb
    prrrr.gemspec
  ]
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "octokit"
  spec.add_dependency "sinatra"
  spec.add_dependency "sinatra-contrib"
  spec.add_dependency "erubis"

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
end
