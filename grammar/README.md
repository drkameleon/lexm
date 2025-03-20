## Grammar Specification

LexM follows a formal grammar that defines its syntax. The complete EBNF grammar definition can be found in the `grammar/lexm.ebnf` file.

### Basic Syntax Rules

The LexM format has these core syntax elements:

```
# Normal lemma with annotations
lemma[annotation:value]

# Lemma with sublemmas
lemma|sublemma1,sublemma2

# Redirection lemma
lemma>>(relation)target

# Lemma with redirection sublemma
lemma|>(relation)target

# Lemma with mixed sublemmas including redirections
lemma|sublemma1,>(relation)target
```

### Grammar Components

- **Lemma**: The main entry (headword)
- **Annotations**: Optional metadata in square brackets `[key:value]`
- **Sublemmas**: Related forms separated by commas after a pipe `|`
- **Redirections**: References to other lemmas with `>>` (lemma level) or `>` (sublemma level)
- **Relations**: Optional typed relations in parentheses `(relation)`