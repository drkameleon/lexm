#############################################################
# LexM - Lemma Markup Format
#
# A specification for representing dictionary-ready,
# lexical entries and their relationships
#
# File: spec/lexm_spec.rb
# Author: Yanis Zafirópulos (aka Dr.Kameleon)
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
    end
    
    describe Sublemma do
        it "stores source location information" do
            sublemma = Sublemma.new("test", nil, "test.lexm", 15, 20)
            expect(sublemma.source_file).to eq("test.lexm")
            expect(sublemma.source_line).to eq(15)
            expect(sublemma.source_column).to eq(20)
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
                expect(errors.any? { |e| e.include?("both a headword and a sublemma") }).to be true
            end
            
            it "detects words that are both normal headwords and redirection headwords" do
                list.addLemma(Lemma.new("run[sp:ran]"), false)
                list.instance_variable_get(:@lemmas) << Lemma.new("run>>go")
                
                errors = list.validateAll
                expect(errors).not_to be_empty
                expect(errors.any? { |e| e.include?("both a normal headword and a redirection headword") }).to be true
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
                    
                    expect { list.validateSublemmaRelationships }.to raise_error(/both a normal headword and a redirection headword/)
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