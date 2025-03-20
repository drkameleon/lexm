#############################################################
# LexM - Lemma Markup Format
#
# A specification for representing, dictionary-ready
# lexical entries and their relationships
#
# File: lib/lexm/lemma_redirect.rb
# Author: Yanis Zafirópulos (aka Dr.Kameleon)
#############################################################

module LexM
    # Represents a redirection to another lemma, with optional relation types
    class LemmaRedirect
        attr_accessor :target, :types
        
        # Initialize a new redirection
        # @param target [String] the target lemma to redirect to
        # @param types [Array<String>] relation types (e.g., ["pl"], ["sp", "pp"])
        def initialize(target, types = [])
            @target = target
            @types = types || []
        end
        
        # Convert to string representation
        # @return [String] the string representation of this redirection
        def to_s
            if @types.empty?
                ">#{@target}"
            elsif @types.length == 1
                ">(#{@types.first})#{@target}"
            else
                ">(#{@types.join(',')})#{@target}"
            end
        end
    end
end