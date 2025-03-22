#############################################################
# LexM - Lemma Markup Format
#
# A specification for representing dictionary-ready,
# lexical entries and their relationships
#
# File: spec/lexm_spec.rb
# (c) 2025 Yanis Zafirópulos (aka Dr.Kameleon)
#############################################################

require "spec_helper"

RSpec.describe LexM do
    it "has a version number" do
        expect(LexM::VERSION).not_to be nil
    end

    describe Lemma do
        describe "#initialize" do
            it "creates an empty lemma when no input is provided" do
                lemma = Lemma.new
                expect(lemma.text).to be_nil
                expect(lemma.annotations).to be_empty
                expect(lemma.sublemmas).to be_empty
                expect(lemma.redirect).to be_nil
            end

            it "parses a lemma with annotations" do
                lemma = Lemma.new("run[sp:ran,pp:run]")
                expect(lemma.text).to eq("run")
                expect(lemma.annotations["sp"]).to eq("ran")
                expect(lemma.annotations["pp"]).to eq("run")
                expect(lemma.sublemmas).to be_empty
            end

            it "parses a lemma with sublemmas" do
                lemma = Lemma.new("abandon|abandoned,abandonment")
                expect(lemma.text).to eq("abandon")
                expect(lemma.annotations).to be_empty
                expect(lemma.sublemmas.size).to eq(2)
                expect(lemma.sublemmas[0].text).to eq("abandoned")
                expect(lemma.sublemmas[1].text).to eq("abandonment")
            end

            it "parses a redirection lemma" do
                lemma = Lemma.new("children>>(pl)child")
                expect(lemma.text).to eq("children")
                expect(lemma.redirect).not_to be_nil
                expect(lemma.redirect.target).to eq("child")
                expect(lemma.redirect.types).to eq(["pl"])
                expect(lemma.redirected?).to be true
            end

            it "parses a lemma with a redirection sublemma" do
                lemma = Lemma.new("rose|>(sp)rise")
                expect(lemma.text).to eq("rose")
                expect(lemma.sublemmas.size).to eq(1)
                expect(lemma.sublemmas[0].redirected?).to be true
                expect(lemma.sublemmas[0].redirect.target).to eq("rise")
                expect(lemma.sublemmas[0].redirect.types).to eq(["sp"])
            end
            
            it "stores source location information" do
                lemma = Lemma.new("run[sp:ran]", "test.lexm", 10, 5)
                expect(lemma.source_file).to eq("test.lexm")
                expect(lemma.source_line).to eq(10)
                expect(lemma.source_column).to eq(5)
            end
        end

        describe "#to_s" do
            it "correctly formats a lemma with annotations" do
                lemma = Lemma.new
                lemma.text = "run"
                lemma.setAnnotations({"sp" => "ran", "pp" => "run"})
                expect(lemma.to_s).to eq("run[sp:ran,pp:run]")
            end

            it "correctly formats a lemma with sublemmas" do
                lemma = Lemma.new
                lemma.text = "abandon"
                lemma.addSublemmas(["abandoned", "abandonment"])
                expect(lemma.to_s).to eq("abandon|abandoned,abandonment")
            end

            it "correctly formats a redirection lemma" do
                lemma = Lemma.new
                lemma.text = "children"
                lemma.setRedirect("child", ["pl"])
                expect(lemma.to_s).to eq("children>>(pl)child")
            end
        end

        describe "#clear" do
            it "clears annotations, sublemmas, and redirect but keeps the lemma text" do
                lemma = Lemma.new("run[sp:ran,pp:run]|run away,run up")
                lemma.clear
                expect(lemma.text).to eq("run")
                expect(lemma.annotations).to be_empty
                expect(lemma.sublemmas).to be_empty
                expect(lemma.redirect).to be_nil
            end
        end

        describe "#parseSublemmas" do
            it "correctly parses a pure redirection sublemma" do
                lemma = Lemma.new("word|>(sp,pp)target")
                expect(lemma.sublemmas.size).to eq(1)
                expect(lemma.sublemmas[0].text).to be_nil
                expect(lemma.sublemmas[0].redirect).not_to be_nil
                expect(lemma.sublemmas[0].redirect.target).to eq("target")
                expect(lemma.sublemmas[0].redirect.types).to eq(["sp", "pp"])
            end

            it "correctly parses mixed normal sublemmas and pure redirection sublemmas" do
                lemma = Lemma.new("word|one,>(sp,pp)target")
                expect(lemma.sublemmas.size).to eq(2)
                
                # First sublemma should be a normal one
                expect(lemma.sublemmas[0].text).to eq("one")
                expect(lemma.sublemmas[0].redirect).to be_nil
                
                # Second sublemma should be a pure redirection
                expect(lemma.sublemmas[1].text).to be_nil
                expect(lemma.sublemmas[1].redirect).not_to be_nil
                expect(lemma.sublemmas[1].redirect.target).to eq("target")
                expect(lemma.sublemmas[1].redirect.types).to eq(["sp", "pp"])
            end
            
            it "correctly parses multiple mixed sublemmas with redirections" do
                lemma = Lemma.new("complex|one,two,>(rel1)target1,three,>(rel2,rel3)target2")
                expect(lemma.sublemmas.size).to eq(5)
                
                # Check normal sublemmas
                expect(lemma.sublemmas[0].text).to eq("one")
                expect(lemma.sublemmas[0].redirect).to be_nil
                expect(lemma.sublemmas[1].text).to eq("two")
                expect(lemma.sublemmas[1].redirect).to be_nil
                expect(lemma.sublemmas[3].text).to eq("three")
                expect(lemma.sublemmas[3].redirect).to be_nil
                
                # Check redirection sublemmas
                expect(lemma.sublemmas[2].text).to be_nil
                expect(lemma.sublemmas[2].redirect).not_to be_nil
                expect(lemma.sublemmas[2].redirect.target).to eq("target1")
                expect(lemma.sublemmas[2].redirect.types).to eq(["rel1"])
                
                expect(lemma.sublemmas[4].text).to be_nil
                expect(lemma.sublemmas[4].redirect).not_to be_nil
                expect(lemma.sublemmas[4].redirect.target).to eq("target2")
                expect(lemma.sublemmas[4].redirect.types).to eq(["rel2", "rel3"])
            end
            
            it "correctly handles sublemmas with parentheses in their text" do
                lemma = Lemma.new("word|term(a,b),>(rel)target")
                expect(lemma.sublemmas.size).to eq(2)
                expect(lemma.sublemmas[0].text).to eq("term(a,b)")
                expect(lemma.sublemmas[0].redirect).to be_nil
                
                expect(lemma.sublemmas[1].text).to be_nil
                expect(lemma.sublemmas[1].redirect).not_to be_nil
                expect(lemma.sublemmas[1].redirect.target).to eq("target")
                expect(lemma.sublemmas[1].redirect.types).to eq(["rel"])
            end
            
            it "correctly handles redirection sublemma followed by normal sublemma" do
                lemma = Lemma.new("wrung|>(sp,pp)wring,abc")
                expect(lemma.sublemmas.size).to eq(2)
                
                # First sublemma should be a pure redirection
                expect(lemma.sublemmas[0].text).to be_nil
                expect(lemma.sublemmas[0].redirect).not_to be_nil
                expect(lemma.sublemmas[0].redirect.target).to eq("wring")
                expect(lemma.sublemmas[0].redirect.types).to eq(["sp", "pp"])
                
                # Second sublemma should be a normal one
                expect(lemma.sublemmas[1].text).to eq("abc")
                expect(lemma.sublemmas[1].redirect).to be_nil
            end
            
            it "correctly handles normal sublemma followed by redirection sublemma" do
                lemma = Lemma.new("wrung|abc,>(sp,pp)wring")
                expect(lemma.sublemmas.size).to eq(2)
                
                # First sublemma should be a normal one
                expect(lemma.sublemmas[0].text).to eq("abc")
                expect(lemma.sublemmas[0].redirect).to be_nil
                
                # Second sublemma should be a pure redirection
                expect(lemma.sublemmas[1].text).to be_nil
                expect(lemma.sublemmas[1].redirect).not_to be_nil
                expect(lemma.sublemmas[1].redirect.target).to eq("wring")
                expect(lemma.sublemmas[1].redirect.types).to eq(["sp", "pp"])
            end
            
            it "correctly handles multiple mixed sublemmas with redirection first" do
                lemma = Lemma.new("complex|>(rel1)target1,one,>(rel2,rel3)target2,two")
                expect(lemma.sublemmas.size).to eq(4)
                
                # Check sublemmas in order
                expect(lemma.sublemmas[0].text).to be_nil
                expect(lemma.sublemmas[0].redirect).not_to be_nil
                expect(lemma.sublemmas[0].redirect.target).to eq("target1")
                expect(lemma.sublemmas[0].redirect.types).to eq(["rel1"])
                
                expect(lemma.sublemmas[1].text).to eq("one")
                expect(lemma.sublemmas[1].redirect).to be_nil
                
                expect(lemma.sublemmas[2].text).to be_nil
                expect(lemma.sublemmas[2].redirect).not_to be_nil
                expect(lemma.sublemmas[2].redirect.target).to eq("target2")
                expect(lemma.sublemmas[2].redirect.types).to eq(["rel2", "rel3"])
                
                expect(lemma.sublemmas[3].text).to eq("two")
                expect(lemma.sublemmas[3].redirect).to be_nil
            end
        end
        
        describe "#smart_split_sublemmas" do
            it "correctly splits simple comma-separated sublemmas" do
                lemma = Lemma.new
                result = lemma.send(:smart_split_sublemmas, "one,two,three")
                expect(result).to eq(["one", "two", "three"])
            end
            
            it "preserves commas inside parentheses" do
                lemma = Lemma.new
                result = lemma.send(:smart_split_sublemmas, "one,>(sp,pp)target")
                expect(result).to eq(["one", ">(sp,pp)target"])
            end
            
            it "handles nested parentheses correctly" do
                lemma = Lemma.new
                result = lemma.send(:smart_split_sublemmas, "one,term((a,b),c),three")
                expect(result).to eq(["one", "term((a,b),c)", "three"])
            end
        end
        
        describe "parent-child relationship" do
            it "sets parent when creating from a string with sublemmas" do
                lemma = Lemma.new("work|work out,work on")
                
                lemma.sublemmas.each do |sublemma|
                    expect(sublemma.parent).to eq(lemma)
                end
            end
            
            it "sets parent when adding sublemmas programmatically" do
                lemma = Lemma.new
                lemma.text = "work"
                lemma.addSublemma("work out")
                lemma.addSublemmas(["work on", "work with"])
                
                lemma.sublemmas.each do |sublemma|
                    expect(sublemma.parent).to eq(lemma)
                end
            end
            
            it "sets parent when adding a redirection sublemma" do
                lemma = Lemma.new("work")
                lemma.addRedirect("activity", ["syn"])
                
                expect(lemma.sublemmas.first.parent).to eq(lemma)
            end
        end
        
        describe "#shortcuts" do
            it "returns an empty hash for redirection lemmas" do
                lemma = Lemma.new("children>>(pl)child")
                expect(lemma.shortcuts).to eq({})
            end
            
            it "returns an empty hash for lemmas without sublemmas" do
                lemma = Lemma.new("run[sp:ran,pp:run]")
                expect(lemma.shortcuts).to eq({})
            end
            
            it "returns shortcuts for all text sublemmas" do
                lemma = Lemma.new("work|work out,work on,finish work")
                shortcuts = lemma.shortcuts
                
                expect(shortcuts.size).to eq(3)
                expect(shortcuts["work out"]).to eq("~ out")
                expect(shortcuts["work on"]).to eq("~ on")
                expect(shortcuts["finish work"]).to eq("finish work")  # No shortcut, different prefix
            end
            
            it "skips redirection sublemmas" do
                lemma = Lemma.new("work|work out,>(rel)target")
                shortcuts = lemma.shortcuts
                
                expect(shortcuts.size).to eq(1)
                expect(shortcuts["work out"]).to eq("~ out")
            end
            
            it "uses the provided placeholder" do
                lemma = Lemma.new("look|look up,look down")
                shortcuts = lemma.shortcuts("*")
                
                expect(shortcuts["look up"]).to eq("* up")
                expect(shortcuts["look down"]).to eq("* down")
            end
        end
    end
    
    describe Sublemma do
        it "stores source location information" do
            sublemma = Sublemma.new("test", nil, nil, "test.lexm", 15, 20)
            expect(sublemma.source_file).to eq("test.lexm")
            expect(sublemma.source_line).to eq(15)
            expect(sublemma.source_column).to eq(20)
        end
        
        describe "#shortcut" do
            let(:parent_lemma) { LexM::Lemma.new("work") }
            
            it "returns nil when there is no parent" do
                sublemma = LexM::Sublemma.new("work out")
                expect(sublemma.shortcut).to be_nil
            end
            
            it "returns nil for redirection sublemmas" do
                redirect = LexM::LemmaRedirect.new("target", ["rel"])
                sublemma = LexM::Sublemma.new(nil, redirect, parent_lemma)
                expect(sublemma.shortcut).to be_nil
            end
            
            it "replaces the lemma with a tilde placeholder" do
                sublemma = LexM::Sublemma.new("work out", nil, parent_lemma)
                expect(sublemma.shortcut).to eq("~ out")
            end
            
            it "returns the full text when the sublemma doesn't start with the lemma" do
                sublemma = LexM::Sublemma.new("carefully work", nil, parent_lemma)
                expect(sublemma.shortcut).to eq("carefully work")
            end
            
            it "uses the provided placeholder instead of tilde" do
                sublemma = LexM::Sublemma.new("work out", nil, parent_lemma)
                expect(sublemma.shortcut("*")).to eq("* out")
            end
            
            it "doesn't create shortcuts for prefix matches that aren't separated by space" do
                sublemma = LexM::Sublemma.new("workout", nil, parent_lemma)
                expect(sublemma.shortcut).to eq("workout")
            end
            
            it "handles multi-word lemmas correctly" do
                multi_word_lemma = LexM::Lemma.new("get up")
                sublemma = LexM::Sublemma.new("get up early", nil, multi_word_lemma)
                expect(sublemma.shortcut).to eq("~ early")
            end
            
            it "handles exact matches correctly" do
                sublemma = LexM::Sublemma.new("work", nil, parent_lemma)
                expect(sublemma.shortcut).to eq("~")
            end
        end
        
        describe "parent reference" do
            it "is set when a sublemma is created with a parent" do
                lemma = LexM::Lemma.new("work")
                sublemma = LexM::Sublemma.new("work out", nil, lemma)
                
                expect(sublemma.parent).to eq(lemma)
            end
            
            it "is set when a sublemma is added to a lemma" do
                lemma = LexM::Lemma.new("work")
                lemma.addSublemma("work out")
                
                expect(lemma.sublemmas.first.parent).to eq(lemma)
            end
            
            it "is set when a lemma with sublemmas is created from a string" do
                lemma = LexM::Lemma.new("work|work out,work on")
                
                lemma.sublemmas.each do |sublemma|
                    expect(sublemma.parent).to eq(lemma)
                end
            end
        end
    end

    describe LemmaList do
        let(:list) { LemmaList.new }
        let(:lemma1) { Lemma.new("run[sp:ran,pp:run]") }
        let(:lemma2) { Lemma.new("children>>(pl)child") }

        describe "#addLemma" do
            it "adds a lemma to the list" do
                list.addLemma(lemma1)
                expect(list.size).to eq(1)
                expect(list[0]).to eq(lemma1)
            end
            
            context "with merging" do
                it "merges annotations when adding a lemma with the same headword" do
                    list.addLemma(Lemma.new("run[sp:ran]"))
                    list.addLemma(Lemma.new("run[pp:run]"))
                    
                    expect(list.size).to eq(1)
                    expect(list[0].annotations["sp"]).to eq("ran")
                    expect(list[0].annotations["pp"]).to eq("run")
                end
                
                it "merges sublemmas when adding a lemma with the same headword" do
                    list.addLemma(Lemma.new("run|run away"))
                    list.addLemma(Lemma.new("run|run through"))
                    
                    expect(list.size).to eq(1)
                    expect(list[0].sublemmas.size).to eq(2)
                    expect(list[0].sublemmas.map(&:text)).to include("run away", "run through")
                end
                
                it "doesn't add duplicate sublemmas" do
                    list.addLemma(Lemma.new("run|run away,run up"))
                    list.addLemma(Lemma.new("run|run away,run through"))
                    
                    expect(list.size).to eq(1)
                    expect(list[0].sublemmas.size).to eq(3)
                    expect(list[0].sublemmas.map(&:text)).to include("run away", "run up", "run through")
                end
                
                it "doesn't merge when merge parameter is false" do
                    list.addLemma(Lemma.new("run[sp:ran]"))
                    list.addLemma(Lemma.new("run[pp:run]"), false)
                    
                    expect(list.size).to eq(2)
                    expect(list[0].annotations["sp"]).to eq("ran")
                    expect(list[0].annotations["pp"]).to be_nil
                    expect(list[1].annotations["pp"]).to eq("run")
                    expect(list[1].annotations["sp"]).to be_nil
                end
            end
        end
        
        describe "#addLemmas" do
            it "adds multiple lemmas with merge support" do
                lemmas = [
                    Lemma.new("run[sp:ran]"),
                    Lemma.new("run[pp:run]|run away"),
                    Lemma.new("walk[sp:walked]")
                ]
                
                list.addLemmas(lemmas)
                
                expect(list.size).to eq(2) # run and walk
                expect(list.findByText("run").first.annotations.keys).to include("sp", "pp")
                expect(list.findByText("run").first.sublemmas.size).to eq(1)
            end
        end

        describe "#findByAnnotation" do
            it "finds lemmas with a specific annotation" do
                list.addLemma(lemma1)
                list.addLemma(lemma2)
                result = list.findByAnnotation("sp")
                expect(result.size).to eq(1)
                expect(result[0]).to eq(lemma1)
            end
        end

        describe "#findRedirectionsTo" do
            it "finds lemmas redirecting to a target" do
                list.addLemma(lemma1)
                list.addLemma(lemma2)
                result = list.findRedirectionsTo("child")
                expect(result.size).to eq(1)
                expect(result[0]).to eq(lemma2)
            end
        end

        describe "#allWords" do
            it "returns all words in the list" do
                list.addLemma(Lemma.new("run[sp:ran,pp:run]|run away"))
                words = list.allWords
                expect(words).to include("run")
                expect(words).to include("run away")
                expect(words.size).to eq(2)
            end
        end
        
        describe "#parseFile" do
            it "tracks source location information" do
                # Create a temporary file
                filename = "temp_test.lexm"
                File.open(filename, "w") do |file|
                    file.puts("run[sp:ran]|run away")
                end
                
                list = LemmaList.new(filename)
                
                # Test lemma location
                lemma = list[0]
                expect(lemma.source_file).to eq(filename)
                expect(lemma.source_line).to eq(1)
                
                # Test sublemma location
                sublemma = lemma.sublemmas.first
                expect(sublemma.source_file).to eq(filename)
                expect(sublemma.source_line).to eq(1)
                expect(sublemma.source_column).to be > 0
                
                # Clean up
                File.delete(filename)
            end
        end
        
        describe "#source_location_str" do
            it "formats source location information" do
                lemma = Lemma.new("test", "file.lexm", 10, 5)
                list = LemmaList.new
                
                location = list.send(:source_location_str, lemma)
                expect(location).to eq("file.lexm:10, col: 5")
            end
            
            it "handles missing location information" do
                lemma = Lemma.new("test")
                list = LemmaList.new
                
                location = list.send(:source_location_str, lemma)
                expect(location).to eq("unknown location")
            end
        end
        
        describe "#validateAll" do
            it "returns an empty array when there are no validation errors" do
                list.addLemma(Lemma.new("run[sp:ran,pp:run]"))
                list.addLemma(Lemma.new("walk[sp:walked]"))
                
                expect(list.validateAll).to be_empty
            end
            
            it "detects duplicate headwords" do
                list.addLemma(Lemma.new("run[sp:ran]"), false)
                list.addLemma(Lemma.new("run[pp:run]"), false)
                
                errors = list.validateAll
                expect(errors).not_to be_empty
                expect(errors.any? { |e| e.include?("Duplicate headword") }).to be true
            end
            
            it "detects words that are both headwords and sublemmas" do
                list.addLemma(Lemma.new("run|walk"))
                list.addLemma(Lemma.new("walk[sp:walked]"))
                
                errors = list.validateAll
                expect(errors).not_to be_empty
                expect(errors.any? { |e| e.include?("is both a headword") && e.include?("and a sublemma of") }).to be true
            end
            
            it "detects words that are both normal headwords and redirection headwords" do
                list.addLemma(Lemma.new("run[sp:ran]"), false)
                list.instance_variable_get(:@lemmas) << Lemma.new("run>>go")
                
                errors = list.validateAll
                expect(errors).not_to be_empty
                expect(errors.any? { |e| e.include?("is both a normal headword") && e.include?("and a redirection headword") }).to be true
            end
            
            it "detects all issues at once" do
                # Set up multiple validation issues
                list.addLemma(Lemma.new("worse|worst,>(cmp)bad"))
                list.addLemma(Lemma.new("worst>>(spl)bad"))
                list.addLemma(Lemma.new("aid|aide"))
                list.addLemma(Lemma.new("aide>>assistant"))
                
                errors = list.validateAll
                expect(errors.size).to be >= 2 # At least the two issues we know about
            end
            
            it "includes source location information in error messages" do
                # Create lemmas with source location
                lemma1 = Lemma.new("run|walk", "test.lexm", 5, 1)
                sublemma = lemma1.sublemmas.first
                sublemma.source_file = "test.lexm"
                sublemma.source_line = 5
                sublemma.source_column = 5
                
                lemma2 = Lemma.new("walk[sp:walked]", "test.lexm", 10, 1)
                
                list.addLemma(lemma1)
                list.addLemma(lemma2)
                
                errors = list.validateAll
                expect(errors).not_to be_empty
                
                # Check that source locations are included in error messages
                location_pattern = /test\.lexm:\d+/
                expect(errors.first).to match(location_pattern)
            end
        end
    end

    describe "Error handling" do
        describe Lemma do
            describe "#parse" do
                it "raises an error for empty input" do
                    expect { Lemma.new("") }.to raise_error(/Empty lemma input/)
                end
                
                it "raises an error for mismatched brackets" do
                    expect { Lemma.new("word[key:value") }.to raise_error(/mismatched brackets/)
                end
                
                it "raises an error for malformed redirection syntax" do
                    expect { Lemma.new("word>> ") }.to raise_error(/Malformed redirection syntax/)
                end
            end
            
            describe "#parseLemma" do
                it "raises an error for missing lemma text before annotations" do
                    lemma = Lemma.new
                    expect { lemma.send(:parseLemma, "[key:value]") }.to raise_error(/Missing lemma text/)
                end
            end
            
            describe "#parseAnnotations" do
                it "raises an error for empty annotation type" do
                    lemma = Lemma.new
                    expect { lemma.send(:parseAnnotations, ":value") }.to raise_error(/Empty annotation type/)
                end
                
                it "raises an error for empty annotation value" do
                    lemma = Lemma.new
                    expect { lemma.send(:parseAnnotations, "key:") }.to raise_error(/Empty annotation value/)
                end
            end
            
            describe "#validateAnnotation" do
                it "raises an error for invalid annotation keys" do
                    lemma = Lemma.new
                    expect { lemma.send(:validateAnnotation, "key with spaces", "value") }.to raise_error(/Invalid annotation key/)
                    expect { lemma.send(:validateAnnotation, "key-with-dashes", "value") }.to raise_error(/Invalid annotation key/)
                end
                
                it "raises an error for annotation values containing brackets" do
                    lemma = Lemma.new
                    expect { lemma.send(:validateAnnotation, "key", "value[with]brackets") }.to raise_error(/cannot contain square brackets/)
                end
            end
            
            describe "#setRedirect" do
                it "raises an error when setting redirect on a lemma with sublemmas" do
                    lemma = Lemma.new("word|sublemma")
                    expect { lemma.setRedirect("target") }.to raise_error(/Cannot set redirect on a lemma with sublemmas/)
                end
            end
        end
        
        describe LemmaList do
            describe "#parseFile" do
                it "raises an error for non-existent files" do
                    list = LemmaList.new
                    expect { list.parseFile("nonexistent_file.lexm") }.to raise_error(/File not found/)
                end
            end
            
            describe "#validateRedirections" do
                it "detects circular redirections" do
                    list = LemmaList.new
                    list.addLemma(Lemma.new("A>>(rel)B"))
                    list.addLemma(Lemma.new("B>>(rel)C"))
                    list.addLemma(Lemma.new("C>>(rel)A"))
                    
                    expect { list.validateRedirections }.to raise_error(/Circular redirection detected/)
                end
                
                it "passes validation with valid redirection chains" do
                    list = LemmaList.new
                    list.addLemma(Lemma.new("A>>(rel)B"))
                    list.addLemma(Lemma.new("B>>(rel)C"))
                    
                    expect(list.validateRedirections).to be true
                end
                
                it "includes source location in circular redirection errors" do
                    list = LemmaList.new
                    list.addLemma(Lemma.new("A>>(rel)B", "test.lexm", 1, 1))
                    list.addLemma(Lemma.new("B>>(rel)C", "test.lexm", 2, 1))
                    list.addLemma(Lemma.new("C>>(rel)A", "test.lexm", 3, 1))
                    
                    begin
                        list.validateRedirections
                        fail "Expected circular redirection error not raised"
                    rescue StandardError => e
                        expect(e.message).to include("test.lexm:1")
                        expect(e.message).to include("test.lexm:2")
                        expect(e.message).to include("test.lexm:3")
                    end
                end
            end
            
            describe "#validateSublemmaRelationships" do
                it "detects when a word is both a headword and a redirection headword" do
                    list = LemmaList.new
                    list.addLemma(Lemma.new("run[sp:ran]"), false)
                    list.instance_variable_get(:@lemmas) << Lemma.new("run>>go")
                    
                    # Update the regex to match the actual error message format
                    expect { list.validateSublemmaRelationships }.to raise_error(/is both a normal headword.*and a redirection headword/)
                end
                
                it "includes source location in validation errors" do
                    list = LemmaList.new
                    lemma1 = Lemma.new("run[sp:ran]", "test.lexm", 5, 1)
                    lemma2 = Lemma.new("run>>go", "test.lexm", 10, 1)
                    
                    list.addLemma(lemma1, false)
                    list.instance_variable_get(:@lemmas) << lemma2
                    
                    begin
                        list.validateSublemmaRelationships
                        fail "Expected validation error not raised"
                    rescue StandardError => e
                        expect(e.message).to include("test.lexm:5")
                        expect(e.message).to include("test.lexm:10")
                    end
                end
            end
            
            describe "#validateCircularDependencies" do
                it "includes source location in circular dependency errors" do
                    list = LemmaList.new
                    
                    # Create a circular dependency with source locations
                    lemma1 = Lemma.new("A|B", "test.lexm", 1, 1)
                    lemma1.sublemmas.first.source_file = "test.lexm"
                    lemma1.sublemmas.first.source_line = 1
                    lemma1.sublemmas.first.source_column = 3
                    
                    lemma2 = Lemma.new("B|A", "test.lexm", 2, 1)
                    lemma2.sublemmas.first.source_file = "test.lexm"
                    lemma2.sublemmas.first.source_line = 2
                    lemma2.sublemmas.first.source_column = 3
                    
                    list.addLemma(lemma1)
                    list.addLemma(lemma2)
                    
                    begin
                        list.validateCircularDependencies
                        fail "Expected circular dependency error not raised"
                    rescue StandardError => e
                        expect(e.message).to include("test.lexm:1")
                        expect(e.message).to include("test.lexm:2")
                    end
                end
            end
        end
    end
end