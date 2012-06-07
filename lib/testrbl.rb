require 'testrbl/version'

module Testrbl
  PATTERNS = [
    /^\s+(?:should|context|test)\s+['"](.*)['"]\s+do\s*$/,
    /^\s+def\s+test_([a-z_\d]+)\s*$/
  ]

  def self.run_from_cli(argv)
    # we only work with 1 file with line-number, everything else gets passed thourgh
    if argv.join(" ") !~ /^\S+:\d+$/
      run "testrb #{argv.map{|a| a.include?(' ') ? "'#{a}'" : a }.join(' ')}"
    end

    file, line = argv.first.split(':')
    file = "./#{file}" if file =~ /^[a-z]/ # fix 1.9 not being able to load local files
    run "testrb #{file} #{pattern_from_file(file, line)}"
  end

  def self.run(command)
    safe_to_bundle_exec = (File.exist?('Gemfile.lock') and File.read('Gemfile.lock').include?(" test-unit "))
    command = "#{"bundle exec " if safe_to_bundle_exec}#{command} --use-color"
    puts command
    exec command
  end

  private

  def self.pattern_from_file(file, line)
    content = File.readlines(file)
    search = content[0..(line.to_i-1)].reverse
    search.each do |line|
      PATTERNS.each do |r|
        return "-n '/#{Regexp.escape($1).gsub("'",".").gsub("\\ "," ")}/'" if line =~ r
      end
    end

    raise "no test found before line #{line}"
  end
end
