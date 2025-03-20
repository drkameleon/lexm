# LexM - Lemma Markup Format

LexM is a concise, human-readable format for representing dictionary-ready, lexical entries with their various forms, relationships, and redirections.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lexm'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install lexm
```

## Basic Format

A LexM entry consists of a lemma (headword) and optional elements:

```
lemma[annotations]|sublemma1,sublemma2,>(relation)target
```

## Examples

```ruby
require 'lexm'
include LexM

# Create a lemma with annotations
lemma = Lemma.new("rise[sp:rose,pp:risen]")
puts lemma
# => rise[sp:rose,pp:risen]

# Create a lemma with sublemmas
lemma = Lemma.new("abandon|abandoned,abandonment")
puts lemma
# => abandon|abandoned,abandonment

# Create a redirection entry
lemma = Lemma.new("better>>(cmp)good")
puts lemma
# => better>>(cmp)good

# Create a lemma with a redirection sublemma
lemma = Lemma.new("rose|>(sp)rise")
puts lemma
# => rose|>(sp)rise

# Build a lemma programmatically
lemma = Lemma.new
lemma.text = "run"
lemma.setAnnotations({"sp" => "ran", "pp" => "run"})
lemma.addSublemmas(["run away", "run up"])
puts lemma
# => run[sp:ran,pp:run]|run away,run up

# Work with a collection of lemmas
list = LemmaList.new
list.addLemma(Lemma.new("go[sp:went,pp:gone]|go about,go ahead"))
list.addLemma(Lemma.new("better>>(cmp)good"))

# Find lemmas that redirect to "good"
good_redirects = list.findRedirectionsTo("good")

# Iterate through all words
list.eachWord do |word|
    puts "Word: #{word}"
end
```

## Entry Types

### Standard Lemma

A standard dictionary entry with a headword and optional annotations:

```
run[sp:ran,pp:run]
```

### Lemma with Sublemmas

A headword with related forms or expressions:

```
abandon|abandoned,abandonment
```

### Redirection Entry

A pure redirection that points to another lemma:

```
better>>(cmp)good
```

### Mixed Format

A lemma that has sublemmas including a redirection:

```
left|left-handed,>(sp,pp)leave
```

## Attribution
LexM was created and developed by Yanis Zafirópulos (a.k.a. Dr.Kameleon). If you use this software, please maintain this attribution.

### How to Cite
If you use LexM in your research or applications, please cite it as:

Yanis Zafirópulos (2025). "LexM: Lemma Markup Format." GitHub repository: https://github.com/drkameleon/lexm

## License

This library is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).