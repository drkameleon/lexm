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
            begin
                line_number = 0
                File.open(filename, 'r') do |file|
                    file.each_line do |line|
                        line_number += 1
                        line = line.strip
                        next if line.empty? || line.start_with?('#')
                  
                        begin
                            @lemmas << Lemma.new(line)
                        rescue StandardError => e
                            raise "Error on line #{line_number}: #{e.message} (#{line})"
                        end
                    end
                end
            rescue Errno::ENOENT
                raise "File not found: #{filename}"
            rescue Errno::EACCES
                raise "Permission denied: #{filename}"
            rescue StandardError => e
                raise "Error reading file: #{e.message}"
            end
            self
        end

        # Check for circular redirection chains
        # For example, if A redirects to B, which redirects back to A
        # @return [Boolean] true if no circular redirections are found
        # @raise [StandardError] with cycle path if circular redirections are detected
        def validateRedirections
            # Build a redirection graph
            redirection_map = {}
            
            @lemmas.each do |lemma|
                if lemma.redirected?
                    redirection_map[lemma.text] = lemma.redirect.target
                end
            end
            
            # Check for cycles
            redirection_map.each_key do |start|
                visited = []
                current = start
              
                while redirection_map.key?(current) && !visited.include?(current)
                    visited << current
                    current = redirection_map[current]
                end
              
                if redirection_map.key?(current) && current == start
                    cycle_path = visited.join(" -> ") + " -> " + current
                    raise "Circular redirection detected: #{cycle_path}"
                end
            end
            
            true
        end

        def validateHeadwords
            # Check for duplicate headwords
            headwords = {}
            
            @lemmas.each do |lemma|
                if headwords.key?(lemma.text)
                    raise "Duplicate headword detected: '#{lemma.text}'"
                end
                headwords[lemma.text] = true
            end
            
            true
        end

        def validateSublemmaRelationships
            # Build word maps
            headwords = {}
            sublemmas_map = {}
            
            # First, capture all headwords and their sublemmas
            @lemmas.each do |lemma|
                # Skip redirection lemmas since they don't have sublemmas
                next if lemma.redirected?
                
                headwords[lemma.text] = true
                
                lemma.sublemmas.each do |sublemma|
                    # Skip redirecting sublemmas, we only care about actual sublemmas with text
                    next if sublemma.redirected?
                    
                    # Record which headword this sublemma belongs to
                    if sublemmas_map.key?(sublemma.text)
                        sublemmas_map[sublemma.text] << lemma.text
                    else
                        sublemmas_map[sublemma.text] = [lemma.text]
                    end
                end
            end
            
            # Check for words that are both headwords and sublemmas
            headwords.keys.each do |word|
                if sublemmas_map.key?(word)
                    raise "Word '#{word}' is both a headword and a sublemma of '#{sublemmas_map[word].join(', ')}'"
                end
            end
            
            # Check for sublemmas that appear in multiple entries
            sublemmas_map.each do |sublemma, headword_list|
                if headword_list.size > 1
                    raise "Sublemma '#{sublemma}' appears in multiple entries: #{headword_list.join(', ')}"
                end
            end
            
            true
        end

        def validateCircularDependencies
            # Build a graph of dependencies (headword -> sublemmas)
            dependency_graph = {}
            
            @lemmas.each do |lemma|
                next if lemma.redirected?
                
                # Initialize headword in the graph if not present
                dependency_graph[lemma.text] ||= []
                
                # Add all non-redirecting sublemmas as dependencies
                lemma.sublemmas.each do |sublemma|
                    next if sublemma.redirected?
                    dependency_graph[lemma.text] << sublemma.text
                end
            end
            
            # For each headword, check for circular dependencies
            dependency_graph.each_key do |start|
                detectCycles(dependency_graph, start)
            end
            
            true
        end
        
        def detectCycles(graph, start, visited = [], path = [])
            # Mark the current node as visited and add to path
            visited << start
            path << start
            
            # Visit all neighbors
            if graph.key?(start)
                graph[start].each do |neighbor|
                    # Skip if neighbor is not a headword (not in graph)
                    next unless graph.key?(neighbor)
                    
                    if !visited.include?(neighbor)
                        detectCycles(graph, neighbor, visited, path)
                    elsif path.include?(neighbor)
                        # Cycle detected
                        cycle_start_index = path.index(neighbor)
                        cycle = path[cycle_start_index..-1] << neighbor
                        raise "Circular dependency detected: #{cycle.join(' -> ')}"
                    end
                end
            end
            
            # Remove the current node from path
            path.pop
            true
        end

        # Validate the entire lemma list for consistency
        # Runs all validation checks
        # @return [Boolean] true if validation passes
        # @raise [StandardError] with detailed message if validation fails
        def validate
            begin
                validateHeadwords
                validateSublemmaRelationships
                validateCircularDependencies
                validateRedirections
                return true
            rescue StandardError => e
                puts "Validation error: #{e.message}"
                return false
            end
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
            begin
                File.open(filename, 'w') do |file|
                    @lemmas.each do |lemma|
                        file.puts(lemma.to_s)
                    end
                end
            rescue Errno::EACCES
                raise "Permission denied: Cannot write to #{filename}"
            rescue StandardError => e
                raise "Error writing to file: #{e.message}"
            end
        end
        
        # Convert to string
        # @return [String] string representation
        def to_s
            @lemmas.map(&:to_s).join("\n")
        end
    end
end