#############################################################
# LexM - Lemma Markup Format
#
# A specification for representing dictionary-ready,
# lexical entries and their relationships
#
# File: lexm.gemspec
# (c) 2025 Yanis Zafirópulos (aka Dr.Kameleon)
#############################################################

require_relative 'lib/lexm/version'

Gem::Specification.new do |spec|
    spec.name          = "lexm"
    spec.version       = LexM::VERSION
    spec.authors       = ["Yanis Zafirópulos"]
    spec.email         = ["drkameleon@gmail.com"]

    spec.summary       = "LexM - Lemma Markup Format"
    spec.description   = "A specification for representing, dictionary-ready lexical entries and their relationships"
    spec.homepage      = "https://github.com/drkameleon/lexm"
    spec.license       = "MIT"
    spec.required_ruby_version = Gem::Requirement.new(">= 2.5.0")

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/drkameleon/lexm"
    spec.metadata["changelog_uri"] = "https://github.com/drkameleon/lexm/blob/main/CHANGELOG.md"

    spec.files = Dir['{bin,lib}/**/*', 'LICENSE', 'README.md']
    
    spec.bindir        = "bin"
    spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
    spec.require_paths = ["lib"]

    spec.add_development_dependency "rspec", "~> 3.0"
    spec.add_development_dependency "yard", "~> 0.9"
end