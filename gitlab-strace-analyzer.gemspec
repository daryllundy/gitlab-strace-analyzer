Gem::Specification.new do |spec|
  spec.name          = 'gitlab-strace-analyzer'
  spec.version       = '0.1.0'
  spec.authors       = ['GitLab Strace Analyzer Team']
  spec.email         = ['info@example.com']
  spec.summary       = 'A Ruby CLI tool for analyzing strace output with GitLab-specific patterns'
  spec.description   = 'Parses and analyzes strace output to identify common GitLab performance and debugging scenarios, including file operations, permission errors, and network timeouts.'
  spec.homepage      = 'https://github.com/yourusername/gitlab-strace-analyzer'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*', 'bin/*', 'examples/**/*', 'README.md', 'CLAUDE.md']
  spec.executables   = ['gitlab-strace-analyzer']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.6.0'

  spec.add_runtime_dependency 'colorize', '~> 0.8'
  spec.add_runtime_dependency 'json', '~> 2.0'

  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.0'
end
