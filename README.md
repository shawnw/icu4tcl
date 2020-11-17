ICU For Tcl
===========

Tcl bindings for [ICU], to provide enhanced Unicode support. It tries
to mostly provide support for things that aren't in core tcl, but
there is some overlap between `string` functions and `icu::string`
ones.

[ICU]: http://site.icu-project.org/

Dependencies
------------

tcl 8.6, and ICU libraries and headers, Critcl (At least for
now. Might turn this into a pure C extension later).

Package
=======

Variables
---------

### icu::version

Package version.

### icu::icu_version

Version of ICU being used.

Commands
--------

### icu::string

Ensemble with various string-related commands.

#### icu::string length s

Returns the number of codepoints in the string.

#### icu::string first_of s chars

Returns the index of the first character in `s` that is also in
`chars`. Returns -1 if none are.

#### icu::string first_not_of s chars

Returns the index of the first character in `s` that is not in
`chars`. Returns -1 if all are.

#### icu::string foldCase ?-exclude-special? s

Returns a case-folded version of `s`. If `-exclude-special`is given,
excludes mappings for the Turkish dotted I (U+0130) and dotless i
(U+0131), etc.

### icu::collator ?name? ?locale?

Creates and returns the name of a new command that collates
strings. If no arguments, uses the default locale's collator. If an
empty string, uses the root collator. If a name for the collator is
not given, one is generated. A single argument is interpreted as the
locale argument.

#### $collator -locale

Returns the name of the locale used by the collator command.

#### $collator s1 s2

Returns -1, 0 or 1 depending on if `s1` is less than, equal to, or
greater than `s2` according to the collator's rules.
