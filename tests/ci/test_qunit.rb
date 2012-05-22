require 'test/unit'
require 'fileutils'
require "rubygems"
require "bundler/setup"
require "capybara"
require "capybara/dsl"
require "rake"
require "ci/reporter/rake/test_unit"

#must be required here or ci_reporter won't work. it expects rake
require "ci/reporter/rake/test_unit_loader"

Capybara.configure do |config|
  config.default_driver = :firefox
  config.default_selector = :css
end

Capybara.register_driver :chrome do |app|
  Capybara::Selenium::Driver.new(app, :browser => :chrome)
end

Capybara.register_driver :firefox do |app|
  Capybara::Selenium::Driver.new(app, :browser => :firefox)
end

Rake::Task['ci:setup:testunit'].invoke

# set the application host using an environment variable
# allows the ci to set a path for the build command
# eg http//localhost/1.0-stable
Capybara.app_host = ENV['CI_APP_HOST'] || Capybara.app_host

# Allow the ci to set the jquery versions for testing, depends on the file
# js/jquery-#{version} being available for movement to js/jquery.js
JQUERY_VERSIONS = (ENV['JQUERY_VERSIONS'] || "1.6.4,1.7.1").split(",")

# testing directory relative to this file
# NOTE not using File.join since this is always going to be nix
PROJECT_ROOT = File.expand_path(File.join(File.dirname(__FILE__), "../../"))
TEST_DIR = PROJECT_ROOT + "/tests/unit/"
JS_ROOT = PROJECT_ROOT + "/js/"

class TestQunit < Test::Unit::TestCase
  include Capybara::DSL

  def self.driver
    Capybara.default_driver
  end

  def driver
    self.class.driver
  end

  def swap_jquery(version)
    FileUtils.cp("#{JS_ROOT}/jquery-#{version}.js", "#{JS_ROOT}/jquery.js")
  end

  # TODO this globbing and next filtering can be simplified
  (Dir[TEST_DIR + "*"] + Dir[TEST_DIR + "**/*-tests.html"]).each do |path|
    next if !File.directory?(path) && !path.include?("-tests.html")
    # next if !path.include?("disabled")

    # strip the parent directory ... ugh this sucks
    path = "/tests" + path.split('/tests')[1]

    JQUERY_VERSIONS.each do |jquery_version|
      # remove the dashes, dots, and slashes from the path (naive), remove
      # the first dash, and replace tests with test so test unit will pick them up
      test_name = path.gsub(/\/|-|\./, "_").gsub(/^_/, "")

      # add in the jquery version
      test_name += "_jquery_" + jquery_version.gsub(".", "_")

      # make sure the test unit picks up the test method
      test_name += "_test"

      # Define a test method for each unit test path
      define_method "#{test_name}" do
        # get some more readable console ouput
        puts
        print "method name: #{test_name}, path: #{path}, result: "

        Capybara.current_driver = driver

        # NOTE swapping before every test :(
        swap_jquery(jquery_version)

        # visit the test suit page
        visit(path)

        wait_for_tests
        unless all_failing.empty?
          # TODO figure out why chained find didn't work here
          failing_descriptions = all("#qunit-tests .fail .test-name").map { |elem|
            elem.text()
          }.join("\n")
        end

        assert_description = <<-MSG
          there should be no failures at #{path} for #{driver} with jquery #{jquery_version}. Failing:
          #{failing_descriptions}"
        MSG

        assert(all_failing.empty?, assert_description)
      end
    end
  end

  # verify that the tests are finished or there is a failure
  def wait_for_tests(attempts = 100)
    attempts.times do
      banner_class = find("#qunit-banner")[:class]
      # break if the banner is there or theres a failure already
      break if banner_class && banner_class.include?("pass")
      break unless all_failing.empty?

      sleep 1
    end
  end

  # get the failing test elements
  def all_failing
    all("#qunit-tests .fail")
  end
end

class TestQunitChrome < TestQunit
  def self.driver
    :chrome
  end
end
