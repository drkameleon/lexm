#############################################################
# LexM - Lemma Markup Format
#
# A specification for representing, dictionary-ready
# lexical entries and their relationships
#
# File: lib/lexm/lemma.rb
# Author: Yanis Zafirópulos (aka Dr.Kameleon)
#############################################################

module LexM
    # Represents a lemma, the main entry in a lexicon
    class Lemma
        attr_accessor :text, :annotations, :sublemmas, :redirect

        # Initialize from either a string or direct components
        # @param input [String, nil] input string in LexM format to parse
        def initialize(input = nil)
            @text = nil
            @annotations = {}
            @sublemmas = []
            @redirect = nil
            
            parse(input) if input.is_a?(String)
        end
        
        # Parse a lemma string
        # @param input [String] lemma string in LexM format
        # @return [Lemma] self
        def parse(input)
            raise "Empty lemma input!" if input.strip.empty?

            # Special case: redirection lemma (with >> syntax)
            if input.include?(">>")
                parseRedirectionLemma(input)
                return self
            end
            
            # Standard case with possible lemma, sublemmas
            lemmaPart, sublemmasPart = input.split('|', 2)
            
            parseLemma(lemmaPart)
            parseSublemmas(sublemmasPart) if sublemmasPart
            
            self
        end

        # Parse a redirection lemma (with >> syntax)
        # @param input [String] redirection lemma string
        # @return [void]
        def parseRedirectionLemma(input)
            if input =~ /(.+?)>>\((.+?)\)(.+)/
                # Format: word>>(relation)target
                @text = $1.strip
                @redirect = LemmaRedirect.new($3.strip, $2.split(',').map(&:strip))
            elsif input =~ /(.+?)>>(.+)/
                # Simple redirection without relation type
                @text = $1.strip
                @redirect = LemmaRedirect.new($2.strip)
            end
        end
        
        # Parse just the lemma part (before any pipe)
        # @param lemmaPart [String] lemma part string
        # @return [void]
        def parseLemma(lemmaPart)
            if lemmaPart.include?('[')
                # Handle annotations in the lemma
                baseLemma, annotationsPart = lemmaPart.split('[', 2)
                raise "Malformed annotation: missing closing ']'" unless annotationsPart.end_with?(']')
                @text = baseLemma.strip
                
                # Extract annotations from the bracket part
                annotationsPart.sub!(/\]$/, '')
                parseAnnotations(annotationsPart)
            else
                # Simple lemma
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
            annotationsText.split(',').each do |annotation|
                if annotation.include?(':')
                    type, value = annotation.split(':', 2)
                    @annotations[type.strip] = value.strip
                else
                    # Handle simple annotations without values
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
        
        # Set an annotation
        # @param type [String] annotation type
        # @param value [Object] annotation value
        # @return [Lemma] self
        def setAnnotation(type, value = true)
            if redirected?
                raise "Cannot add annotations to a redirection lemma"
            end
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