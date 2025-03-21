#############################################################
# LexM - Lemma Markup Format
#
# A specification for representing dictionary-ready,
# lexical entries and their relationships
#
# File: lib/lexm/lemma_list.rb
# (c) 2025 Yanis Zafirópulos (aka Dr.Kameleon)
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
            line_number = 0
            text.each_line do |line|
                line_number += 1
                line = line.strip
                next if line.empty? || line.start_with?('#')
                lemma = Lemma.new(line, "string input", line_number, 1)
                @lemmas << lemma
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
                            # Create lemma with source location info
                            lemma = Lemma.new(line, filename, line_number, 1)
                            @lemmas << lemma
                            
                            # Track sublemma positions
                            track_sublemma_positions(lemma, line, filename, line_number)
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

        # Track source positions for sublemmas
        # @param lemma [Lemma] The lemma containing sublemmas
        # @param line [String] The original line from the file
        # @param filename [String] Source filename
        # @param line_number [Integer] Source line number
        # @return [void]
        def track_sublemma_positions(lemma, line, filename, line_number)
            return if line.nil? || lemma.redirected? || !line.include?("|")
            
            # Find where sublemmas begin
            sublemmas_start = line.index("|") + 1
            
            # For each sublemma, try to find its position in the line
            lemma.sublemmas.each do |sublemma|
                sublemma.source_file = filename
                sublemma.source_line = line_number
                
                # Determine column position
                if sublemma.text
                    # Find position of this sublemma text in the line
                    text_pos = line.index(sublemma.text, sublemmas_start)
                    sublemma.source_column = text_pos ? text_pos + 1 : sublemmas_start
                elsif sublemma.redirect
                    # Find position of redirection marker
                    redirect_pos = line.index('>', sublemmas_start)
                    sublemma.source_column = redirect_pos ? redirect_pos + 1 : sublemmas_start
                end
            end
        end

        # Helper method to format source location
        # @param item [Object] Object with source location attributes
        # @return [String] Formatted source location
        def source_location_str(item)
            if item.source_file && item.source_line
                col_info = item.source_column ? ", col: #{item.source_column}" : ""
                "#{item.source_file}:#{item.source_line}#{col_info}"
            else
                "unknown location"
            end
        end

        # Check for circular redirection chains
        # For example, if A redirects to B, which redirects back to A
        # @return [Boolean] true if no circular redirections are found
        # @raise [StandardError] with cycle path if circular redirections are detected
        def validateRedirections
            # Build a redirection graph with locations
            redirection_map = {}
            location_map = {}
            
            @lemmas.each do |lemma|
                if lemma.redirected?
                    redirection_map[lemma.text] = lemma.redirect.target
                    location_map[lemma.text] = source_location_str(lemma)
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
                    # Format the cycle with locations
                    cycle_path = visited.map do |word|
                        loc = location_map[word] || "unknown location"
                        "#{word} (#{loc})"
                    end
                    
                    cycle_path << "#{current} (#{location_map[current]})"
                    raise "Circular redirection detected: #{cycle_path.join(' -> ')}"
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
                    location1 = source_location_str(headwords[lemma.text])
                    location2 = source_location_str(lemma)
                    raise "Duplicate headword detected: '#{lemma.text}' at #{location1} and #{location2}"
                end
                headwords[lemma.text] = lemma
            end
            
            true
        end

        # Ensures that words don't appear as both headwords and sublemmas,
        # and that the same sublemma doesn't appear under multiple headwords
        # @return [Boolean] true if no conflicts are found
        # @raise [StandardError] if conflicts are detected
        def validateSublemmaRelationships
            # Build word maps with source tracking
            normal_headwords = {}
            redirection_headwords = {}
            sublemmas_map = {}
            
            # First, capture all headwords and their sublemmas
            @lemmas.each do |lemma|
                if lemma.redirected?
                    redirection_headwords[lemma.text] = lemma
                else
                    normal_headwords[lemma.text] = lemma
                    
                    # Process sublemmas for non-redirecting lemmas
                    lemma.sublemmas.each do |sublemma|
                        # Skip redirecting sublemmas, we only care about actual sublemmas with text
                        next if sublemma.redirected?
                        
                        # Record which headword this sublemma belongs to
                        if sublemmas_map.key?(sublemma.text)
                            sublemmas_map[sublemma.text] << [lemma, sublemma]
                        else
                            sublemmas_map[sublemma.text] = [[lemma, sublemma]]
                        end
                    end
                end
            end
            
            # Check for words that are both normal headwords and redirection headwords
            normal_headwords.each do |word, lemma|
                if redirection_headwords.key?(word)
                    location1 = source_location_str(lemma)
                    location2 = source_location_str(redirection_headwords[word])
                    raise "Word '#{word}' is both a normal headword (#{location1}) and a redirection headword (#{location2})"
                end
            end
            
            # Check for words that are both headwords and sublemmas
            normal_headwords.each do |word, lemma|
                if sublemmas_map.key?(word)
                    location1 = source_location_str(lemma)
                    sublemma_info = sublemmas_map[word].map do |l, s|
                        "#{l.text} (#{source_location_str(s)})"
                    end.join(', ')
                    raise "Word '#{word}' is both a headword (#{location1}) and a sublemma of #{sublemma_info}"
                end
            end
            
            # Check for words that are both redirection headwords and sublemmas
            redirection_headwords.each do |word, lemma|
                if sublemmas_map.key?(word)
                    location1 = source_location_str(lemma)
                    sublemma_info = sublemmas_map[word].map do |l, s|
                        "#{l.text} (#{source_location_str(s)})"
                    end.join(', ')
                    raise "Word '#{word}' is both a redirection headword (#{location1}) and a sublemma of #{sublemma_info}"
                end
            end
            
            # Check for sublemmas that appear in multiple entries
            sublemmas_map.each do |sublemma, entries|
                if entries.size > 1
                    headword_info = entries.map do |l, s|
                        "#{l.text} (#{source_location_str(s)})"
                    end.join(', ')
                    raise "Sublemma '#{sublemma}' appears in multiple entries: #{headword_info}"
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
            # Build a graph of dependencies (headword -> sublemmas) with locations
            dependency_graph = {}
            location_map = {}
            
            @lemmas.each do |lemma|
                next if lemma.redirected?
                
                # Track lemma location
                location_map[lemma.text] = source_location_str(lemma)
                
                # Initialize headword in the graph if not present
                dependency_graph[lemma.text] ||= []
                
                # Add all non-redirecting sublemmas as dependencies
                lemma.sublemmas.each do |sublemma|
                    next if sublemma.redirected?
                    dependency_graph[lemma.text] << sublemma.text
                    location_map[sublemma.text] ||= source_location_str(sublemma)
                end
            end
            
            # For each headword, check for circular dependencies
            dependency_graph.each_key do |start|
                detectCycles(dependency_graph, start, [], [], location_map)
            end
            
            true
        end
        
        # Helper method for validateCircularDependencies
        # Recursively traverses the dependency graph to find cycles using DFS
        # @param graph [Hash] The dependency graph mapping lemmas to their sublemmas
        # @param start [String] The starting node for cycle detection
        # @param visited [Array] Nodes already visited in any path
        # @param path [Array] Nodes visited in the current path
        # @param location_map [Hash] Map of words to their source locations
        # @return [Boolean] True if no cycles are detected
        # @raise [StandardError] if a cycle is detected
        def detectCycles(graph, start, visited = [], path = [], location_map = {})
            # Mark the current node as visited and add to path
            visited << start
            path << start
            
            # Visit all neighbors
            if graph.key?(start)
                graph[start].each do |neighbor|
                    # Skip if neighbor is not a headword (not in graph)
                    next unless graph.key?(neighbor)
                    
                    if !visited.include?(neighbor)
                        detectCycles(graph, neighbor, visited, path, location_map)
                    elsif path.include?(neighbor)
                        # Cycle detected
                        cycle_start_index = path.index(neighbor)
                        cycle = path[cycle_start_index..-1] << neighbor
                        
                        # Format the cycle with source locations
                        cycle_with_locations = cycle.map do |word|
                            loc = location_map[word] || "unknown location"
                            "#{word} (#{loc})"
                        end
                        
                        raise "Circular dependency detected: #{cycle_with_locations.join(' -> ')}"
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
            
            # Create maps for tracking word usage with source locations
            normal_headwords = {}
            redirection_headwords = {}
            sublemmas_map = {}
            
            # First, map out all words and their locations
            @lemmas.each do |lemma|
                location = source_location_str(lemma)
                
                if lemma.redirected?
                    redirection_headwords[lemma.text] = location
                else
                    normal_headwords[lemma.text] = location
                    
                    # Process sublemmas for non-redirecting lemmas
                    lemma.sublemmas.each do |sublemma|
                        next if sublemma.redirected?
                        
                        sub_location = source_location_str(sublemma)
                        
                        # Record which headword this sublemma belongs to with location
                        if sublemmas_map.key?(sublemma.text)
                            sublemmas_map[sublemma.text] << [lemma.text, sub_location]
                        else
                            sublemmas_map[sublemma.text] = [[lemma.text, sub_location]]
                        end
                    end
                end
            end
            
            # Check for duplicate headwords with locations
            headword_locations = {}
            @lemmas.each do |lemma|
                location = source_location_str(lemma)
                if headword_locations.key?(lemma.text)
                    headword_locations[lemma.text] << location
                else
                    headword_locations[lemma.text] = [location]
                end
            end
            
            headword_locations.each do |word, locations|
                if locations.size > 1
                    errors << "Duplicate headword detected: '#{word}' at #{locations.join(' and ')}"
                end
            end
            
            # Check for words that are both normal headwords and redirection headwords
            normal_headwords.each do |word, location|
                if redirection_headwords.key?(word)
                    errors << "Word '#{word}' is both a normal headword (#{location}) and a redirection headword (#{redirection_headwords[word]})"
                end
            end
            
            # Check for words that are both headwords and sublemmas
            normal_headwords.each do |word, location|
                if sublemmas_map.key?(word)
                    sublemma_info = sublemmas_map[word].map { |h, l| "#{h} (#{l})" }.join(', ')
                    errors << "Word '#{word}' is both a headword (#{location}) and a sublemma of #{sublemma_info}"
                end
            end
            
            # Check for words that are both redirection headwords and sublemmas
            redirection_headwords.each do |word, location|
                if sublemmas_map.key?(word)
                    sublemma_info = sublemmas_map[word].map { |h, l| "#{h} (#{l})" }.join(', ')
                    errors << "Word '#{word}' is both a redirection headword (#{location}) and a sublemma of #{sublemma_info}"
                end
            end
            
            # Check for sublemmas that appear in multiple entries
            sublemmas_map.each do |sublemma, headword_list|
                if headword_list.size > 1
                    headword_info = headword_list.map { |h, l| "#{h} (#{l})" }.join(', ')
                    errors << "Sublemma '#{sublemma}' appears in multiple entries: #{headword_info}"
                end
            end
            
            # Check for circular dependencies and redirections if no errors so far
            if errors.empty?
                begin
                    validateCircularDependencies
                rescue StandardError => e
                    errors << e.message
                end
                
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