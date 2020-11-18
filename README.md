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

### icu::unicode_version

Version of Unicode being used.

Commands
--------

### icu::string

Ensemble with various string-related commands. Unlike the ones in
`::string`, these will handle UTF-16 strings with characters outside
of the BMP correctly. However, due to that, most of them are also
`O(N)` complexity.

#### icu::string length s

Returns the number of codepoints in the string.

#### icu::string compare ?-equivalence? ?-nocase? ?-exclude-special-i? s1 s2

Compares `s1` and `s2` in code point order, returning a number less
than 0, 0 or greater than 0 if `s1` is less than, euqal to or greater
than `s2`. `-nocase` does case-insensitive comparision, and
`-exclude-special-i` special-cases the Turkish dotted I (U+0130) and
dotless i U+0131) characters (Only meaningful with `-nocase`).

The `-equivalence` option does Unicode equivalence
comparision. *Canonical equivalence between two strings is defined as
their normalized forms (NFD or NFC) being identical.*

For locale-specific string comparision, see `icu::collator`.

#### icu::string equal ?-equivalence? ?-nocase? ?-exclude-special-i? s1 s2

Returns 1 if the two strings are equal, 0 if not. Options are the same
as for `compare`.

#### icu::string index s i

Return the character at the `i`th code point of `s`. If the string is
not that long, returns an empty string.

#### icu::string first needleString haystackString

Returns the index of the first occurence of `needleString` in
`haystackString`, or -` if not found.

#### icu::string last needleString haystackString

Returns the index of the last occurence of `needleString` in
`haystackString`, or -` if not found.

#### icu::string first_of s chars

Returns the index of the first character in `s` that is also in
`chars`. Returns -1 if none are.

#### icu::string first_not_of s chars

Returns the index of the first character in `s` that is not in
`chars`. Returns -1 if all are.

#### icu::string toupper ?-locale locale? s

Returns an upper-cased version of `s`, according to the optional
`locale` rules. If the locale is an empty string, uses the root
locale. If not present, uses the default one.

#### icu::string tolower ?-locale locale? s

Returns a lower-cased version of `s`, according to the optional
`locale` rules. If the locale is an empty string, uses the root
locale. If not present, uses the default one.

#### icu::string totitle ?-locale locale? s

Returns a title-cased version of `s`, according to the optional
`locale` rules. If the locale is an empty string, uses the root
locale. If not present, uses the default one.

#### icu::string foldcase ?-exclude-special-i? s

Returns a case-folded version of `s`. If `-exclude-special-i`is given,
excludes mappings for the Turkish dotted I (U+0130) and dotless i
(U+0131), etc.

#### icu::string nfc ?string ...?

Returns all its arguments concatenated together and normalized in NFC.

#### icu::string nfd ?string ...?

Returns all its arguments concatenated together and normalized in NFD.

#### icu::string nfkc ?string ...?

Returns all its arguments concatenated together and normalized in NFKC.

#### icu::string nfkd ?string ...?

Returns all its arguments concatenated together and normalized in NFKD.

#### icu::string is subcommand string

Returns true if all codepoints of the string match some condition. An
empty string is true unless `-strict` is given, in which case it's false.

##### is nfc string

Is the string in NFC mode?

##### is nfd string

Is the string in NFD mode?

##### is nfkc string

Is the string in NFKC mode?

##### is nfkd string

Is the string in NFKD mode?

##### is lower ?-strict? string

##### is upper ?-strict? string

##### is title ?-strict? string

Is every codepoint in the string titlecased?

##### is digit ?-strict? string

##### is alpha ?-strict? string

##### is alnum ?-strict? string

##### is punct ?-strict? string

##### is graph ?-strict? string

##### is blank ?-strict? string

##### is space ?-strict? string

##### is cntrl ?-strict? string

##### is base ?-strict? string

Is every codepoint in the string a base character?

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

### locale

An ensemble with various locale-related commands.

#### default ?locale?

Return the default locale. With an argument, also sets the default to
that.

#### get

Returns information about a given locale, or the default one if no
locale is specified.

##### get language ?locale?

Return the language code for the locale.

##### get script ?locale?

Return the script used by the locale.

##### get country ?locale?

Return the locale's country code.

##### get variant ?locale?

Return the locale's variant code.

##### get name ?locale?

Return the full name of the locale.

##### get canonname ?locale?

Return the canonicalized full name of the locale.

##### get rightoleft ?locale?

Returns 1 if the locale's script is read right to left, otherwise 0.

##### get character-orientation ?locale?

Returns `left-to-right` or `right-to-left` or `unknown`.

##### get line-orientation ?locale?

Returns `top-to-bottom` or `bottom-to-top` or `unknown`.

#### languages ?pattern?

Returns a list of known ISO language codes.

#### countries ?pattern?

Returns a list of known ISO country codes.

#### list ?pattern?

Returns a list of known locales.
