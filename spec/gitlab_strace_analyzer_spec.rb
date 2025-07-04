require 'spec_helper'
require 'tempfile'

RSpec.describe GitLabStraceAnalyzer do
  describe GitLabStraceAnalyzer::CLI do
    describe '#run' do
      it 'displays usage when no arguments provided' do
        cli = GitLabStraceAnalyzer::CLI.new([])
        expect { cli.run }.to output(/Usage: gitlab-strace-analyzer analyze/).to_stdout
      end

      it 'displays error for unknown command' do
        cli = GitLabStraceAnalyzer::CLI.new(['unknown'])
        expect { cli.run }.to output(/Unknown command: unknown/).to_stdout
      end

      it 'displays error for non-existent file' do
        cli = GitLabStraceAnalyzer::CLI.new(['analyze', 'nonexistent.file'])
        expect { cli.run }.to output(/Error: File not found/).to_stdout
      end
    end
  end

  describe GitLabStraceAnalyzer::StraceAnalyzer do
    let(:temp_file) { Tempfile.new('strace') }
    let(:analyzer) { GitLabStraceAnalyzer::StraceAnalyzer.new(temp_file.path) }

    after do
      temp_file.close
      temp_file.unlink
    end

    describe '#analyze' do
      it 'processes an empty file without errors' do
        temp_file.write('')
        temp_file.rewind

        expect { analyzer.analyze }.to output(/Analyzing strace file/).to_stdout
      end

      it 'detects file operations' do
        temp_file.write("open(\"/etc/passwd\", O_RDONLY) = 3\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(/File operations: .*1/).to_stdout
      end

      it 'detects permission denied errors' do
        temp_file.write("open(\"/root/secret\", O_RDONLY) = -1 EACCES (Permission denied)\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(/Permission denied errors: .*1/).to_stdout
      end

      it 'detects network timeouts' do
        temp_file.write("connect(3, {sa_family=AF_INET, sin_port=htons(80)}, 16) = -1 ETIMEDOUT (Connection timed out)\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(/Network timeouts: .*1/).to_stdout
      end

      it 'detects network operations' do
        temp_file.write("socket(AF_INET, SOCK_STREAM, IPPROTO_TCP) = 3\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(/Network operations: .*1/).to_stdout
      end

      it 'ignores empty lines and comments' do
        temp_file.write("\n# This is a comment\n\nopen(\"/etc/passwd\", O_RDONLY) = 3\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(/Total lines processed: 4/).to_stdout
      end
    end

    describe 'file operation detection' do
      it 'detects various file operations' do
        strace_content = [
          'open("/etc/passwd", O_RDONLY) = 3',
          'read(3, "root:x:0:0:root:/root:/bin/bash", 1024) = 32',
          'write(1, "Hello World", 11) = 11',
          'close(3) = 0',
          'stat("/tmp/file", {st_mode=S_IFREG|0644, st_size=123}) = 0'
        ].join("\n")

        temp_file.write(strace_content)
        temp_file.rewind

        expect { analyzer.analyze }.to output(/File operations: .*5/).to_stdout
      end
    end

    describe 'network operation detection' do
      it 'detects various network operations' do
        strace_content = [
          'socket(AF_INET, SOCK_STREAM, IPPROTO_TCP) = 3',
          'connect(3, {sa_family=AF_INET, sin_port=htons(80)}, 16) = 0',
          'send(3, "GET / HTTP/1.1\\r\\n\\r\\n", 18, 0) = 18',
          'recv(3, "HTTP/1.1 200 OK\\r\\n", 1024, 0) = 17'
        ].join("\n")

        temp_file.write(strace_content)
        temp_file.rewind

        expect { analyzer.analyze }.to output(/Network operations: .*4/).to_stdout
      end
    end

    describe 'error detection' do
      it 'detects file not found errors' do
        temp_file.write("open(\"/nonexistent/file\", O_RDONLY) = -1 ENOENT (No such file or directory)\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(/Issues Found/).to_stdout
      end

      it 'detects resource temporarily unavailable errors' do
        temp_file.write("recv(3, \"\", 1024, 0) = -1 EAGAIN (Resource temporarily unavailable)\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(/Network timeouts: .*1/).to_stdout
      end
    end

    describe 'GitLab-specific pattern detection' do
      it 'detects PostgreSQL activity' do
        temp_file.write("open(\"/var/opt/gitlab/postgresql/data/base/12345/pg_stat_tmp/db_0.stat\", O_RDONLY) = 3\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(/GitLab Components Activity/).to_stdout
      end

      it 'detects Redis activity' do
        temp_file.write("connect(3, {sa_family=AF_UNIX, sun_path=\"/var/opt/gitlab/redis/redis.socket\"}, 32) = 0\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(/GitLab Components Activity/).to_stdout
      end

      it 'detects Git repository operations' do
        temp_file.write("open(\"/var/opt/gitlab/git-data/repositories/project.git/objects/ab/cd123\", O_RDONLY) = 3\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(/GitLab Components Activity/).to_stdout
      end

      it 'detects GitLab log activity' do
        temp_file.write("write(2, \"ERROR: Something went wrong\", 25) = 25\nopen(\"/var/log/gitlab/gitlab-rails/application.log\", O_WRONLY) = 4\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(/GitLab Components Activity/).to_stdout
      end

      it 'detects Unicorn worker activity' do
        temp_file.write("execve(\"/opt/gitlab/embedded/bin/unicorn\", [\"unicorn\", \"worker\"], []) = 0\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(/GitLab Components Activity/).to_stdout
      end

      it 'detects Sidekiq worker activity' do
        temp_file.write("execve(\"/opt/gitlab/embedded/bin/sidekiq\", [\"sidekiq\", \"worker\"], []) = 0\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(/GitLab Components Activity/).to_stdout
      end
    end

    describe 'performance bottleneck detection' do
      it 'detects slow syscalls' do
        temp_file.write("read(3, \"data\", 1024) = 1024 <2.5>\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(/Performance Metrics/).to_stdout
      end

      it 'detects memory issues' do
        temp_file.write("mmap(NULL, 1048576, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = -1 ENOMEM (Cannot allocate memory)\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(/Memory issues: .*1/).to_stdout
      end

      it 'detects heavy disk I/O' do
        temp_file.write("read(3, \"large_data_chunk\", 2097152) = 2097152\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(%r{Heavy disk I/O operations: .*1}).to_stdout
      end

      it 'detects heavy network I/O' do
        temp_file.write("send(3, \"large_network_data\", 2097152) = 2097152\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(%r{Heavy network I/O operations: .*1}).to_stdout
      end

      it 'detects frequent failures' do
        temp_file.write("read(3, \"\", 1024) = -1 EBUSY (Device or resource busy)\n")
        temp_file.rewind

        expect { analyzer.analyze }.to output(/Issues Found/).to_stdout
      end
    end

    describe 'report generation' do
      let(:analyzer_with_options) do
        GitLabStraceAnalyzer::StraceAnalyzer.new(temp_file.path, { recommendations: true })
      end

      it 'generates recommendations' do
        temp_file.write("read(3, \"data\", 1024) = 1024 <2.5>\n")
        temp_file.rewind

        expect { analyzer_with_options.analyze }.to output(/Recommendations/).to_stdout
      end

      it 'generates JSON report' do
        temp_file.write("open(\"/etc/passwd\", O_RDONLY) = 3\n")
        temp_file.rewind

        analyzer.analyze
        json_report = analyzer.generate_json_report

        expect(json_report).to have_key(:summary)
        expect(json_report).to have_key(:issues)
        expect(json_report).to have_key(:recommendations)
        expect(json_report[:summary]).to have_key(:total_lines)
        expect(json_report[:summary]).to have_key(:file_operations)
      end

      it 'saves text report to file' do
        temp_file.write("open(\"/etc/passwd\", O_RDONLY) = 3\n")
        temp_file.rewind

        analyzer.analyze
        report_file = Tempfile.new(['report', '.txt'])

        begin
          analyzer.save_report(:text, report_file.path.chomp('.txt'))
          expect(File.exist?("#{report_file.path.chomp('.txt')}.txt")).to be true
        ensure
          File.delete("#{report_file.path.chomp('.txt')}.txt") if File.exist?("#{report_file.path.chomp('.txt')}.txt")
          report_file.close
          report_file.unlink
        end
      end

      it 'saves JSON report to file' do
        temp_file.write("open(\"/etc/passwd\", O_RDONLY) = 3\n")
        temp_file.rewind

        analyzer.analyze
        report_file = Tempfile.new(['report', '.json'])

        begin
          analyzer.save_report(:json, report_file.path.chomp('.json'))
          expect(File.exist?("#{report_file.path.chomp('.json')}.json")).to be true

          # Verify JSON content
          json_content = JSON.parse(File.read("#{report_file.path.chomp('.json')}.json"))
          expect(json_content).to have_key('summary')
          expect(json_content).to have_key('issues')
        ensure
          if File.exist?("#{report_file.path.chomp('.json')}.json")
            File.delete("#{report_file.path.chomp('.json')}.json")
          end
          report_file.close
          report_file.unlink
        end
      end
    end

    describe 'CLI option parsing' do
      it 'parses verbose option' do
        cli = GitLabStraceAnalyzer::CLI.new(['-v', 'analyze', temp_file.path])
        temp_file.write("open(\"/etc/passwd\", O_RDONLY) = 3\n")
        temp_file.rewind

        expect { cli.run }.to output(/File operations: .*1/).to_stdout
      end

      it 'parses recommendations option' do
        cli = GitLabStraceAnalyzer::CLI.new(['-r', 'analyze', temp_file.path])
        temp_file.write("open(\"/etc/passwd\", O_RDONLY) = 3\n")
        temp_file.rewind

        expect { cli.run }.to output(/Recommendations/).to_stdout
      end
    end
  end
end
