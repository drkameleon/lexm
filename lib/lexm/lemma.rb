#############################################################
# LexM - Lemma Markup Format
#
# A specification for representing dictionary-ready,
# lexical entries and their relationships
#
# File: lib/lexm/lemma.rb
# Author: Yanis Zafirópulos (aka Dr.Kameleon)
#############################################################

module LexM
    # Represents a lemma, the main entry in a lexicon
    class Lemma
        attr_accessor :text, :annotations, :sublemmas, :redirect
        # Source location information
        attr_accessor :source_file, :source_line, :source_column

        # Initialize from either a string or direct components
        # @param input [String, nil] input string in LexM format to parse
        # @param source_file [String, nil] source file path
        # @param source_line [Integer, nil] source line number
        # @param source_column [Integer, nil] source column number
        def initialize(input = nil, source_file = nil, source_line = nil, source_column = nil)
            @text = nil
            @annotations = {}
            @sublemmas = []
            @redirect = nil
            @source_file = source_file
            @source_line = source_line
            @source_column = source_column
            
            parse(input) if input.is_a?(String)
        end
        
        # Parse a lemma string
        # @param input [String] lemma string in LexM format
        # @return [Lemma] self
        def parse(input)
            # Check for empty input
            raise "Empty lemma input!" if input.nil? || input.strip.empty?
            
            # Check for basic syntax issues
            if input.count('[') != input.count(']')
                raise "Malformed input: mismatched brackets in '#{input}'"
            end
            
            # Check for balanced pipes
            if input.include?("|") && input.start_with?("|")
                raise "Malformed input: lemma starts with pipe character in '#{input}'"
            end
          
            if input.include?(">>")
                parseRedirectionLemma(input)
                return self
            end
          
            lemmaPart, sublemmasPart = input.split('|', 2)
          
            parseLemma(lemmaPart)
            parseSublemmas(sublemmasPart) if sublemmasPart
          
            self
        end

        # Parse a redirection lemma (with >> syntax)
        # @param input [String] redirection lemma string
        # @return [void]
        def parseRedirectionLemma(input)
            # Check for valid redirection syntax (needs a target after >>)
            if input.match(/>>[\s]*$/)
                raise "Malformed redirection syntax in '#{input}'. Should be 'word>>target' or 'word>>(relation)target'"
            end
            
            if input =~ /(.+?)>>\((.+?)\)(.+)/
                @text = $1.strip
                @redirect = LemmaRedirect.new($3.strip, $2.split(',').map(&:strip))
            elsif input =~ /(.+?)>>(.+)/
                @text = $1.strip
                target = $2.strip
                if target.empty?
                    raise "Malformed redirection syntax in '#{input}'. Missing target after '>>'"
                end
                @redirect = LemmaRedirect.new(target)
            else
                raise "Malformed redirection syntax in '#{input}'. Should be 'word>>target' or 'word>>(relation)target'"
            end
        end
        
        # Parse just the lemma part (before any pipe)
        # @param lemmaPart [String] lemma part string
        # @return [void]
        def parseLemma(lemmaPart)
            if lemmaPart.include?('[')
                baseLemma, annotationsPart = lemmaPart.split('[', 2)
              
                # Check for malformed annotation syntax
                raise "Malformed annotation: missing closing ']' in '#{lemmaPart}'" unless annotationsPart.end_with?(']')
              
                # Ensure there's actual lemma text before annotations
                if baseLemma.strip.empty?
                    raise "Missing lemma text before annotations in '#{lemmaPart}'"
                end
              
                @text = baseLemma.strip
          
                annotationsPart.sub!(/\]$/, '')
                parseAnnotations(annotationsPart)
            else
                # Simple lemma
                # Ensure there's actual text
                if lemmaPart.strip.empty?
                    raise "Empty lemma text in '#{lemmaPart}'"
                end
                @text = lemmaPart.strip
            end
        end
        
        # Parse sublemmas part (after the pipe)
        # @param sublemmasPart [String] sublemmas part string
        # @return [void]
        def parseSublemmas(sublemmasPart)
            # Check if the sublemma part starts with a redirection marker
            if sublemmasPart.start_with?('>')
                # This is a case where the lemma has a pure redirection sublemma
                # Format: word|>(relation)target
                if sublemmasPart =~ />\((.+?)\)(.+)/
                    redirect = LemmaRedirect.new($2.strip, $1.split(',').map(&:strip))
                    @sublemmas << Sublemma.new(nil, redirect)
                elsif sublemmasPart =~ />(.+)/
                    redirect = LemmaRedirect.new($1.strip)
                    @sublemmas << Sublemma.new(nil, redirect)
                end
            else
                # Split the sublemmas and process each one
                sublemmas = sublemmasPart.split(',')
                
                # Process normal sublemmas
                sublemmas.each do |sublemma|
                    sublemma = sublemma.strip
                    
                    # Handle pure redirection sublemma
                    if sublemma.start_with?('>')
                        if sublemma =~ />\((.+?)\)(.+)/
                            redirect = LemmaRedirect.new($2.strip, $1.split(',').map(&:strip))
                            @sublemmas << Sublemma.new(nil, redirect)
                        elsif sublemma =~ />(.+)/
                            redirect = LemmaRedirect.new($1.strip)
                            @sublemmas << Sublemma.new(nil, redirect)
                        end
                    # Handle normal sublemma with possible redirection
                    elsif sublemma.include?('>')
                        if sublemma =~ /(.+?)>\((.+?)\)(.+)/
                            # Format: word>(relation)target
                            text = $1.strip
                            redirect = LemmaRedirect.new($3.strip, $2.split(',').map(&:strip))
                            @sublemmas << Sublemma.new(text, redirect)
                        elsif sublemma =~ /(.+?)>(.+)/
                            # Simple redirection without relation type
                            text = $1.strip
                            redirect = LemmaRedirect.new($2.strip)
                            @sublemmas << Sublemma.new(text, redirect)
                        else
                            @sublemmas << Sublemma.new(sublemma)
                        end
                    else
                        # Simple sublemma
                        @sublemmas << Sublemma.new(sublemma)
                    end
                end
            end
        end
        
        # Parse annotations like sp:past,pp:participle or pl:oxen
        # @param annotationsText [String] annotations string
        # @return [void]
        def parseAnnotations(annotationsText)
            if annotationsText.strip.empty?
                raise "Empty annotations block"
            end
            
            annotationsText.split(',').each do |annotation|
                if annotation.strip.empty?
                    raise "Empty annotation in comma-separated list"
                end
              
                if annotation.include?(':')
                    type, value = annotation.split(':', 2)
                
                    # Validate annotation type
                    if type.strip.empty?
                        raise "Empty annotation type in '#{annotation}'"
                    end
                
                    # Validate annotation value
                    if value.strip.empty?
                        raise "Empty annotation value for type '#{type.strip}'"
                    end
                
                    @annotations[type.strip] = value.strip
                else
                    # Handle simple annotations without values
                    if annotation.strip.empty?
                        raise "Empty annotation name"
                    end
                
                    @annotations[annotation.strip] = true
                end
            end
        end
        
        # Add a standard sublemma
        # @param text [String] text of the sublemma
        # @return [Lemma] self
        def addSublemma(text)
            if redirected?
                raise "Cannot add sublemmas to a redirection lemma"
            end
            @sublemmas << Sublemma.new(text)
            self
        end
        
        # Add multiple sublemmas at once
        # @param texts [Array<String>] array of sublemma texts
        # @return [Lemma] self
        def addSublemmas(texts)
            if redirected?
                raise "Cannot add sublemmas to a redirection lemma"
            end
            texts.each do |text|
                @sublemmas << Sublemma.new(text)
            end
            self
        end
        
        # Add a pure redirect sublemma
        # @param target [String] target to redirect to
        # @param types [Array<String>] relation types
        # @return [Lemma] self
        def addRedirect(target, types = [])
            if redirected?
                raise "Cannot add sublemmas to a redirection lemma"
            end
            redirect = LemmaRedirect.new(target, types)
            @sublemmas << Sublemma.new(nil, redirect)
            self
        end
        
        # Set the lemma's redirection
        # @param target [String] target to redirect to
        # @param types [Array<String>] relation types
        # @return [Lemma] self
        def setRedirect(target, types = [])
            if !@sublemmas.empty?
                raise "Cannot set redirect on a lemma with sublemmas"
            end
            @redirect = LemmaRedirect.new(target, types)
            self
        end

        # Validate annotation key and value format
        # Ensures keys and values follow the expected format
        # @param key [String] annotation key to validate
        # @param value [String, Boolean] annotation value to validate
        # @return [Boolean] true if validation passes
        # @raise [StandardError] with detailed message if validation fails
        def validateAnnotation(key, value)
            # Check that key matches a valid pattern (alphanumeric and limited symbols)
            unless key =~ /^[a-zA-Z0-9_]+$/
                raise "Invalid annotation key: '#{key}' (must contain only letters, numbers, and underscores)"
            end
            
            # Additional validation for values
            if value.is_a?(String)
                # Check for invalid characters in value if needed
                if value.include?(']') || value.include?('[')
                    raise "Invalid annotation value for '#{key}': cannot contain square brackets"
                end
            end
        end
        
        # Set an annotation
        # @param type [String] annotation type
        # @param value [Object] annotation value
        # @return [Lemma] self
        def setAnnotation(type, value = true)
            if redirected?
                raise "Cannot add annotations to a redirection lemma"
            end
            validateAnnotation(type, value)
            @annotations[type] = value
            self
        end
        
        # Add multiple annotations at once
        # @param annotations [Hash] hash of annotation type => value pairs
        # @return [Lemma] self
        def setAnnotations(annotations)
            if redirected?
                raise "Cannot add annotations to a redirection lemma"
            end
            annotations.each do |key, value|
                @annotations[key] = value
            end
            self
        end
        
        # Clear all annotations
        # @return [Lemma] self
        def clearAnnotations
            @annotations = {}
            self
        end
        
        # Clear all sublemmas
        # @return [Lemma] self
        def clearSublemmas
            @sublemmas = []
            self
        end
        
        # Clear redirect
        # @return [Lemma] self
        def clearRedirect
            @redirect = nil
            self
        end
        
        # Clear all annotations and sublemmas but keep the main lemma
        # @return [Lemma] self
        def clear
            @annotations = {}
            @sublemmas = []
            @redirect = nil
            self
        end
        
        # Clear everything including the main lemma
        # @return [Lemma] self
        def clearAll
            @text = nil
            @annotations = {}
            @sublemmas = []
            @redirect = nil
            self
        end
        
        # Is this a redirection lemma (no sublemmas, just a redirect)?
        # @return [Boolean] true if this is a redirection lemma
        def redirected?
            !@redirect.nil? && @sublemmas.empty?
        end
        
        # Convert to string format
        # @return [String] the string representation of this lemma
        def to_s
            # Redirection lemma format (with double >>)
            if redirected?
                return "#{@text}>>#{@redirect.to_s.sub('>', '')}"
            end
            
            # Normal lemma format
            result = ""
            
            # Format the lemma part with any annotations
            if @text.nil?
                return ""
            elsif @annotations.empty?
                result << @text
            else
                annotationsStr = @annotations.map do |type, value| 
                    value == true ? type : "#{type}:#{value}"
                end.join(',')
                result << "#{@text}[#{annotationsStr}]"
            end
            
            # Add sublemmas if present
            if !@sublemmas.empty?
                result << "|"
                result << @sublemmas.map(&:to_s).join(',')
            end
            
            result
        end
    end
end