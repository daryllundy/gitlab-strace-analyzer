require 'colorize'
require 'optparse'
require 'json'
require 'time'

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

        opts.on('-r', '--recommendations', 'Show recommendations') do |r|
          @options[:recommendations] = r
        end

        opts.on('-f', '--format FORMAT', %w[json text], 'Output format (json, text)') do |f|
          @options[:format] = f.to_sym
        end

        opts.on('-o', '--output FILE', 'Save report to file') do |o|
          @options[:output] = o
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

      return unless @options[:output]

      format = @options[:format] || :text
      analyzer.save_report(format, @options[:output])
    end
  end

  class StraceAnalyzer
    FILE_OPERATIONS = %w[open openat read write readv writev close stat fstat lstat access chmod chown mkdir rmdir
                         unlink rename].freeze
    NETWORK_OPERATIONS = %w[socket connect accept bind listen send sendto recv recvfrom].freeze

    GITLAB_PATTERNS = {
      postgres: %r{/var/opt/gitlab/postgresql/},
      redis: %r{/var/opt/gitlab/redis/},
      git_repos: %r{/var/opt/gitlab/git-data/repositories/},
      logs: %r{/var/log/gitlab/},
      uploads: %r{/var/opt/gitlab/gitlab-rails/uploads/},
      shared: %r{/var/opt/gitlab/gitlab-rails/shared/},
      tmp: %r{/var/opt/gitlab/gitlab-rails/tmp/},
      config: %r{/etc/gitlab/},
      nginx: %r{/var/opt/gitlab/nginx/},
      unicorn: /unicorn.*worker/,
      sidekiq: /sidekiq.*worker/,
      gitaly: /gitaly.*server/,
      database_query: /postgres.*SELECT|INSERT|UPDATE|DELETE/,
      git_operations: /git.*(?:clone|fetch|push|pull|merge|rebase)/
    }.freeze

    def initialize(file_path, options = {})
      @file_path = file_path
      @options = options
      @issues = []
      @stats = {
        total_lines: 0,
        file_operations: 0,
        network_operations: 0,
        permission_denied: 0,
        network_timeouts: 0,
        gitlab_patterns: Hash.new(0),
        performance_metrics: {
          slow_syscalls: 0,
          high_cpu_processes: [],
          memory_issues: 0,
          disk_io_heavy: 0,
          network_heavy: 0
        }
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
      print_recommendations if @options[:recommendations]
    end

    def generate_json_report
      {
        summary: {
          total_lines: @stats[:total_lines],
          file_operations: @stats[:file_operations],
          network_operations: @stats[:network_operations],
          permission_denied: @stats[:permission_denied],
          network_timeouts: @stats[:network_timeouts],
          gitlab_patterns: @stats[:gitlab_patterns],
          performance_metrics: @stats[:performance_metrics]
        },
        issues: @issues,
        recommendations: generate_recommendations,
        analysis_timestamp: Time.now.iso8601
      }
    end

    def save_report(format = :text, filename = nil)
      filename ||= "strace_analysis_#{Time.now.strftime('%Y%m%d_%H%M%S')}"

      case format
      when :json
        File.write("#{filename}.json", JSON.pretty_generate(generate_json_report))
        puts "JSON report saved to #{filename}.json".green
      when :text
        File.open("#{filename}.txt", 'w') do |f|
          # Redirect stdout to file temporarily
          old_stdout = $stdout
          $stdout = f
          print_summary
          print_issues
          print_recommendations
          $stdout = old_stdout
        end
        puts "Text report saved to #{filename}.txt".green
      end
    end

    private

    def analyze_line(line, line_number)
      return if line.empty? || line.start_with?('#')

      detect_file_operations(line, line_number)
      detect_permission_denied(line, line_number)
      detect_network_timeouts(line, line_number)
      detect_network_operations(line, line_number)
      detect_gitlab_patterns(line, line_number)
      detect_performance_bottlenecks(line, line_number)
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

    def detect_gitlab_patterns(line, line_number)
      GITLAB_PATTERNS.each do |pattern_name, pattern|
        next unless line.match(pattern)

        @stats[:gitlab_patterns][pattern_name] += 1

        case pattern_name
        when :postgres, :database_query
          puts "#{line_number.to_s.rjust(6)}: [DB] #{line}".magenta if @options[:verbose]
          check_database_performance(line, line_number)
        when :redis
          puts "#{line_number.to_s.rjust(6)}: [REDIS] #{line}".light_red if @options[:verbose]
        when :git_repos, :git_operations
          puts "#{line_number.to_s.rjust(6)}: [GIT] #{line}".light_green if @options[:verbose]
          check_git_performance(line, line_number)
        when :logs
          puts "#{line_number.to_s.rjust(6)}: [LOG] #{line}".light_blue if @options[:verbose]
        when :uploads, :shared, :tmp
          puts "#{line_number.to_s.rjust(6)}: [STORAGE] #{line}".light_yellow if @options[:verbose]
        when :unicorn, :sidekiq, :gitaly
          puts "#{line_number.to_s.rjust(6)}: [PROCESS] #{line}".light_cyan if @options[:verbose]
          check_process_performance(line, line_number, pattern_name)
        end

        break
      end
    end

    def check_database_performance(line, line_number)
      return unless line.include?('slow query') || line.match(/\d+\.\d+ms/) && line.match(/\d+\.\d+ms/)[0].to_f > 1000

      add_issue(:slow_database_query, line_number, line, 'Slow database query detected')
    end

    def check_git_performance(line, line_number)
      return unless line.include?('pack-objects') || line.include?('receiving objects')

      add_issue(:git_performance, line_number, line, 'Git operation may be resource intensive')
    end

    def check_process_performance(line, line_number, process_type)
      return unless line.include?('timeout') || line.include?('killed') || line.include?('segfault')

      add_issue(:process_issue, line_number, line, "#{process_type.to_s.capitalize} process issue detected")
    end

    def detect_performance_bottlenecks(line, line_number)
      # Extract syscall execution time if present
      if line.match(/<(\d+\.\d+)>/)
        execution_time = line.match(/<(\d+\.\d+)>/)[1].to_f
        if execution_time > 1.0 # Slow syscall threshold: 1 second
          @stats[:performance_metrics][:slow_syscalls] += 1
          syscall_name = line.match(/^[^(]+/)[0] if line.match(/^[^(]+/)
          add_issue(:slow_syscall, line_number, line, "Slow syscall detected: #{syscall_name} (#{execution_time}s)")
        end
      end

      # Detect high CPU usage patterns
      if line.include?('CPU') && line.match(/(\d+)%/)
        cpu_usage = line.match(/(\d+)%/)[1].to_i
        if cpu_usage > 80
          process_name = extract_process_name(line)
          unless @stats[:performance_metrics][:high_cpu_processes].include?(process_name)
            @stats[:performance_metrics][:high_cpu_processes] << process_name
          end
          add_issue(:high_cpu_usage, line_number, line, "High CPU usage detected: #{cpu_usage}%")
        end
      end

      # Detect memory issues
      if line.include?('ENOMEM') || line.include?('Out of memory') || line.include?('mmap') && line.include?('failed')
        @stats[:performance_metrics][:memory_issues] += 1
        add_issue(:memory_issue, line_number, line, 'Memory allocation issue detected')
      end

      # Detect heavy disk I/O
      if line.match(/^(read|write|pread|pwrite|readv|writev)/) && line.include?('=')
        bytes_match = line.match(/= (\d+)/)
        if bytes_match && bytes_match[1].to_i > 1_048_576 # > 1MB
          @stats[:performance_metrics][:disk_io_heavy] += 1
          add_issue(:heavy_disk_io, line_number, line, "Heavy disk I/O detected: #{bytes_match[1]} bytes")
        end
      end

      # Detect network heavy operations
      if line.match(/^(send|recv|sendto|recvfrom)/) && line.include?('=')
        bytes_match = line.match(/= (\d+)/)
        if bytes_match && bytes_match[1].to_i > 1_048_576 # > 1MB
          @stats[:performance_metrics][:network_heavy] += 1
          add_issue(:heavy_network_io, line_number, line, "Heavy network I/O detected: #{bytes_match[1]} bytes")
        end
      end

      # Detect frequent failed syscalls
      if line.include?('= -1') && (line.include?('EBUSY') || line.include?('EAGAIN') || line.include?('EWOULDBLOCK'))
        add_issue(:frequent_failures, line_number, line,
                  'Frequent syscall failures detected - may indicate resource contention')
      end
    end

    def extract_process_name(line)
      # Try to extract process name from various formats
      if line.match(/\[([^\]]+)\]/)
        line.match(/\[([^\]]+)\]/)[1]
      elsif line.match(/(\w+):\s/)
        line.match(/(\w+):\s/)[1]
      else
        'unknown'
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

      if @stats[:gitlab_patterns].any?
        puts "\nGitLab Components Activity:".blue.bold
        puts '-' * 30
        @stats[:gitlab_patterns].each do |pattern, count|
          color = case pattern
                  when :postgres, :database_query then :magenta
                  when :redis then :light_red
                  when :git_repos, :git_operations then :light_green
                  when :logs then :light_blue
                  when :uploads, :shared, :tmp then :light_yellow
                  when :unicorn, :sidekiq, :gitaly then :light_cyan
                  else :white
                  end
          puts "#{pattern.to_s.gsub('_', ' ').capitalize}: #{count.to_s.colorize(color)}"
        end
      end

      metrics = @stats[:performance_metrics]
      return unless metrics.values.any? { |v| v.is_a?(Integer) && v > 0 } || metrics[:high_cpu_processes].any?

      puts "\nPerformance Metrics:".red.bold
      puts '-' * 30
      puts "Slow syscalls (>1s): #{metrics[:slow_syscalls].to_s.red}"
      puts "Memory issues: #{metrics[:memory_issues].to_s.red}"
      puts "Heavy disk I/O operations: #{metrics[:disk_io_heavy].to_s.yellow}"
      puts "Heavy network I/O operations: #{metrics[:network_heavy].to_s.yellow}"
      return unless metrics[:high_cpu_processes].any?

      puts "High CPU processes: #{metrics[:high_cpu_processes].join(', ').light_red}"
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
                when :slow_database_query then :light_magenta
                when :git_performance then :light_green
                when :process_issue then :light_red
                when :slow_syscall then :red
                when :high_cpu_usage then :light_red
                when :memory_issue then :red
                when :heavy_disk_io then :yellow
                when :heavy_network_io then :yellow
                when :frequent_failures then :light_red
                else :white
                end

        puts "Line #{issue[:line_number]}: #{issue[:description]}".colorize(color)
        puts "  #{issue[:line]}"
        puts
      end
    end

    def print_recommendations
      puts "\nRecommendations:".green.bold
      puts '-' * 30

      recommendations = generate_recommendations
      recommendations.each_with_index do |rec, index|
        puts "#{index + 1}. #{rec}".green
      end
    end

    def generate_recommendations
      recommendations = []

      # Performance-based recommendations
      if @stats[:performance_metrics][:slow_syscalls] > 10
        recommendations << "Consider investigating slow syscalls - #{@stats[:performance_metrics][:slow_syscalls]} detected"
      end

      if @stats[:performance_metrics][:memory_issues] > 0
        recommendations << 'Memory allocation issues detected - check available memory and swap usage'
      end

      if @stats[:performance_metrics][:disk_io_heavy] > 50
        recommendations << 'High disk I/O detected - consider optimizing file access patterns or adding SSD storage'
      end

      if @stats[:performance_metrics][:network_heavy] > 20
        recommendations << 'Heavy network I/O detected - consider network optimization or caching strategies'
      end

      # GitLab-specific recommendations
      if @stats[:gitlab_patterns][:postgres] > 100
        recommendations << 'High PostgreSQL activity - consider database optimization and query tuning'
      end

      if @stats[:gitlab_patterns][:redis] > 50
        recommendations << 'High Redis activity - monitor Redis memory usage and consider Redis optimization'
      end

      if @stats[:gitlab_patterns][:git_repos] > 30
        recommendations << 'High Git repository activity - consider Git GC optimization and repository maintenance'
      end

      if @stats[:permission_denied] > 5
        recommendations << 'Multiple permission denied errors - review file/directory permissions and user access'
      end

      if @stats[:network_timeouts] > 3
        recommendations << 'Network timeout issues detected - check network connectivity and firewall settings'
      end

      if recommendations.empty?
        recommendations << 'Consider running strace with -T flag for timing information if not already present'
      end

      recommendations
    end
  end
end
