module Prrrr
  class Repository
    class IllegalStateError < StandardError
      attr_reader :status

      def initialize(message, status)
        super(message)
        @status = status
      end
    end

    def initialize(logger, client, repo)
      @logger = logger
      @client = client
      @repo = repo
    end

    def info(options = {})
      @client.repository(@repo)
    end

    def branches(regexp = %r{})
      branches = []
      res = @client.branches(@repo)
      auto_paginate(res) do |branch|
        next unless branch.name =~ regexp
        branches << branch.name
      end
      branches.sort
    end

    def open_pullreq_exists?(base, head)
      @logger.info "will fetch pull requests for #{@repo} into #{base} from #{head}"
      user, _ = @repo.split("/", 2)
      res = @client.pull_requests(@repo, state: 'open', base: base, head: "#{user}:#{head}")
      res.length > 0
    end

    def pullreqs_for_release(base, head)
      res = pick_merge_commits(@repo, base, head)
      pulls = pick_pullreqs(@repo, base, res[:merge_commits])
      res[:pull_requests] = pulls
      res
    end

    def create_pullreq(base, head, title, body = nil)
      res = @client.create_pull_request(@repo, base, head, title, body)
    end

    private

    def pick_pullreqs(repo, base, commits)
      pulls = []

      looking = commits.reduce({}) { |hash, commit| hash[commit] = true; hash }

      @logger.info "will fetch pull requests for #{repo}"
      res = @client.pull_requests(repo, state: 'closed')
      auto_paginate(res) do |pull|
        break unless looking.length > 0
        next if pull[:base][:ref] == base

        sha = pull[:merge_commit_sha]
        if looking.include?(sha)
          @logger.info "found pr##{pull[:number]} for #{sha}"
          pulls << pull
          looking.delete sha
        end
      end

      pulls.reverse
    end

    def pick_merge_commits(repo, base, head)
      commits = []

      @logger.info "will compare between #{base} and #{head} of #{repo}"
      res = @client.compare(repo, base, head)

      if res[:status] != "ahead"
        raise IllegalStateError.new("status is not ahead (#{res[:status]})", res[:status])
      end

      head_commit = res[:commits][-1]

      res[:commits].reverse.each do |commit|
        sha = commit[:sha]

        if commit[:parents].length >= 2
          @logger.info "#{sha} is merge commit"
          commits << sha
        end
      end

      # compare API returns max 250 commits only
      if res[:total_commits] > 250
        @logger.warn "the compared result contains more than 250 commits"
      end

      # shrink result size
      res[:commits] = []
      res[:files].each do |file|
        file[:patch] = nil
      end

      res.to_h.merge({
        :merge_commits => commits,
        :head_commit => head_commit,
      })
    end

    def auto_paginate(res)
      res.each do |item|
        yield item
      end

      last_response = @client.last_response
      while true
        next_url = last_response.rels[:next]
        break if next_url.nil?
        @logger.info "will fetch #{next_url.href} as auto_paginate"
        last_response = next_url.get

        last_response.data.each do |item|
          yield item
        end
      end
    end
  end
end
