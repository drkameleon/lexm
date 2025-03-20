#############################################################
# LexM - Lemma Markup Format
#
# A specification for representing, dictionary-ready
# lexical entries and their relationships
#
# File: spec/spec_helper.rb
# Author: Yanis Zafirópulos (aka Dr.Kameleon)
#############################################################

require "bundler/setup"
require "lexm"
include LexM

RSpec.configure do |config|
    config.example_status_persistence_file_path = ".rspec_status"

    config.disable_monkey_patching!

    config.expect_with :rspec do |c|
        c.syntax = :expect
    end
end