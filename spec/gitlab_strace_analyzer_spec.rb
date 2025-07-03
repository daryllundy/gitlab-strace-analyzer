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
  end
end
