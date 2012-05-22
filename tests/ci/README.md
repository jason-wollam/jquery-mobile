# jQuery Mobile simple CI

After getting the test suite to a place where a full run was taking more time and effort that was realistic to expect from devs a simple CI integration was built using selenium. Generally it relies on Selenium's ability to retrieve information via selectors from the DOM of the page it's operating on which it then reports.

## Dependencies

The test suite depends on Ruby, a host of Ruby Gems listed in the Gemfile, Selenium drivers for both firefox and chrome, the browsers themselves, and an apache server serving the site at localhost:80 (configurable). The output from the tests is exported in JUnit xml format for integration with Jenkins and any other CI server that support said format.

## Setup

The setup is mostly automated (may require tweeking) via [chef](http://wiki.opscode.com/display/chef/FAQ) cookbooks included at the root of the project under the `cookbooks` directory. `chef-solo` is the preferred method of setup. The idea is that building a new CI server with the test suite from scratch should be trivial and documented with code.

## Test lifecycle

When `ruby test_qunit.rb` is executed two `TestUnit` test sets are run, one for each browser. In each test set a seperate test is created for all `tests/unit/` child directories and any files in any sub directory (however nested) that end in `-tests.html`. The two globs are `tests/unit/*` and `tests/unit/**/*-tests.html`. In this way new test pages can be added easily by following the glob conventions.

Each test is identical save for the url it instructs Selenium to visit which is always a QUnit page. Once the page loads, the server side test waits for client side test suite in the page to complete by polling the QUnit banner for failure or success. If it finds a failure at any time it will short circuit the test and report failure immediatley (would be better to record all failures but requires work).

It reports failure or success by asserting on the set of failed tests in the page. If that set is empty, the assertion reports success otherwise failure.

Once the test suite has run all the tests created for each browser it outputs the results into JUnit format.

## Code quality

The Ruby used to run the test suite leaves a lot to be desired in the way of code quality (see, globs and gsubs for test names) but for now it's serviceably small.
