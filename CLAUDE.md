# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby CLI tool for parsing and analyzing strace output, specifically targeting GitLab performance and debugging scenarios. The tool provides GitLab-specific pattern detection, color-coded output, and performance bottleneck identification.

## Architecture

- **Entry Point**: `bin/gitlab-strace-analyzer` - executable that requires the main library
- **Main Library**: `lib/gitlab_strace_analyzer.rb` - contains the core CLI and analysis logic
- **Dependencies**: Uses colorize for colored output, optparse for CLI parsing, and JSON for data handling
- **Structure**: Standard Ruby gem structure with bin/, lib/, spec/ directories

## Development Commands

### Setup
```bash
bundle install
```
Note: This project may require Ruby >= 2.7 due to json gem dependency.

### Testing
```bash
bundle exec rspec
```

### Linting
```bash
bundle exec rubocop
```

### Running the CLI
```bash
./bin/gitlab-strace-analyzer analyze /path/to/strace.log
```

## Key Files

- `Gemfile` - Dependencies including colorize, optparse, json, rspec, rubocop
- `bin/gitlab-strace-analyzer` - Main executable
- `lib/` - Core library code (to be implemented)
- `spec/` - Test files (to be implemented)

## Development Notes

The project is in early development phase with basic scaffolding in place. The main library and test files are not yet implemented, indicating this is a fresh project ready for development.