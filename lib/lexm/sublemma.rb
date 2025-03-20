#############################################################
# LexM - Lemma Markup Format
#
# A specification for representing, dictionary-ready
# lexical entries and their relationships
#
# File: lib/lexm/sublemma.rb
# Author: Yanis Zafirópulos (aka Dr.Kameleon)
#############################################################

module LexM
    # Represents a sublemma, which can be either a textual sublemma or a redirection
    class Sublemma
        attr_accessor :text, :redirect
        
        # Initialize a new sublemma
        # @param text [String, nil] the text of the sublemma (nil for pure redirections)
        # @param redirect [LemmaRedirect, nil] redirection information (nil for normal sublemmas)
        def initialize(text = nil, redirect = nil)
            @text = text
            @redirect = redirect
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