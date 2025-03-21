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
        
        # Initialize a new sublemma
        # @param text [String, nil] the text of the sublemma (nil for pure redirections)
        # @param redirect [LemmaRedirect, nil] redirection information (nil for normal sublemmas)
        # @param source_file [String, nil] source file path
        # @param source_line [Integer, nil] source line number
        # @param source_column [Integer, nil] source column number
        def initialize(text = nil, redirect = nil, source_file = nil, source_line = nil, source_column = nil)
            @text = text
            @redirect = redirect
            @source_file = source_file
            @source_line = source_line
            @source_column = source_column
        end
        
        # Is this a pure redirection sublemma?
        # @return [Boolean] true if this is a pure redirection with no text
        def redirected?
            @text.nil? && !@redirect.nil?
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