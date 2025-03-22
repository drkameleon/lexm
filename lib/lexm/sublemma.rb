#############################################################
# LexM - Lemma Markup Format
#
# A specification for representing dictionary-ready,
# lexical entries and their relationships
#
# File: lib/lexm/sublemma.rb
# (c) 2025 Yanis Zafirópulos (aka Dr.Kameleon)
#############################################################

module LexM
    # Represents a sublemma, which can be either a textual sublemma or a redirection
    class Sublemma
        attr_accessor :text, :redirect
        # Source location information
        attr_accessor :source_file, :source_line, :source_column
        # Reference to parent lemma
        attr_accessor :parent
        
        # Initialize a new sublemma
        # @param text [String, nil] the text of the sublemma (nil for pure redirections)
        # @param redirect [LemmaRedirect, nil] redirection information (nil for normal sublemmas)
        # @param parent [Lemma, nil] parent lemma (optional)
        # @param source_file [String, nil] source file path
        # @param source_line [Integer, nil] source line number
        # @param source_column [Integer, nil] source column number
        def initialize(text = nil, redirect = nil, parent = nil, source_file = nil, source_line = nil, source_column = nil)
            @text = text
            @redirect = redirect
            @parent = parent
            @source_file = source_file
            @source_line = source_line
            @source_column = source_column
        end
        
        # Is this a pure redirection sublemma?
        # @return [Boolean] true if this is a pure redirection with no text
        def redirected?
            @text.nil? && !@redirect.nil?
        end
        
        # Returns a shortened version of the sublemma text, replacing the lemma part with a placeholder
        # For example, if the lemma is "work" and sublemma is "work out", this returns "~ out"
        # @param placeholder [String] optional placeholder to use instead of "~" (default: "~")
        # @return [String, nil] the shortened sublemma text or nil if this is a redirection sublemma or has no parent
        def shortcut(placeholder = "~")
            return nil if redirected? || @text.nil? || @parent.nil? || @parent.text.nil?
            
            parent_text = @parent.text
            
            # Check if the sublemma starts with the parent lemma
            if @text.start_with?(parent_text)
                # Replace the parent lemma with the placeholder
                remainder = @text[parent_text.length..-1]
                
                # If the remainder starts with a space, keep it
                if remainder.start_with?(" ")
                    return "#{placeholder}#{remainder}"
                elsif remainder.empty?
                    # For exact matches, just return the placeholder
                    return placeholder
                else
                    # For cases where the lemma is a prefix but not a whole word
                    # (e.g., lemma "over", sublemma "overdo") - don't create a shortcut
                    return @text
                end
            else
                # If the sublemma doesn't start with the parent lemma, return the full text
                return @text
            end
        end
        
        # Convert to string representation
        # @return [String] the string representation of this sublemma
        def to_s
            if redirected?
                @redirect.to_s
            else
                @text
            end
        end
    end
end