#############################################################
# LexM - Lemma Markup Format
#
# A specification for representing, dictionary-ready
# lexical entries and their relationships
#
# File: lib/lexm/lemma_list.rb
# Author: Yanis Zafirópulos (aka Dr.Kameleon)
#############################################################

module LexM
    # Represents a collection of lemmas
    class LemmaList
        # The array of lemmas
        attr_reader :lemmas
        
        # Initialize a new lemma list, optionally from a string or file
        # @param input [String, nil] input string or filename
        def initialize(input = nil)
            @lemmas = []
            
            if input.is_a?(String)
                # Assume it's a filename if it doesn't contain newlines
                if input.include?("\n")
                    parseString(input)
                else
                    parseFile(input)
                end
            end
        end
        
        # Iterate through all lemma lemmas
        # @yield [Lemma] each lemma in the list
        def each
            @lemmas.each do |lemma|
                yield lemma
            end
        end
        
        # Iterate through all words (both lemmas and sublemmas)
        # @yield [String] each word (lemma text or sublemma text)
        def eachWord
            @lemmas.each do |lemma|
                # Yield the main lemma text
                yield lemma.text if lemma.text
                
                # Yield all sublemma texts
                lemma.sublemmas.each do |sublemma|
                    yield sublemma.text if sublemma.text
                end
            end
        end
        
        # Get an array of all words (both lemmas and sublemmas)
        # @return [Array<String>] array of all words
        def allWords
            words = []
            eachWord { |word| words << word }
            words
        end
        
        # Parse a multi-line string
        # @param text [String] text to parse
        # @return [LemmaList] self
        def parseString(text)
            text.each_line do |line|
                line = line.strip
                next if line.empty? || line.start_with?('#')
                @lemmas << Lemma.new(line)
            end
            self
        end
        
        # Parse from a file
        # @param filename [String] file to parse
        # @return [LemmaList] self
        def parseFile(filename)
            File.open(filename, 'r') do |file|
                file.each_line do |line|
                    line = line.strip
                    next if line.empty? || line.start_with?('#')
                    @lemmas << Lemma.new(line)
                end
            end
            self
        end
        
        # Find lemmas by lemma text
        # @param text [String] lemma text to search for
        # @return [Array<Lemma>] matching lemmas
        def findByText(text)
            @lemmas.select { |lemma| lemma.text == text }
        end
        
        # Find normal lemmas (not redirection lemmas)
        # @return [Array<Lemma>] normal lemmas
        def normalLemmas
            @lemmas.select { |lemma| not lemma.redirected? }
        end
        
        # Find redirection lemmas
        # @return [Array<Lemma>] redirection lemmas
        def redirectedLemmas
            @lemmas.select { |lemma| lemma.redirected? }
        end
        
        # Find lemmas that redirect to a given target, optionally filtered by type
        # @param target [String] target to search for
        # @param type [String, nil] optional relation type filter
        # @return [Array<Lemma>] matching lemmas
        def findRedirectionsTo(target, type = nil)
            @lemmas.select do |lemma|
                if lemma.redirected? && lemma.redirect.target == target
                    type.nil? || lemma.redirect.types.include?(type)
                else
                    lemma.sublemmas.any? do |sublemma|
                        sublemma.redirected? && 
                        sublemma.redirect.target == target && 
                        (type.nil? || sublemma.redirect.types.include?(type))
                    end
                end
            end
        end
        
        # Find lemmas by annotation
        # @param type [String] annotation type
        # @param value [Object, nil] optional value to match
        # @return [Array<Lemma>] matching lemmas
        def findByAnnotation(type, value = nil)
            @lemmas.select do |lemma|
                if value.nil?
                    lemma.annotations.key?(type)
                else
                    lemma.annotations[type] == value
                end
            end
        end
        
        # Add a new lemma
        # @param lemma [Lemma] lemma to add
        # @return [LemmaList] self
        def addLemma(lemma)
            @lemmas << lemma
            self
        end
        
        # Add multiple lemmas at once
        # @param lemmas [Array<Lemma>] lemmas to add
        # @return [LemmaList] self
        def addLemmas(lemmas)
            @lemmas.concat(lemmas)
            self
        end
        
        # Remove a lemma
        # @param lemma [Lemma] lemma to remove
        # @return [LemmaList] self
        def removeLemma(lemma)
            @lemmas.delete(lemma)
            self
        end
        
        # Clear all lemmas
        # @return [LemmaList] self
        def clear
            @lemmas = []
            self
        end
        
        # Get number of lemmas
        # @return [Integer] number of lemmas
        def size
            @lemmas.size
        end
        
        # Get lemma by index
        # @param index [Integer] index
        # @return [Lemma] lemma at index
        def [](index)
            @lemmas[index]
        end
        
        # Save to a file
        # @param filename [String] file to save to
        # @return [void]
        def save(filename)
            File.open(filename, 'w') do |file|
                @lemmas.each do |lemma|
                    file.puts(lemma.to_s)
                end
            end
        end
        
        # Convert to string
        # @return [String] string representation
        def to_s
            @lemmas.map(&:to_s).join("\n")
        end
    end
end