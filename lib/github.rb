require_relative "github-graphql"

module Github
  def self.pull_request_by_number(org, repo, pr_number)
    pr = GithubGraphql::PullRequest.by_number(org, repo, pr_number).repository.pull_request

    result = pr.to_h.select do |k, v|
      %w(id url number headRefName title createdAt).include? k
    end
    result["authorId"] = pr.author.id
    result["authorLogin"] = pr.author.login
    result["authorName"] = pr.author.name
    result["author"] = name_and_login(pr.author)

    result["reviews"] = pr.reviews.nodes.inject({}) do |reviews, review|
      reviews.merge({ name_and_login(review.author) => review.state })
    end

    result["reviewRequests"] = pr.review_requests.nodes.map do |rr|
      { "user" => name_and_login(rr.requested_reviewer) }
    end

    return result
  end

  ## Returns a list of members {id, login, name}
  def self.team_members(org, team_name)
    team = GithubGraphql::Team.members(org, team_name).organization.team
    return nil if team.nil?

    return team.members.edges.map do |edge|
      edge.node.to_h
    end
  end

  def self.request_review_on_pull_request(pr_id, user_ids)
    GithubGraphql::PullRequest.request_review(pr_id, user_ids)
  end

  def self.puts_pull_request(pr)
    puts "\e[1m#{pr["title"]}\e[0m #{pr["headRefName"]}"
    puts "#{pr["author"]} #{pr["createdAt"]}"
    puts ""

    pr["reviews"].each do |user, state|
      if state == "APPROVED"
        puts " \e[92m\e[1m✔ \e[0m #{user}"
      elsif state == "CHANGES_REQUESTED"
        puts " \e[91m\e[1m±\e[0m  #{user}"
      elsif state == "COMMENTED"
        puts "💬  #{user}"
      end
    end

    pr["reviewRequests"].each do |rr|
      puts " \e[33m\e[1m●\e[0m  #{rr["user"]}"
    end
  end

  def self.parse_pull_request_url(url)
    keys = ["org", "repo", "pr_number"]
    vals = url.match(/https:\/\/github.com\/(.+)\/(.+)\/pull\/(.+)/).captures

    return Hash[keys.zip(vals)]
  end

  def self.name_and_login(obj)
    if obj.name && !obj.name.empty?
      "#{obj.name} (@#{obj.login})"
    else
      "@#{obj.login}"
    end
  end
end
