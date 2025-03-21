#!/usr/bin/env ruby
#############################################################
# LexM - Lemma Markup Format
#
# A specification for representing dictionary-ready,
# lexical entries and their relationships
#
# File: examples/basic_usage.rb
# (c) 2025 Yanis Zafirópulos (aka Dr.Kameleon)
#############################################################

# Basic usage example for the LexM library
require 'lexm'
include LexM

# Create lemmas in different ways
puts "=== Creating Different Types of Lemmas ==="

# From a string with annotations
lemma1 = Lemma.new("run[sp:ran,pp:run]")
puts "Lemma with annotations: #{lemma1}"

# From a string with sublemmas
lemma2 = Lemma.new("abandon|abandoned,abandonment")
puts "Lemma with sublemmas: #{lemma2}"

# From a string with redirection
lemma3 = Lemma.new("children>>(pl)child")
puts "Redirection lemma: #{lemma3}"

# From a string with mixed format
lemma4 = Lemma.new("rose|>(sp)rise")
puts "Mixed format lemma: #{lemma4}"

# Build a lemma programmatically
lemma5 = Lemma.new
lemma5.text = "good"
lemma5.setAnnotations({"cmp" => "better", "spl" => "best"})
puts "Programmatically built lemma: #{lemma5}"
puts

# Working with a lemma
puts "=== Working with Lemma Properties ==="
lemma = Lemma.new("go[sp:went,pp:gone]|go about,go ahead,go away")
puts "Lemma text: #{lemma.text}"
puts "Annotations: #{lemma.annotations.inspect}"
puts "Is redirection? #{lemma.redirected?}"
puts "Sublemmas: #{lemma.sublemmas.map { |s| s.text }.compact.join(', ')}"
puts

# Working with a collection
puts "=== Working with LemmaList ==="
list = LemmaList.new
list.addLemma(lemma1)
list.addLemma(lemma2)
list.addLemma(lemma3)
list.addLemma(lemma4)
list.addLemma(lemma5)

puts "Total lemmas: #{list.size}"
puts "Normal lemmas: #{list.normalLemmas.size}"
puts "Redirection lemmas: #{list.redirectedLemmas.size}"

# Finding lemmas
puts "\nLemmas with 'sp' annotation:"
sp_lemmas = list.findByAnnotation("sp")
sp_lemmas.each { |l| puts "  #{l.text}: #{l.annotations['sp']}" }

puts "\nLemmas redirecting to 'child':"
child_redirects = list.findRedirectionsTo("child")
child_redirects.each { |l| puts "  #{l.text}" }

# Working with all words
puts "\nAll words (lemmas and sublemmas):"
all_words = list.allWords
puts all_words.sort.join(", ")
puts

# Saving to a file
output_file = "example_output.lexm"
list.save(output_file)
puts "Saved lemmas to #{output_file}"

# Reading from the file
loaded_list = LemmaList.new(output_file)
puts "Loaded #{loaded_list.size} lemmas from file"