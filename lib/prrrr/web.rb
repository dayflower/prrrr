require "prrrr/repository"
require "octokit"
require "sinatra/base"
require "sinatra/cookies"
require "tilt"
require "faraday"
require "json"
require "uri"
require "securerandom"

module Prrrr
  class Web < Sinatra::Application
    set :root, File.expand_path("../../..", __FILE__)
    set :public_folder, File.join(settings.root, "static")
    set :erb, :escape_html => true

    set :show_exceptions, :after_handler

    set :pr_template, ENV["PR_TEMPLATE"] || File.join(settings.root, "text", "pr.erb")

    set :logging_octokit, false
    set :token_expires, 3600*24*7
    set :branch_regexp, %r{\A\w+\z}
    set :encryption_key, SecureRandom.urlsafe_base64(33)

    set :github_client_id, ENV["GITHUB_CLIENT_ID"]
    set :github_client_secret, ENV["GITHUB_CLIENT_SECRET"]
    set :github_global_token, ENV["GITHUB_GLOBAL_TOKEN"]
    set :github_api_endpoint, ENV["GITHUB_API_ENDPOINT"] || ENV["OCTOKIT_API_ENDPOINT"]
    set :github_web_endpoint, ENV["GITHUB_WEB_ENDPOINT"] || ENV["OCTOKIT_WEB_ENDPOINT"]

    helpers Sinatra::Cookies

    helpers do
      def send_static(file)
        send_file File.expand_path(file, settings.public_folder)
      end

      def octokit
        unless @octokit
          if settings.logging_octokit
            stack = Faraday::RackBuilder.new do |builder|
              builder.response :logger
              builder.use Octokit::Response::RaiseError
              builder.adapter Faraday.default_adapter
            end
            Octokit.middleware = stack
          end

          Octokit.api_endpoint = settings.github_api_endpoint unless settings.github_api_endpoint.nil?
          Octokit.web_endpoint = settings.github_web_endpoint unless settings.github_web_endpoint.nil?

          # TODO raise when github_token is nil
          @octokit = Octokit::Client.new(access_token: github_token)
        end

        @octokit
      end

      def repo(repo_name)
        Prrrr::Repository.new(logger, octokit, repo_name)
      end

      def create_access_token(password, access_token)
        Prrrr::Util.encrypt(password, { token: access_token, issued: Time.now.to_i })
      end

      def parse_access_token(password, token)
        o = Prrrr::Util.decrypt(password, token)
        return nil if o.nil?
        if o[:issued] + settings.token_expires < Time.now.to_i
          return nil
        end
        o[:token]
      end

      def github_token
        @github_token ||= settings.github_global_token || parse_access_token(settings.encryption_key, cookies[:access_token])
      end
    end

    REPONAME_PATTERN = %r{([a-zA-Z0-9]\w+/\w+)}

    error Octokit::Unauthorized do
      if request.path_info =~ %r{\A/#{REPONAME_PATTERN}}
        repo_name = $1
      else
        repo_name = "(unknown)"
      end
      status 403
      erb :error_403, :locals => { :repo_name => repo_name }
    end

    error Octokit::NotFound do
      if request.path_info =~ %r{\A/#{REPONAME_PATTERN}}
        repo_name = $1
      else
        repo_name = "(unknown)"
      end
      status 404
      erb :error_404, :locals => { :repo_name => repo_name }
    end

    get %r{/#{REPONAME_PATTERN}/auth} do |repo_name|
      if cookies[:oauth2_state] != request["state"]
        halt 403
      end

      res = Octokit.exchange_code_for_token(request["code"], settings.github_client_id, settings.github_client_secret)

      cookies[:access_token] = create_access_token(settings.encryption_key, res.access_token)
      redirect "/" + repo_name
    end

    get %r{/#{REPONAME_PATTERN}/branches} do |repo_name|
      content_type :json
      JSON.pretty_generate(repo(repo_name).branches(settings.branch_regexp))
    end

    post %r{/#{REPONAME_PATTERN}/prepare} do |repo_name|
      base, head = %w[ base head ].map { |k| request[k] }
      repo = repo(repo_name)

      if repo.open_pullreq_exists?(base, head)
        status 422
        return erb :error_already_exists, :locals => { :repo_name => repo_name, :base => base, :head => head }
      end

      begin
        pulls = repo.pullreqs_for_release(base, head)
      rescue Prrrr::Repository::IllegalStateError => e
        status 400
        return erb :error_bad_compare, :locals => { :repo_name => repo_name, :base => base, :head => head, :status => e.status }
      end

      template = Tilt[:erb].new(settings.pr_template)
      content = template.render({}, :diff => pulls )
      title, body = content.split(/\n/, 2)

      erb :form, :locals => { :base => base, :head => head, :title => title, :body => body, :diff => pulls }
    end

    post %r{/#{REPONAME_PATTERN}/pr} do |repo_name|
      base, head, title, body = %w[ base head title body ].map { |k| request[k] }
      repo = repo(repo_name)

      if repo.open_pullreq_exists?(base, head)
        status 422
        return erb :error_already_exists, :locals => { :repo_name => repo_name, :base => base, :head => head }
      end

      begin
        res = repo.create_pullreq(base, head, title, body)
        erb :created, :locals => { :res => res, :base => base, :head => head, :title => title, :body => body }
      rescue Octokit::UnprocessableEntity => e
        logger.warn e.message
        status 422
        erb :failed, :locals => { :e => e }
      end
    end

    get %r{/#{REPONAME_PATTERN}} do |repo_name|
      if github_token.nil?
        state = SecureRandom.uuid
        next_url = url("/#{repo_name}/auth")
        params = URI.encode_www_form({
          client_id: settings.github_client_id,
          redirect_uri: next_url,
          state: state,
          allow_signup: false,
          scope: "repo"
        })
        github_login_url = URI.join("https://github.com/", "login/oauth/authorize", "?" + params)
        cookies[:oauth2_state] = state
        erb :login, :locals => { :repo_name => repo_name, :github_login_url => github_login_url.to_s }
      else
        erb :repo, :locals => {
          :repo_name => repo_name,
          #:repo     => repo(repo_name).info,
        }
      end
    end

    get "/favicon.ico" do
      halt 204
    end

    get "/" do
      erb :index
    end
  end
end
