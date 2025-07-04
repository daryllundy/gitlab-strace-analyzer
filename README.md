# GitLab Strace Analyzer 🔍

A Ruby CLI tool designed to parse and analyze strace output, specifically targeting common GitLab performance and debugging scenarios.

## Demo

[![asciicast](https://asciinema.org/a/KXUHyIMgun4ki7xZQbk8Ms3aY.svg)](https://asciinema.org/a/KXUHyIMgun4ki7xZQbk8Ms3aY)

*Click the demo above to see the GitLab Strace Analyzer in action!*

## Features
- **File Operations Detection**: Identifies all file system operations (open, read, write, etc.)
- **Permission Error Detection**: Highlights EACCES and permission denied errors
- **Network Timeout Detection**: Catches ETIMEDOUT and EAGAIN network issues
- **GitLab-Specific Pattern Detection**: Detects PostgreSQL, Redis, Git repositories, logs, and process activity
- **Performance Bottleneck Analysis**: Identifies slow syscalls, memory issues, and heavy I/O operations
- **Smart Recommendations**: Provides actionable suggestions based on detected patterns
- **Multiple Output Formats**: Supports text and JSON report generation
- **Color-coded Output**: Different colors for different issue types and GitLab components
- **Detailed Analysis**: Provides line-by-line analysis with comprehensive statistics

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

### Show Recommendations
```bash
./bin/gitlab-strace-analyzer analyze /path/to/strace.log --recommendations
```

### Save Report to File
```bash
# Save as text report
./bin/gitlab-strace-analyzer analyze /path/to/strace.log --output report --format text

# Save as JSON report
./bin/gitlab-strace-analyzer analyze /path/to/strace.log --output report --format json
```

### All Options Combined
```bash
./bin/gitlab-strace-analyzer analyze /path/to/strace.log --verbose --recommendations --output analysis_report --format json
```

### Help
```bash
./bin/gitlab-strace-analyzer --help
```

## Example Output

When analyzing a strace file, you'll see colored output like:

```
Analyzing strace file: examples/gitlab_activity.strace
==================================================

Analysis Summary:
------------------------------
Total lines processed: 150
File operations: 45
Network operations: 12
Permission denied errors: 2
Network timeouts: 1

GitLab Components Activity:
------------------------------
Postgres: 8
Redis: 3
Git repos: 12
Logs: 5
Unicorn: 2
Sidekiq: 4

Performance Metrics:
------------------------------
Slow syscalls (>1s): 3
Memory issues: 0
Heavy disk I/O operations: 2
Heavy network I/O operations: 1

Issues Found:
------------------------------
Line 15: Permission denied
  openat(AT_FDCWD, "/var/opt/gitlab/git-data/repositories/group/project.git", O_RDONLY) = -1 EACCES (Permission denied)

Line 89: Slow syscall detected: read (2.5s)
  read(3, "large_database_result", 2097152) = 2097152 <2.5>

Recommendations:
------------------------------
1. Multiple permission denied errors - review file/directory permissions and user access
2. High Git repository activity - consider Git GC optimization and repository maintenance
3. Consider investigating slow syscalls - 3 detected
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

### GitLab-Specific Patterns
- **PostgreSQL Activity**: Database operations and queries
- **Redis Activity**: Cache operations and connections
- **Git Repository Operations**: Repository access and Git operations
- **GitLab Logs**: Application and system log activity
- **Process Activity**: Unicorn, Sidekiq, and Gitaly process monitoring
- **Upload/Storage**: File upload and storage operations

### Performance Issues
- **Slow Syscalls**: System calls taking longer than 1 second
- **Memory Issues**: Memory allocation failures (ENOMEM)
- **Heavy Disk I/O**: Large file operations (>1MB)
- **Heavy Network I/O**: Large network transfers (>1MB)
- **Resource Contention**: Frequent EBUSY/EAGAIN errors

### Color Coding
- 🔴 **Red**: Permission denied errors, slow syscalls, memory issues
- 🟡 **Yellow**: Network timeouts, heavy I/O operations
- 🟢 **Green**: File operations, recommendations (verbose mode)
- 🔵 **Cyan**: Network operations (verbose mode)
- 🟣 **Magenta**: File not found errors, database operations
- 🟠 **Light colors**: GitLab-specific components (Redis, Git, processes, etc.)

## JSON Output Format

When using `--format json`, the analyzer generates a structured JSON report:

```json
{
  "summary": {
    "total_lines": 150,
    "file_operations": 45,
    "network_operations": 12,
    "permission_denied": 2,
    "network_timeouts": 1,
    "gitlab_patterns": {
      "postgres": 8,
      "redis": 3,
      "git_repos": 12,
      "logs": 5,
      "unicorn": 2,
      "sidekiq": 4
    },
    "performance_metrics": {
      "slow_syscalls": 3,
      "memory_issues": 0,
      "disk_io_heavy": 2,
      "network_heavy": 1
    }
  },
  "issues": [
    {
      "type": "permission_denied",
      "line_number": 15,
      "line": "openat(...) = -1 EACCES (Permission denied)",
      "description": "Permission denied"
    }
  ],
  "recommendations": [
    "Multiple permission denied errors - review file/directory permissions and user access",
    "High Git repository activity - consider Git GC optimization"
  ],
  "analysis_timestamp": "2024-01-15T10:30:00Z"
}
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for your changes
5. Run the test suite
6. Submit a pull request

## License

This project is licensed under the MIT License.
