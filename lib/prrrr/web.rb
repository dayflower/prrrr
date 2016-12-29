require "prrrr/repository"
require "octokit"
require "sinatra/base"
require "tilt"
require "faraday"

module Prrrr
  class Web < Sinatra::Application
    set :root, File.expand_path("../../..", __FILE__)
    set :public_folder, File.join(settings.root, "static")
    set :views, File.join(settings.root, "/view")
    set :erb, :escape_html => true

    set :show_exceptions, :after_handler

    helpers do
      def send_static(file)
        send_file File.expand_path(file, settings.public_folder)
      end

      def octokit
        unless @octokit
          stack = Faraday::RackBuilder.new do |builder|
            builder.response :logger
            builder.use Octokit::Response::RaiseError
            builder.adapter Faraday.default_adapter
          end
          Octokit.middleware = stack

          @octokit = Octokit::Client.new(access_token: settings.global_token)
        end

        @octokit
      end

      def repo(repo_name)
        Prrrr::Repository.new(logger, octokit, repo_name)
      end

    end

    set(:step) { |value| condition { request["step"] === value } }

    REPONAME_PATTERN = %r{([a-zA-Z0-9]\w+/\w+)}

    get "/favicon.ico" do
      halt 204
    end

    error Octokit::Unauthorized do
      if request.path_info =~ %r{\A/#{REPONAME_PATTERN}}
        repo_name = $1
      else
        repo_name = "(unknown)"
      end
      status 403
      erb :'web/error_403', :locals => { :repo_name => repo_name }
    end

    error Octokit::NotFound do
      if request.path_info =~ %r{\A/#{REPONAME_PATTERN}}
        repo_name = $1
      else
        repo_name = "(unknown)"
      end
      status 404
      erb :'web/error_404', :locals => { :repo_name => repo_name }
    end

    get %r{/#{REPONAME_PATTERN}} do |repo_name|
      erb :'web/branches'
    end

    post %r{/#{REPONAME_PATTERN}}, :step => "branches" do |repo_name|
      base, head = %w[ base head ].map { |k| request[k] }
      pulls = repo(repo_name).pullreqs_for_release(base, head)
      template = Tilt[:erb].new(File.join(settings.views, "text/pr.erb"))
      content = template.render({}, :pulls => pulls )
      title, body = content.split(/\n/, 2)
      erb :'web/form', :locals => { :base => base, :head => head, :title => title, :body => body }
    end

    post %r{/#{REPONAME_PATTERN}}, :step => "form" do |repo_name|
      base, head, title, body = %w[ base head title body ].map { |k| request[k] }

      begin
        res = repo(repo_name).create_pullreq(base, head, title, body)
        erb :'web/created', :locals => { :res => res, :base => base, :head => head, :title => title, :body => body }
      rescue Octokit::UnprocessableEntity => e
        status 422
        erb :'web/failed'
      end
      #erb :'web/complete', :locals => {  }
    end
  end
end