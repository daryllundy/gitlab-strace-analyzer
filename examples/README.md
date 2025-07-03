# Example Strace Files

This directory contains example strace output files that demonstrate different types of issues the GitLab Strace Analyzer can detect:

## permission_errors.strace
Demonstrates various permission denied errors that can occur when GitLab processes try to access files or directories they don't have permission to read.

## network_timeouts.strace
Shows network connection timeouts and related network issues that can affect GitLab's ability to communicate with external services.

## file_operations.strace
Contains normal file operations from a Git command, showing how the analyzer identifies and categorizes file system interactions.

## Usage

You can analyze any of these files using:

```bash
./bin/gitlab-strace-analyzer analyze examples/permission_errors.strace
./bin/gitlab-strace-analyzer analyze examples/network_timeouts.strace
./bin/gitlab-strace-analyzer analyze examples/file_operations.strace
```

Add the `--verbose` flag to see detailed output of all file and network operations.