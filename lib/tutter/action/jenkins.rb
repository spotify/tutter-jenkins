class Jenkins
  def initialize(settings, client, project, data)
    @settings = settings
    @client = client
    @project = project
    @data = data
  end

  def run
    pull_request_id = @data['issue']['number']
    puts "pull request id: #{pull_request_id}"
    pr = @client.pull_request @project, pull_request_id

    if pr.mergeable_state != 'clean'
      puts "merge state for #{@project} #{pull_request_id} is not clean. Current state: #{pr.mergeable_state}"
      return false
    end

    # No comments, no need to go further.
    if pr.comments == 0
      puts 'no comments, skipping'
      return false
    end

    # Don't care about code we can't merge
    unless pr.mergeable
      puts 'not mergeable, skipping'
      return false
    end

    # We fetch the latest commit and it's date.
    last_commit = @client.pull_request_commits(@project, pull_request_id).last
    last_commit_date = last_commit.commit.committer.date

    comments = @client.issue_comments(@project, pull_request_id)
    jenkins_last_comment = @client.issue_comments(@project, pull_request_id).select{|c| c.attrs[:user].attrs[:login] == 'jenkins'}.last
    jenkins_allows_merge = jenkins_last_comment && jenkins_last_comment.body =~ /PASS/

    if jenkins_allows_merge
      puts "the last comment from jenkins allows the merge"
      last_comment = comments.last
      if last_comment.created_at > last_commit_date && last_comment.body.strip.downcase == 'merge, my change is covered by tests'
        puts "merging #{pull_request_id} #{@project}"
        @client.merge_pull_request(@project, pull_request_id, 'ok, shipping!')
      end
    end
  end
end
