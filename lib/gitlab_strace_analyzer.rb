require 'colorize'
require 'optparse'
require 'json'

module GitLabStraceAnalyzer
  class CLI
    def self.start(args)
      new(args).run
    end

    def initialize(args)
      @args = args
      @options = {}
      parse_options
    end

    def run
      if @args.empty?
        puts 'Usage: gitlab-strace-analyzer analyze <strace_file>'
        return
      end

      command = @args[0]
      case command
      when 'analyze'
        analyze_file(@args[1])
      else
        puts "Unknown command: #{command}"
        puts 'Available commands: analyze'
      end
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.banner = 'Usage: gitlab-strace-analyzer [options] command'

        opts.on('-v', '--verbose', 'Run verbosely') do |v|
          @options[:verbose] = v
        end

        opts.on('-h', '--help', 'Prints this help') do
          puts opts
          exit
        end
      end.parse!(@args)
    end

    def analyze_file(file_path)
      unless file_path && File.exist?(file_path)
        puts 'Error: File not found or not specified'.red
        return
      end

      analyzer = StraceAnalyzer.new(file_path, @options)
      analyzer.analyze
    end
  end

  class StraceAnalyzer
    FILE_OPERATIONS = %w[open openat read write readv writev close stat fstat lstat access chmod chown mkdir rmdir
                         unlink rename].freeze
    NETWORK_OPERATIONS = %w[socket connect accept bind listen send sendto recv recvfrom].freeze

    def initialize(file_path, options = {})
      @file_path = file_path
      @options = options
      @issues = []
      @stats = {
        total_lines: 0,
        file_operations: 0,
        network_operations: 0,
        permission_denied: 0,
        network_timeouts: 0
      }
    end

    def analyze
      puts "Analyzing strace file: #{@file_path}".blue.bold
      puts '=' * 50

      File.open(@file_path, 'r') do |file|
        file.each_line.with_index do |line, index|
          @stats[:total_lines] += 1
          analyze_line(line.strip, index + 1)
        end
      end

      print_summary
      print_issues
    end

    private

    def analyze_line(line, line_number)
      return if line.empty? || line.start_with?('#')

      detect_file_operations(line, line_number)
      detect_permission_denied(line, line_number)
      detect_network_timeouts(line, line_number)
      detect_network_operations(line, line_number)
    end

    def detect_file_operations(line, line_number)
      FILE_OPERATIONS.each do |op|
        next unless line.match(/\b#{op}\(/)

        @stats[:file_operations] += 1

        puts "#{line_number.to_s.rjust(6)}: #{line}".green if @options[:verbose]

        if line.include?('ENOENT') || line.include?('No such file')
          add_issue(:file_not_found, line_number, line, 'File not found')
        end

        break
      end
    end

    def detect_permission_denied(line, line_number)
      return unless line.include?('EACCES') || line.include?('Permission denied')

      @stats[:permission_denied] += 1
      add_issue(:permission_denied, line_number, line, 'Permission denied')
      puts "#{line_number.to_s.rjust(6)}: #{line}".red
    end

    def detect_network_timeouts(line, line_number)
      if line.include?('ETIMEDOUT') || line.include?('Connection timed out') ||
         line.include?('EAGAIN') || line.include?('Resource temporarily unavailable')
        @stats[:network_timeouts] += 1
        add_issue(:network_timeout, line_number, line, 'Network timeout detected')
        puts "#{line_number.to_s.rjust(6)}: #{line}".yellow
      end
    end

    def detect_network_operations(line, line_number)
      NETWORK_OPERATIONS.each do |op|
        next unless line.match(/\b#{op}\(/)

        @stats[:network_operations] += 1

        puts "#{line_number.to_s.rjust(6)}: #{line}".cyan if @options[:verbose]

        break
      end
    end

    def add_issue(type, line_number, line, description)
      @issues << {
        type: type,
        line_number: line_number,
        line: line,
        description: description
      }
    end

    def print_summary
      puts "\nAnalysis Summary:".blue.bold
      puts '-' * 30
      puts "Total lines processed: #{@stats[:total_lines]}"
      puts "File operations: #{@stats[:file_operations].to_s.green}"
      puts "Network operations: #{@stats[:network_operations].to_s.cyan}"
      puts "Permission denied errors: #{@stats[:permission_denied].to_s.red}"
      puts "Network timeouts: #{@stats[:network_timeouts].to_s.yellow}"
    end

    def print_issues
      return if @issues.empty?

      puts "\nIssues Found:".red.bold
      puts '-' * 30

      @issues.each do |issue|
        color = case issue[:type]
                when :permission_denied then :red
                when :network_timeout then :yellow
                when :file_not_found then :magenta
                else :white
                end

        puts "Line #{issue[:line_number]}: #{issue[:description]}".colorize(color)
        puts "  #{issue[:line]}"
        puts
      end
    end
  end
end
