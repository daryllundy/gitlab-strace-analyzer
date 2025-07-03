# GitLab Strace Analyzer 🔍

A Ruby CLI tool designed to parse and analyze strace output, specifically targeting common GitLab performance and debugging scenarios.

## Features
- **File Operations Detection**: Identifies all file system operations (open, read, write, etc.)
- **Permission Error Detection**: Highlights EACCES and permission denied errors
- **Network Timeout Detection**: Catches ETIMEDOUT and EAGAIN network issues
- **Color-coded Output**: Different colors for different issue types
- **Detailed Analysis**: Provides line-by-line analysis with statistics

## Installation

### Development Setup
```bash
git clone https://github.com/yourusername/gitlab-strace-analyzer.git
cd gitlab-strace-analyzer
bundle install
```

### From Source
```bash
gem build gitlab-strace-analyzer.gemspec
gem install gitlab-strace-analyzer-*.gem
```

## Usage

### Basic Analysis
```bash
./bin/gitlab-strace-analyzer analyze /path/to/strace.log
```

### Verbose Output
```bash
./bin/gitlab-strace-analyzer analyze /path/to/strace.log --verbose
```

### Help
```bash
./bin/gitlab-strace-analyzer --help
```

## Example Output

When analyzing a strace file, you'll see colored output like:

```
Analyzing strace file: examples/permission_errors.strace
==================================================

     15: openat(AT_FDCWD, "/var/opt/gitlab/git-data/repositories/group/project.git", O_RDONLY|O_NONBLOCK|O_CLOEXEC|O_DIRECTORY) = -1 EACCES (Permission denied)
     17: openat(AT_FDCWD, "/home/git/.gitconfig", O_RDONLY) = -1 EACCES (Permission denied)

Analysis Summary:
------------------------------
Total lines processed: 20
File operations: 8
Network operations: 0
Permission denied errors: 4
Network timeouts: 0

Issues Found:
------------------------------
Line 15: Permission denied
  openat(AT_FDCWD, "/var/opt/gitlab/git-data/repositories/group/project.git", O_RDONLY|O_NONBLOCK|O_CLOEXEC|O_DIRECTORY) = -1 EACCES (Permission denied)

Line 17: Permission denied
  openat(AT_FDCWD, "/home/git/.gitconfig", O_RDONLY) = -1 EACCES (Permission denied)
```

## Example Files

The `examples/` directory contains sample strace files demonstrating various scenarios:

- `permission_errors.strace` - Git operations with permission issues
- `network_timeouts.strace` - Network connection timeouts
- `file_operations.strace` - Normal file operations

Try analyzing them:
```bash
./bin/gitlab-strace-analyzer analyze examples/permission_errors.strace
./bin/gitlab-strace-analyzer analyze examples/network_timeouts.strace --verbose
```

## Development

### Running Tests
```bash
bundle exec rspec
```

### Code Quality
```bash
bundle exec rubocop
```

### Building
```bash
gem build gitlab-strace-analyzer.gemspec
```

## Detected Issues

The analyzer identifies several types of issues:

### File System Issues
- **Permission Denied**: EACCES errors when accessing files/directories
- **File Not Found**: ENOENT errors for missing files
- **File Operations**: All file system calls (open, read, write, stat, etc.)

### Network Issues
- **Connection Timeouts**: ETIMEDOUT errors
- **Resource Unavailable**: EAGAIN errors indicating temporary resource issues
- **Network Operations**: Socket operations (connect, send, recv, etc.)

### Color Coding
- 🔴 **Red**: Permission denied errors
- 🟡 **Yellow**: Network timeouts
- 🟢 **Green**: File operations (verbose mode)
- 🔵 **Cyan**: Network operations (verbose mode)
- 🟣 **Magenta**: File not found errors

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for your changes
5. Run the test suite
6. Submit a pull request

## License

This project is licensed under the MIT License.
