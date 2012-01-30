require 'fileutils'

module MSPRelease
  class Command::Checkout < MSPRelease::Command

    include Debian::Versions

    def self.description
      "Checkout a release commit from a git repository"
    end

    def run
      git_url = ARGV[1]
      release_spec_arg = ARGV[2]
      branch_name = release_spec_arg || 'master'
      pathspec = "origin/#{branch_name}"

      if release_spec_arg
        puts("Checking out latest release commit from #{pathspec}")
      else
        puts("Checking out latest commit from master")
      end

      tmp_dir = "msp_release-#{Time.now.to_i}.tmp"
      Git.clone(git_url, {:out_to => tmp_dir, :exec => {:quiet => true}})

      project = Project.new(tmp_dir + "/" + Helpers::PROJECT_FILE)

      src_dir = Dir.chdir(tmp_dir) do

        if pathspec != "origin/master"
          # look for a release commit
          move_to(pathspec)

          first_commit_hash, commit_message =
            find_first_release_commit(project)

          if first_commit_hash.nil?
            raise ExitException, "Could not find a release commit on #{pathspec}"
          end

          exec "git reset --hard #{first_commit_hash}"

        else
          dev_version = Development.
            new_from_working_directory(branch_name, latest_commit_hash)

          project.changelog.amend(dev_version)
        end

        project.source_package_name + "-" + project.changelog.version.to_s
      end

      FileUtils.mv(tmp_dir, src_dir)
      puts("Checked out to #{src_dir}")
    end

    private

    def oneline_pattern
      /^([a-z0-9]+) (.+)$/i
    end

    def log_command
      "git --no-pager log --no-color --full-index"
    end

    def latest_commit_hash
      output = exec(log_command + " --pretty=oneline -1").split("\n").first
      oneline_pattern.match(output)[1]
    end

    def find_first_release_commit(project)
      all_commits = exec(log_command +  " --pretty=oneline").
        split("\n")

      all_commits.map { |commit_line|
        match = oneline_pattern.match(commit_line)
        [match[1], match[2]]
      }.find {|hash, message|
        project.release_name_from_message(message)
      }
    end

    def move_to(pathspec)
      begin
        exec("git show #{pathspec} --")
      rescue Exec::UnexpectedExitStatus => e
        if /^fatal: bad revision/.match(e.stderr)
          raise ExitException, "Git pathspec '#{pathspec}' does not exist"
        else
          raise
        end
      end

      exec("git checkout --track #{pathspec}")
    end
  end

end
