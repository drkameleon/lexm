#!/usr/bin/env ruby
#############################################################
# LexM - Lemma Markup Format
#
# A specification for representing dictionary-ready,
# lexical entries and their relationships
#
# File: examples/test_sample.rb
# Author: Yanis Zafirópulos (aka Dr.Kameleon)
#############################################################

# Script to test processing the sample.lexm file
require 'lexm'
include LexM

sample_file = File.join(File.dirname(__FILE__), 'sample.lexm')
lemmas = LemmaList.new(sample_file)

puts "=== Sample File Analysis ==="
puts "Total lemmas: #{lemmas.size}"
puts "Normal lemmas: #{lemmas.normalLemmas.size}"
puts "Redirection lemmas: #{lemmas.redirectedLemmas.size}"

puts "\n=== Verbs ==="
verbs = lemmas.findByAnnotation("sp")
verbs.each do |verb|
    if verb.annotations["sp"] && verb.annotations["pp"]
        puts "#{verb.text}: #{verb.annotations["sp"]} (past), #{verb.annotations["pp"]} (participle)"
    end
end

puts "\n=== Words redirecting to 'good' ==="
good_redirects = lemmas.findRedirectionsTo("good")
good_redirects.each do |lemma|
    puts "#{lemma.text} -> good (#{lemma.redirect.types.join(', ')})"
end

puts "\n=== All words (sorted) ==="
all_words = lemmas.allWords.sort
puts all_words.join(", ")

puts "\n=== Finding 'look' and its sublemmas ==="
look = lemmas.findByText("look").first
if look
    puts "Found lemma: #{look.text}"
    puts "Sublemmas:"
    look.sublemmas.each do |sublemma|
        puts "  #{sublemma.text}"
    end
end