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

        # Ensures no headword appears more than once in the list
        # This prevents ambiguity and conflicts in the dictionary
        # @return [Boolean] true if no duplicate headwords are found
        # @raise [StandardError] if duplicate headwords are detected
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

        # Ensures that words don't appear as both headwords and sublemmas,
        # and that the same sublemma doesn't appear under multiple headwords
        # @return [Boolean] true if no conflicts are found
        # @raise [StandardError] if conflicts are detected
        def validateSublemmaRelationships
            # Build word maps
            normal_headwords = {}
            redirection_headwords = {}
            sublemmas_map = {}
            
            # First, capture all headwords and their sublemmas
            @lemmas.each do |lemma|
                if lemma.redirected?
                    redirection_headwords[lemma.text] = true
                else
                    normal_headwords[lemma.text] = true
                    
                    # Process sublemmas for non-redirecting lemmas
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
            end
            
            # Check for words that are both normal headwords and redirection headwords
            normal_headwords.keys.each do |word|
                if redirection_headwords.key?(word)
                    raise "Word '#{word}' is both a normal headword and a redirection headword"
                end
            end
            
            # Check for words that are both headwords and sublemmas
            normal_headwords.keys.each do |word|
                if sublemmas_map.key?(word)
                    raise "Word '#{word}' is both a headword and a sublemma of '#{sublemmas_map[word].join(', ')}'"
                end
            end
            
            # Check for words that are both redirection headwords and sublemmas
            redirection_headwords.keys.each do |word|
                if sublemmas_map.key?(word)
                    raise "Word '#{word}' is both a redirection headword and a sublemma of '#{sublemmas_map[word].join(', ')}'"
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

        # Detects circular dependencies between lemmas and sublemmas
        # A circular dependency would result in infinite recursion when
        # expanding or processing the lemma structure
        # @return [Boolean] true if no circular dependencies are found
        # @raise [StandardError] if circular dependencies are detected
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
        
        # Helper method for validateCircularDependencies
        # Recursively traverses the dependency graph to find cycles using DFS
        # @param graph [Hash] The dependency graph mapping lemmas to their sublemmas
        # @param start [String] The starting node for cycle detection
        # @param visited [Array] Nodes already visited in any path
        # @param path [Array] Nodes visited in the current path
        # @return [Boolean] True if no cycles are detected
        # @raise [StandardError] if a cycle is detected
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
        
        # Performs all validation checks and returns an array of all errors
        # instead of raising on the first error encountered
        # @return [Array<String>] List of validation errors or empty array if valid
        def validateAll
            errors = []
            
            # Create maps for tracking word usage
            normal_headwords = {}
            redirection_headwords = {}
            sublemmas_map = {}
            
            # First, map out all words and their locations
            @lemmas.each do |lemma|
                if lemma.redirected?
                    redirection_headwords[lemma.text] = true
                else
                    normal_headwords[lemma.text] = true
                    
                    # Process sublemmas for non-redirecting lemmas
                    lemma.sublemmas.each do |sublemma|
                        next if sublemma.redirected?
                        
                        # Record which headword this sublemma belongs to
                        if sublemmas_map.key?(sublemma.text)
                            sublemmas_map[sublemma.text] << lemma.text
                        else
                            sublemmas_map[sublemma.text] = [lemma.text]
                        end
                    end
                end
            end
            
            # Check for duplicate headwords
            headword_counts = {}
            @lemmas.each do |lemma|
                headword_counts[lemma.text] ||= 0
                headword_counts[lemma.text] += 1
            end
            
            headword_counts.each do |word, count|
                if count > 1
                    errors << "Duplicate headword detected: '#{word}'"
                end
            end
            
            # Check for words that are both normal headwords and redirection headwords
            normal_headwords.keys.each do |word|
                if redirection_headwords.key?(word)
                    errors << "Word '#{word}' is both a normal headword and a redirection headword"
                end
            end
            
            # Check for words that are both headwords and sublemmas
            normal_headwords.keys.each do |word|
                if sublemmas_map.key?(word)
                    errors << "Word '#{word}' is both a headword and a sublemma of '#{sublemmas_map[word].join(', ')}'"
                end
            end
            
            # Check for words that are both redirection headwords and sublemmas
            redirection_headwords.keys.each do |word|
                if sublemmas_map.key?(word)
                    errors << "Word '#{word}' is both a redirection headword and a sublemma of '#{sublemmas_map[word].join(', ')}'"
                end
            end
            
            # Check for sublemmas that appear in multiple entries
            sublemmas_map.each do |sublemma, headword_list|
                if headword_list.size > 1
                    errors << "Sublemma '#{sublemma}' appears in multiple entries: #{headword_list.join(', ')}"
                end
            end
            
            # Perform additional checks only if no errors so far
            if errors.empty?
                # Check for circular dependencies
                begin
                    validateCircularDependencies
                rescue StandardError => e
                    errors << e.message
                end
                
                # Check for circular redirections
                begin
                    validateRedirections
                rescue StandardError => e
                    errors << e.message
                end
            end
            
            errors
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
        
        # Adds a lemma to the list
        # If a lemma with the same headword already exists, it will merge the
        # annotations and sublemmas from the new lemma into the existing one
        # @param lemma [Lemma] The lemma to add
        # @param merge [Boolean] Whether to merge with existing lemmas (default: true)
        # @return [LemmaList] self for method chaining
        def addLemma(lemma, merge = true)
            # Find existing lemma with the same headword
            existing = findByText(lemma.text).first
            
            if existing && merge
                # Merge annotations
                lemma.annotations.each do |key, value|
                    existing.setAnnotation(key, value)
                end
                
                # Merge sublemmas
                lemma.sublemmas.each do |sublemma|
                    # Check if this sublemma already exists
                    sublemma_exists = existing.sublemmas.any? do |existing_sublemma|
                        existing_sublemma.text == sublemma.text &&
                        (!existing_sublemma.redirected? && !sublemma.redirected?)
                    end
                    
                    # Add the sublemma if it doesn't exist
                    unless sublemma_exists
                        existing.sublemmas << sublemma
                    end
                end
            else
                # Add as new lemma
                @lemmas << lemma
            end
            
            self
        end
        
        # Add multiple lemmas at once
        # @param lemmas [Array<Lemma>] lemmas to add
        # @param merge [Boolean] Whether to merge with existing lemmas (default: true)
        # @return [LemmaList] self
        def addLemmas(lemmas, merge = true)
            lemmas.each do |lemma|
                addLemma(lemma, merge)
            end
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