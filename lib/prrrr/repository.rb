module Prrrr
  class Repository
    class IllegalStateError < StandardError
    end

    def initialize(logger, client, repo)
      @logger = logger
      @client = client
      @repo = repo
    end

    def open_pullreq_exists?(base, head)
      @logger.info "will fetch pull requests for #{@repo} into #{base} to #{head}"
      res = @client.pull_requests(@repo, state: 'open', base: base, head: head)
      res.length > 0
    end

    def pullreqs_for_release(base, head)
      merge_commits = pick_merge_commits(@repo, base, head)
      pick_pullreqs(@repo, base, merge_commits)
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
        throw IllegalStateError.new("status is not ahead (#{res[:status]})")
      end

      base_sha = res[:merge_base_commit][:sha]

      last_sha = nil
      res[:commits].reverse.each do |commit|
        last_sha = commit[:sha]

        if commit[:parents].length >= 2
          if last_sha != base_sha
            @logger.info "#{last_sha} is merge commit"
            commits << last_sha
          end
        end
      end

      # compare API returns max 250 commits only
      if last_sha != base_sha
        @logger.info "the compared result contains more than 250 commits"
        @logger.info "will fetch commits of #{repo} from #{last_sha}"
        res = @client.commits(repo, last_sha, per_page: 100)
        auto_paginate(res) do |commit|
          last_sha = commit[:sha]
          break if last_sha == base_sha

          if commit[:parents].length >= 2
            @logger.info "#{last_sha} is merge commit"
            commits << last_sha
          end
        end
      end

      commits
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
