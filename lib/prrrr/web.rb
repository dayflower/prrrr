require "prrrr/repository"
require "rack/request"
require "rack/response"
require "rack/static"
require "octokit"

module Prrrr
  module Web
    STATIC_ROOT = File.expand_path("../../../static", __FILE__)

    class App
      def initialize(params = {})
      end

      def call(env)
        path = env["PATH_INFO"].dup
        unless path.sub!(%r{\A /(\w+)/(\w+)/? }xmo, "")
          throw RuntimeError.new
        end

        user, repo = $1, $2

        [ 200, [], [ "#{user}:#{repo}" ] ]
      end
    end

    class Router
      def initialize(params = {})
        app = App.new()
        @static_handler = Rack::Static.new(app, root: STATIC_ROOT,
                                                urls: %w[ /js ])
      end

      def call(env)
        @static_handler.call(env)
      end
    end
  end
end
