require 'spec_helper'

describe Testrbl do
  around do |example|
    run "rm -rf tmp && mkdir tmp"
    Dir.chdir "tmp" do
      example.call
    end
    run "rm -rf tmp"
  end

  def run(cmd, options={})
    result = `#{cmd} 2>&1`
    raise "FAILED #{cmd} --> #{result}" if $?.success? != !options[:fail]
    result
  end

  def testrbl(command, options={})
    run "#{File.expand_path("../../bin/testrbl", __FILE__)} #{command}", options
  end

  def write(file, content)
    folder = File.dirname(file)
    run "mkdir -p #{folder}" unless File.exist?(folder)
    File.open(file, 'w'){|f| f.write content }
  end

  it "has a VERSION" do
    Testrbl::VERSION.should =~ /^[\.\da-z]+$/
  end

  context "with a simple setup" do
    before do
      write "a_test.rb", <<-RUBY
        require 'test/unit'

        class Xxx < Test::Unit::TestCase
          def test_xxx
            puts 'ABC'
          end

          def test_yyy
            puts 'BCD'
          end
        end
      RUBY
    end

    it "runs by exact line" do
      result = testrbl "a_test.rb:4"
      result.should include "ABC\n"
      result.should_not include "BCD"
    end

    it "runs by above a line" do
      result = testrbl "a_test.rb:5"
      result.should include "ABC\n"
      result.should_not include "BCD"
    end

    it "does not run when line is before test" do
      result = testrbl "a_test.rb:3", :fail => true
      result.should include "no test found before line 3"
      result.should_not include "ABC"
    end

    it "runs whole file without number" do
      result = testrbl "a_test.rb"
      result.should include "ABC\n"
      result.should include "BCD"
    end

    it "runs with options" do
      result = testrbl "a_test.rb -n '/xxx/'"
      result.should include "ABC"
      result.should_not include "BCD"
    end
  end

  context "test with string" do
    before do
      write "a_test.rb", <<-RUBY
        require 'test/unit'

        class Xxx < Test::Unit::TestCase
          test "a" do
            puts 'ABC'
          end

          test "b" do
            puts 'BCD'
          end

          test "c" do
            puts 'CDE'
          end
        end
      RUBY
    end

    it "runs test" do
      result = testrbl "a_test.rb:8"
      result.should_not include "ABC\n"
      result.should include "BCD\n"
      result.should_not include "CDE\n"
    end
  end

  context "shoulda" do
    before do
      write "a_test.rb", <<-RUBY
        require 'test/unit'
        require 'shoulda'

        class Xxx < Test::Unit::TestCase
          should "a" do
            puts 'ABC'
          end

          should "b" do
            puts 'BCD'
          end

          context "c" do
            should "d" do
              puts 'CDE'
            end

            should "e" do
              puts 'DEF'
            end

            should "..'?! [(" do
              puts 'EFG'
            end
          end

          context "g" do
            should "a" do
              puts "FGH"
            end
          end
        end
      RUBY
    end

    it "runs should" do
      result = testrbl "a_test.rb:9"
      result.should_not include "ABC\n"
      result.should include "BCD\n"
      result.should_not include "CDE\n"
    end

    it "runs stuff with regex special chars" do
      result = testrbl "a_test.rb:22"
      result.should_not include "DEF\n"
      result.should include "EFG\n"
    end

    it "runs context" do
      result = testrbl "a_test.rb:13"
      result.should_not include "ABC\n"
      result.should_not include "BCD\n"
      result.should include "CDE\n"
      result.should include "DEF\n"
    end

    it "runs via nested context" do
      result = testrbl "a_test.rb:28"
      result.should_not include "ABC\n"
      result.should_not include "EFG\n"
      result.should include "FGH\n"
    end
  end

  context "multiple files / folders" do
    before do
      write "a_test.rb", <<-RUBY
        require 'test/unit'

        class Xxx1 < Test::Unit::TestCase
          def test_xxx
            puts 'ABC'
          end
        end
      RUBY

      write "a/a_test.rb", <<-RUBY
        require 'test/unit'

        class Xxx2 < Test::Unit::TestCase
          def test_xxx
            puts 'BCD'
          end
        end
      RUBY

      write "a/b/c_test.rb", <<-RUBY
        require 'test/unit'

        class Xxx3 < Test::Unit::TestCase
          def test_xxx
            puts 'CDE'
          end
        end
      RUBY

      write "a/c/c_test.rb", <<-RUBY
        require 'test/unit'

        class Xxx4 < Test::Unit::TestCase
          def test_xxx
            puts 'DEF'
          end
        end
      RUBY
    end

    it "runs a folder with subfolders" do
      result = testrbl "a"
      result.should_not include "ABC\n"
      result.should include "BCD\n"
      result.should include "CDE\n"
    end

    it "runs files and folders" do
      result = testrbl "a/b a/c/c_test.rb"
      result.should_not include "ABC\n"
      result.should_not include "BCD\n"
      result.should include "CDE\n"
      result.should include "DEF\n"
    end

    it "runs multiple files" do
      result = testrbl "a/b/c_test.rb a/c/c_test.rb"
      result.should_not include "ABC\n"
      result.should_not include "BCD\n"
      result.should include "CDE\n"
      result.should include "DEF\n"
    end
  end
end
