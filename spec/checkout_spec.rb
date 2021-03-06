require 'spec/helpers'
require 'msp_release'
require 'msp_release/cli/checkout'

describe 'checkout' do
  include_context 'project_helpers'

  let :dev_version_regex do
    "([0-9]{14}-git\\+[a-f0-9]{6}~([a-z\.]+))"
  end

  describe "default behaviour - no args except repository url" do

    before do
      build_init_project('project', {:deb =>
          {:build_command => "dpkg-buildpackage -us -uc"}})
    end

    it 'lets you checkout the latest release from master when invoking with only the repository as a single argument' do

      in_tmp_dir do
        run_msp_release "checkout #{@remote_repo}"

        last_run.should exit_with(0)
        last_stdout.should match("Checking out latest commit from origin/master")
        version_regex = /Checked out to project\-([0-9]{14}-git\+[a-f0-9]{6}~master)/
        last_stdout.should match(version_regex)

        package_version = version_regex.match(last_stdout)[1]
        full_package_name = 'project-' + package_version

        File.directory?(full_package_name).should be_true
        Dir.chdir full_package_name do
          run_msp_release 'status'
          last_run.should exit_with(0)
          last_stdout.should include("Changelog says : #{package_version}")
        end
      end
    end

    it 'lets you change the distribution in the changelog' do
      in_tmp_dir do
        run_msp_release "checkout --debian-distribution=tinternet #{@remote_repo}"

        last_run.should exit_with(0)
        last_stdout.should match("Checking out latest commit from origin/master")

        checked_out_regex = /Checked out to project\-#{dev_version_regex}/
        last_stdout.should match(checked_out_regex)
        package_version = checked_out_regex.match(last_stdout)[1]

        File.read("project-#{package_version}/debian/changelog").
          first.strip.should ==
          "project (#{package_version}) tinternet; urgency=low"
      end
    end

    it 'lets you put the build products in to a tar file' do
      in_tmp_dir do
        run_msp_release "checkout --build --tar #{@remote_repo}"

        last_run.should exit_with(0)
        last_stdout.should match("Checking out latest commit from origin/master")

        checked_out_regex = /Checked out to project\-#{dev_version_regex}/
        last_stdout.should match(checked_out_regex)
        package_version = checked_out_regex.match(last_stdout)[1]
        tarfile = "project-#{package_version}.tar"
        File.exists?(tarfile).should be_true

        exec("tar -tf #{tarfile}")
        ["\.changes$", "\.dsc$", "\.tar\.gz$", "\.deb$"].each do |pattern|
          last_stdout.should match(pattern)
        end
      end
    end

    it 'lets you checkout the latest from master and the builds it' do

      in_tmp_dir do
        run_msp_release "checkout --build #{@remote_repo}"

        last_run.should exit_with(0)
        last_stdout.should match("Checking out latest commit from origin/master")

        checked_out_regex = /Checked out to project\-#{dev_version_regex}/
        last_stdout.should match(checked_out_regex)
        package_version = checked_out_regex.match(last_stdout)[1]

        package_built_regex = /Package built:.+(project\_#{dev_version_regex}_[a-z0-9]+.changes)/
        last_stdout.should match(package_built_regex)

        changes_fname = package_built_regex.match(last_stdout)[1]
        File.exists?(changes_fname).should be_true
      end
    end

    describe "in a working directory containing {project_name}_" do
      it 'lets you checkout the latest from master and the builds it' do

        in_tmp_dir 'project_builddir'  do
          run_msp_release "checkout --build #{@remote_repo}"

          last_run.should exit_with(0)
          last_stdout.should match("Checking out latest commit from origin/master")

          checked_out_regex = /Checked out to project\-#{dev_version_regex}/
          last_stdout.should match(checked_out_regex)
          package_version = checked_out_regex.match(last_stdout)[1]

          package_built_regex = /Package built:.+(project\_#{dev_version_regex}_[a-z0-9]+.changes)/
          last_stdout.should match(package_built_regex)

          changes_fname = package_built_regex.match(last_stdout)[1]
          File.exists?(changes_fname).should be_true
        end
      end
    end
  end

  describe "checkout out HEAD from a non release branch" do

    before do
      build_init_project('project', {:deb =>
          {:build_command => "dpkg-buildpackage -us -uc"}})

      in_project_dir do
        exec("git branch feature-llama")
        exec("git push origin feature-llama")
      end
    end

    it 'will checkout head from a branch if you pass BRANCH_NAME as an argument' do
      in_tmp_dir do
        run_msp_release "checkout #{@remote_repo} feature-llama"
        last_run.should exit_with(0)
        last_stdout.should match("Checking out latest commit from origin/feature-llama")

        checked_out_regex = /Checked out to project\-#{dev_version_regex}/
        last_stdout.should match(checked_out_regex)
        package_version = checked_out_regex.match(last_stdout)[1]
        branch_part = checked_out_regex.match(last_stdout)[2]

        branch_part.should == 'feature.llama'
      end
    end

  end

  describe "checking out latest release commit from a release branch" do

    before do
      build_init_project('project', {:deb =>
          {:build_command => "dpkg-buildpackage -us -uc"}})

      in_project_dir do
        run_msp_release 'branch'
        run_msp_release 'new'
        run_msp_release 'push'
      end
    end

    it 'will checkout the lastest release on a branch if you pass BRANCH_NAME as an argument' do
      in_tmp_dir do
        run_msp_release "checkout #{@remote_repo} release-0.0"

        last_run.should exit_with(0)
        last_stdout.should match("Checking out latest release commit from origin/release-0.0")
        last_stdout.should match("Checked out to project-0.0.1-1")

        File.directory?('project-0.0.1-1').should be_true
        Dir.chdir 'project-0.0.1-1' do
          run_msp_release 'status'
          last_stdout.should match('^Release commit : 0.0.1-1')
          last_stdout.should match('^Release branch : 0.0')
        end
      end
    end

    it 'will build the package if you pass --build' do
      in_tmp_dir do
        run_msp_release "checkout --build #{@remote_repo} release-0.0"

        last_run.should exit_with(0)
        last_stdout.should match("Checking out latest release commit from origin/release-0.0")
        last_stdout.should match("Checked out to project-0.0.1-1")


        package_built_regex = /Package built:.+(project_0\.0\.1\-1_[a-z0-9]+\.changes)/
        last_stdout.should match(package_built_regex)

        changes_fname = package_built_regex.match(last_stdout)[1]
        File.exists?(changes_fname).should be_true
      end
    end

    it 'will fail if you give it a branch that does not exist' do
      in_tmp_dir do
        run_msp_release "checkout #{@remote_repo} release-0.1.0"

        last_run.should exit_with(1)
        last_stderr.should match("Git pathspec 'origin/release-0.1.0' does not exist")
      end
    end
  end

  describe "with --no-noise" do

    before do
      build_init_project('project', {:deb =>
          {:build_command => "dpkg-buildpackage -us -uc"}})

      in_project_dir do
        run_msp_release 'branch'
        run_msp_release 'new'
        run_msp_release 'push'
      end
    end

    it "will build the package with no output" do
      in_tmp_dir do
        run_msp_release "checkout --no-noise --build #{@remote_repo} release-0.0"
        last_run.should exit_with(0)
        last_stdout.strip.should == ""
      end
    end

    it "will output any build products if you supply --print-files" do
      in_tmp_dir do
        run_msp_release "checkout --no-noise --print-files --build #{@remote_repo} release-0.0"
        last_run.should exit_with(0)
        last_stdout.strip.should_not == ""
        last_stdout.should match "project_0.0.1-1.tar.gz"
        last_stdout.should match /project_0\.0\.1\-1\_(.+)\.deb/
        last_stdout.should match /project_0\.0\.1\-1\_(.+)\.changes/
        last_stdout.should match /project_0.0.1-1.dsc/
      end
    end

    it "will output only the name of the tar file if you supply --print-files" +
      " and --tar" do
    end
  end

  describe "with --shallow" do
    before do
      build_init_project('project', {:deb =>
          {:build_command => "dpkg-buildpackage -us -uc"}})

      in_project_dir do
        # Create enough commits so that the first one will not show up in a
        # shallow clone
        (0..(MSPRelease::CLI::Checkout::CLONE_DEPTH + 1)).each do |iter|
          exec("echo change >> dummy_file")
          exec("git add dummy_file")
          exec("git commit -m 'change #{iter}'")

        end
        exec("git push origin master")
      end
    end

    it "will checkout the repository with short history" do
      in_tmp_dir do
        run_msp_release "checkout --shallow file:///#{@remote_repo}"
        last_run.should exit_with(0)
        last_stdout.should match("^Checking out latest commit from origin/master \\(shallow\\)$")
        version_regex = /Checked out to project\-([0-9]{14}-git\+[a-f0-9]{6}~master)/
        last_stdout.should match(version_regex)

        package_version = version_regex.match(last_stdout)[1]
        full_package_name = 'project-' + package_version

        File.directory?(full_package_name).should be_true
        Dir.chdir full_package_name do
          run_msp_release 'status'
          last_run.should exit_with(0)
          last_stdout.should include("Changelog says : #{package_version}")
          exec("git log")
          last_stdout.should match("change 6")
          last_stdout.should_not match("change 0")
        end
      end

    end
  end

end
