#############################################################
# LexM - Lemma Markup Format
#
# A specification for representing, dictionary-ready
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
            end
        end
    end
end