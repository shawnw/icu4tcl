# The MIT License (MIT)
# Copyright © 2020 Shawn Wagner

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# “Software”), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

package require Tcl 8.6
package require critcl

if {![critcl::compiling]} {
    error "This extension cannot be compiled without critcl enabled"
}

critcl::tcl 8.6
critcl::license {Shawn Wagner} {MIT license}
critcl::summary {TCL bindings to ICU}
critcl::description {This package exports ICU (International
Components For Unicode) functionality to Tcl to improve its unicode
handling capability.}

critcl::cflags {*}[exec icu-config --cflags]
if {$tcl_platform(os) eq "NetBSD"} {
    critcl::cflags -I/usr/pkg/include/
    # Might also have to set LD_LIBRARY_PATH to include /usr/pkg/lib
    # when running.
}
critcl::ldflags {*}[exec icu-config --ldflags-searchpath]
critcl::clibraries {*}[exec icu-config --ldflags-libsonly]

namespace eval icu {
    variable icu_version {}
    variable unicode_version {}
}

critcl::ccode {
    #include <unicode/uversion.h>
    #include <unicode/ustring.h>
    #include <unicode/uchar.h>
    #include <unicode/uscript.h>
    #include <unicode/ucol.h>
    #include <unicode/ubrk.h>
    #include <unicode/uloc.h>
    #include <unicode/unorm2.h>
    #include <unicode/ulistformatter.h>
    #include <math.h>
    #include <stdlib.h>
    #include <stdio.h>
    #include <string.h>
}

critcl::cinit {
    _Static_assert(sizeof(UChar) == sizeof(Tcl_UniChar),
                   "Tcl_UniChar and UChar sizes differ");
    Tcl_CreateNamespace(ip, "icu", NULL, NULL);
    Tcl_CreateNamespace(ip, "icu::char", NULL, NULL);
    Tcl_CreateNamespace(ip, "icu::char::is", NULL, NULL);
    Tcl_CreateNamespace(ip, "icu::string", NULL, NULL);
    Tcl_CreateNamespace(ip, "icu::locale", NULL, NULL);
    Tcl_CreateNamespace(ip, "icu::format", NULL, NULL);
    Tcl_SetVar2Ex(ip, "icu::icu_version", NULL,
                  Tcl_NewStringObj(U_ICU_VERSION, -1), 0);
    Tcl_SetVar2Ex(ip, "icu::unicode_version", NULL,
                  Tcl_NewStringObj(U_UNICODE_VERSION, -1), 0);
} {}

critcl::ccode {
    static void set_icu_error_result(Tcl_Interp *interp, const char *msg,
                                     UErrorCode err) {
        Tcl_AddErrorInfo(interp, "Internal ICU error");
        Tcl_SetErrorCode(interp, "ICU", u_errorName(err), (char *)NULL);
        Tcl_SetResult(interp, (char *)msg, TCL_STATIC);
     }
}

critcl::ccommand icu::char::value {cdata interp objc objv} {
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "character");
        return TCL_ERROR;
    }

    UChar32 c = -1;
    Tcl_UniChar *s = Tcl_GetUnicode(objv[1]);
    U16_GET(s, 0, 0, -1, c);
    Tcl_SetObjResult(interp, Tcl_NewIntObj(c));
    return TCL_OK;
}

critcl::ccommand icu::char::tochar {cdata interp objc objv} {
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "codepoint");
        return TCL_ERROR;
    }

    UChar32 c;
    if (Tcl_GetIntFromObj(interp, objv[1], &c) != TCL_OK) {
        return TCL_ERROR;
    }

    if (c < UCHAR_MIN_VALUE || c > UCHAR_MAX_VALUE) {
        Tcl_SetResult(interp, "codepoint out of range", TCL_STATIC);
        return TCL_ERROR;
    }

    Tcl_UniChar res[3] = { 0, 0, 0 };
    int reslen = -1;
    if (U16_LENGTH(c) == 1) {
        res[0] = c;
        reslen = 1;
    } else {
        res[0] = U16_LEAD(c);
        res[1] = U16_TRAIL(c);
        reslen = 2;
    }
    Tcl_SetObjResult(interp, Tcl_NewUnicodeObj(res, reslen));
    return TCL_OK;
}

critcl::ccommand icu::char::name {cdata interp objc objv} {
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "character");
        return TCL_ERROR;
    }

    UChar32 c;
    if (Tcl_GetIntFromObj(interp, objv[1], &c) != TCL_OK) {
        return TCL_ERROR;
    }

    if (c < UCHAR_MIN_VALUE || c > UCHAR_MAX_VALUE) {
        Tcl_SetResult(interp, "codepoint out of range", TCL_STATIC);
        return TCL_ERROR;
    }

    char name[256];
    UErrorCode err = U_ZERO_ERROR;
    int32_t len = u_charName(c, U_UNICODE_CHAR_NAME, name, sizeof name, &err);
    if (U_FAILURE(err) || len > sizeof name) {
        set_icu_error_result(interp, "u_charName", err);
        return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_NewStringObj(name, len));
    return TCL_OK;
}

critcl::ccommand icu::char::lookup {cdata interp objc objv} {
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "name");
        return TCL_ERROR;
    }

    UErrorCode err = U_ZERO_ERROR;
    UChar32 c = u_charFromName(U_UNICODE_CHAR_NAME, Tcl_GetString(objv[1]),
                               &err);
    if (err == U_INVALID_CHAR_FOUND) {
        Tcl_SetObjResult(interp, Tcl_NewIntObj(-1));
        return TCL_OK;
    } else if (U_FAILURE(err)) {
        set_icu_error_result(interp, "u_charFromName", err);
        return TCL_ERROR;
    } else {
        Tcl_SetObjResult(interp, Tcl_NewIntObj(c));
        return TCL_OK;
    }
}

critcl::ccommand icu::char::script {cdata interp objc objv} {
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "character");
        return TCL_ERROR;
    }

    UChar32 c;
    if (Tcl_GetIntFromObj(interp, objv[1], &c) != TCL_OK) {
        return TCL_ERROR;
    }

    if (c < UCHAR_MIN_VALUE || c > UCHAR_MAX_VALUE) {
        Tcl_SetResult(interp, "codepoint out of range", TCL_STATIC);
        return TCL_ERROR;
    }

    char name[256];
    UErrorCode err = U_ZERO_ERROR;
    UScriptCode script = uscript_getScript(c, &err);
    if (script == 0) {
        Tcl_SetResult(interp, "invalid codepoint", TCL_STATIC);
        return TCL_ERROR;
    } else if (U_FAILURE(err)) {
        set_icu_error_result(interp, "uscript_getScript", err);
        return TCL_ERROR;
    } else {
        Tcl_SetResult(interp, (char *)uscript_getName(script), TCL_VOLATILE);
        return TCL_OK;
    }
}

critcl::cproc icu::char::is::mirrored {int cp} boolean {
    return u_isMirrored(cp);
}

critcl::cproc icu::char::is::lower {int cp} boolean {
    return u_islower(cp);
}

critcl::cproc icu::char::is::upper {int cp} boolean {
    return u_isupper(cp);
}

critcl::cproc icu::char::is::title {int cp} boolean {
    return u_istitle(cp);
}

critcl::cproc icu::char::is::digit {int cp} boolean {
    return u_isdigit(cp);
}

critcl::cproc icu::char::is::alpha {int cp} boolean {
    return u_isalpha(cp);
}

critcl::cproc icu::char::is::alnum {int cp} boolean {
    return u_isalnum(cp);
}

critcl::cproc icu::char::is::punct {int cp} boolean {
    return u_ispunct(cp);
}

critcl::cproc icu::char::is::graph {int cp} boolean {
    return u_isgraph(cp);
}

critcl::cproc icu::char::is::blank {int cp} boolean {
    return u_isblank(cp);
}

critcl::cproc icu::char::is::space {int cp} boolean {
    return u_isspace(cp);
}

critcl::cproc icu::char::is::cntrl {int cp} boolean {
    return u_iscntrl(cp);
}

critcl::cproc icu::char::is::base {int cp} boolean {
    return u_isbase(cp);
}

critcl::cproc icu::char::is::defined {int cp} boolean {
    return u_isdefined(cp);
}

critcl::cproc icu::char::mirrorchar {int cp} int {
    return u_charMirror(cp);
}

critcl::cproc icu::char::pairedbracket {int cp} int {
    return u_getBidiPairedBracket(cp);
}

critcl::cproc icu::char::decimal {int cp} int {
    return u_charDigitValue(cp);
}

critcl::cproc icu::char::digit {int cp int {radix 10}} int {
    return u_digit(cp, radix);
}

critcl::cproc icu::char::number {int cp} double {
    double d = u_getNumericValue(cp);
    return d == U_NO_NUMERIC_VALUE ? NAN : d;
}

critcl::cproc icu::char::tolower {int cp} int {
    return u_tolower(cp);
}

critcl::cproc icu::char::toupper {int cp} int {
    return u_toupper(cp);
}

critcl::cproc icu::char::totitle {int cp} int {
    return u_totitle(cp);
}

# Return the number of codepoints in a string. Differs from 8.X [string
# length] for surrogate pairs.
critcl::ccommand icu::string::length {cdata interp objc objv} {
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "string");
        return TCL_ERROR;
    }
    Tcl_SetObjResult(interp,
                     Tcl_NewIntObj(u_countChar32(Tcl_GetUnicode(objv[1]), -1)));
    return TCL_OK;
}

critcl::ccommand icu::string::compare {cdata interp objc objv} {
    int idx = 1;
    int options = U_COMPARE_CODE_POINT_ORDER;
    _Bool nocase = 0, equiv = 0;

    if (objc < 3 || objc > 6) {
        Tcl_WrongNumArgs(interp, 1, objv,
                         "?-equivalence? ?-nocase? ?-exclude-special-i? s1 s2");
        return TCL_ERROR;
    }

    while (idx < objc - 2) {
        const char *opt = Tcl_GetString(objv[idx++]);
        if (strcmp(opt, "-equivalence") == 0) {
            equiv = 1;
        } else if (strcmp(opt, "-nocase") == 0) {
            nocase = 1;
        } else if (strcmp(opt, "-exclude-special-i") == 0) {
            options |= U_FOLD_CASE_EXCLUDE_SPECIAL_I;
        } else if (opt[0] == '-') {
            Tcl_SetResult(interp, "unknown option", TCL_STATIC);
            return TCL_ERROR;
        } else {
            Tcl_WrongNumArgs(interp, 1, objv,
                             "?-equivalence? ?-nocase? ?-exclude-special-i? s1 s2");
            return TCL_ERROR;
        }
    }

    uint32_t res;
    UErrorCode err = U_ZERO_ERROR;
    if (equiv) {
        if (nocase) {
            options |= U_COMPARE_IGNORE_CASE;
        }
        res = unorm_compare(Tcl_GetUnicode(objv[idx]), -1,
                            Tcl_GetUnicode(objv[idx+1]), -1,
                            options, &err);
        if (U_FAILURE(err)) {
            set_icu_error_result(interp, "unorm_compare", err);
            return TCL_ERROR;
        }
    } else if (nocase) {
        res = u_strCaseCompare(Tcl_GetUnicode(objv[idx]), -1,
                               Tcl_GetUnicode(objv[idx+1]), -1,
                               options, &err);
        if (U_FAILURE(err)) {
            set_icu_error_result(interp, "u_strCaseCompare", err);
            return TCL_ERROR;
        }
    } else {
        res = u_strcmpCodePointOrder(Tcl_GetUnicode(objv[idx]),
                                     Tcl_GetUnicode(objv[idx+1]));
    }
    Tcl_SetObjResult(interp, Tcl_NewIntObj(res));
    return TCL_OK;
}

critcl::ccommand icu::string::index {cdata interp objc objv} {
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "string charIndex");
        return TCL_ERROR;
    }

    int32_t slen;
    const Tcl_UniChar *s = Tcl_GetUnicodeFromObj(objv[1], &slen);
    int skip, offset = 0;

    if (Tcl_GetIntFromObj(interp, objv[2], &skip) != TCL_OK) {
        return TCL_ERROR;
    }
    if (skip < 0) {
        Tcl_SetResult(interp, "charIndex cannot be negative", TCL_STATIC);
        return TCL_ERROR;
    }
    U16_FWD_N(s, offset, slen, skip);
    if (s[offset]) {
        UChar32 c = 0;
        Tcl_UniChar res[3] = { 0, 0, 0};
        int reslen = -1;
        U16_NEXT_OR_FFFD(s, offset, slen, c);
        if (U16_LENGTH(c) == 1) {
            res[0] = c;
            reslen = 1;
        } else {
            res[0] = U16_LEAD(c);
            res[1] = U16_TRAIL(c);
            reslen = 2;
        }
        Tcl_SetObjResult(interp, Tcl_NewUnicodeObj(res, reslen));
    } else {
        Tcl_SetResult(interp, "", TCL_STATIC);
    }
    return TCL_OK;
}

critcl::ccommand icu::string::range {cdata interp objc objv} {
    if (objc != 4) {
        Tcl_WrongNumArgs(interp, 1, objv, "string first last");
        return TCL_ERROR;
    }

    int start_cp, end_cp;

    if (Tcl_GetIntFromObj(interp, objv[2], &start_cp) != TCL_OK ||
        Tcl_GetIntFromObj(interp, objv[3], &end_cp) != TCL_OK) {
        return TCL_ERROR;
    }
    if (start_cp > end_cp) {
        Tcl_SetResult(interp, "first must be <= last", TCL_STATIC);
        return TCL_ERROR;
    }

    int32_t offset = 0, start_offset, end_offset,
            sublen = end_cp - start_cp + 1;
    int len;
    const Tcl_UniChar *s = Tcl_GetUnicodeFromObj(objv[1], &len);
    U16_FWD_N(s, offset, len, start_cp);
    start_offset = offset;
    U16_FWD_N(s, offset, len, sublen);
    end_offset = offset;
    Tcl_SetObjResult(interp,
                     Tcl_NewUnicodeObj(s + start_offset,
                                       end_offset - start_offset));
    return TCL_OK;
}


critcl::ccommand icu::string::first {cdata interp objc objv} {
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "needleString haystackString");
        return TCL_ERROR;
    }

    const Tcl_UniChar *s = Tcl_GetUnicode(objv[2]);
    const Tcl_UniChar *loc = u_strFindFirst(s, -1, Tcl_GetUnicode(objv[1]), -1);
    int32_t pos = -1;
    if (loc) {
        pos = u_countChar32(s, loc - s);
    } else {
        pos = -1;
    }
    Tcl_SetObjResult(interp, Tcl_NewIntObj(pos));
    return TCL_OK;
}

critcl::ccommand icu::string::last {cdata interp objc objv} {
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "needleString haystackString");
        return TCL_ERROR;
    }

    const Tcl_UniChar *s = Tcl_GetUnicode(objv[2]);
    const Tcl_UniChar *loc = u_strFindLast(s, -1, Tcl_GetUnicode(objv[1]), -1);
    int32_t pos = -1;
    if (loc) {
        pos = u_countChar32(s, loc - s);
    } else {
        pos = -1;
    }
    Tcl_SetObjResult(interp, Tcl_NewIntObj(pos));
    return TCL_OK;
}

# Return the index of the first codepoint in string that is included
# in characters.
critcl::ccommand icu::string::first_of {cdata interp objc objv} {
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "string characters");
        return TCL_ERROR;
    }
    UChar *str = Tcl_GetUnicode(objv[1]);
    int32_t pos = u_strcspn(str, Tcl_GetUnicode(objv[2]));
    if (str[pos]) {
        Tcl_SetObjResult(interp, Tcl_NewIntObj(u_countChar32(str, pos)));
    } else {
        Tcl_SetObjResult(interp, Tcl_NewIntObj(-1));
    }
    return TCL_OK;
}

critcl::ccommand icu::string::first_not_of {cdata interp objc objv} {
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "string characters");
        return TCL_ERROR;
    }
    UChar *str = Tcl_GetUnicode(objv[1]);
    int32_t pos = u_strspn(str, Tcl_GetUnicode(objv[2]));
    if (str[pos]) {
        Tcl_SetObjResult(interp, Tcl_NewIntObj(u_countChar32(str, pos)));
    } else {
        Tcl_SetObjResult(interp, Tcl_NewIntObj(-1));
    }
    return TCL_OK;
}

critcl::ccommand icu::string::foldcase {cdata interp objc objv} {
    uint32_t options = U_FOLD_CASE_DEFAULT;
    Tcl_UniChar *dest = NULL;
    uint32_t dest_capacity = 0;
    UErrorCode err = U_ZERO_ERROR;
    int idx = 1;

    if (objc == 1 || objc > 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "?-exclude-special-i? string");
        return TCL_ERROR;
    }

    if (objc == 3) {
        const char *arg = Tcl_GetString(objv[1]);
        idx = 2;
        if (strcmp(arg, "-exclude-special-i") == 0) {
            options = U_FOLD_CASE_EXCLUDE_SPECIAL_I;
        } else if (arg[0] == '-') {
            Tcl_SetResult(interp, "Unknown option", TCL_STATIC);
            return TCL_ERROR;
        } else {
            Tcl_WrongNumArgs(interp, 1, objv, "?-exclude-special-i? string");
            return TCL_ERROR;
        }
    }

    dest_capacity = Tcl_GetCharLength(objv[idx]) + 1;
    dest = (Tcl_UniChar *)ckalloc(dest_capacity * sizeof(Tcl_UniChar));
    uint32_t dest_len = u_strFoldCase(dest, dest_capacity,
                                      Tcl_GetUnicode(objv[idx]), -1,
                                      options, &err);
    if (err == U_BUFFER_OVERFLOW_ERROR || dest_len > dest_capacity) {
        dest_capacity = dest_len + 1;
        dest = (Tcl_UniChar *)ckrealloc((char *)dest,
                                        dest_capacity * sizeof(Tcl_UniChar));
        err = U_ZERO_ERROR;
        dest_len = u_strFoldCase(dest, dest_capacity,
                                 Tcl_GetUnicode(objv[idx]), -1,
                                 options, &err);
    }

    if (U_FAILURE(err)) {
        set_icu_error_result(interp, "u_strFoldCase", err);
        ckfree((char *)dest);
        return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, Tcl_NewUnicodeObj(dest, dest_len));
    ckfree((char *)dest);
    return TCL_OK;
}

critcl::ccommand icu::string::toupper {cdata interp objc objv} {
    Tcl_UniChar *dest = NULL;
    uint32_t dest_capacity = 0;
    const char *loc = NULL;
    UErrorCode err = U_ZERO_ERROR;
    int idx = 1;

    if (!(objc == 2 || objc == 4)) {
        Tcl_WrongNumArgs(interp, 1, objv, "?-locale locale? string");
        return TCL_ERROR;
    }

    if (objc == 4) {
        idx = 3;
        const char *arg = Tcl_GetString(objv[1]);
        if (strcmp(arg, "-locale") == 0) {
            loc = Tcl_GetString(objv[2]);
        } else if (arg[0] == '-') {
            Tcl_SetResult(interp, "Unknown option", TCL_STATIC);
            return TCL_ERROR;
        } else {
            Tcl_WrongNumArgs(interp, 1, objv, "?-locale locale? string");
            return TCL_ERROR;
        }
    }

    dest_capacity = Tcl_GetCharLength(objv[idx]) + 1;
    dest = (Tcl_UniChar *)ckalloc(dest_capacity * sizeof(Tcl_UniChar));

    uint32_t dest_len = u_strToUpper(dest, dest_capacity,
                                     Tcl_GetUnicode(objv[idx]), -1,
                                     loc, &err);
    if (err == U_BUFFER_OVERFLOW_ERROR || dest_len > dest_capacity) {
        dest_capacity = dest_len + 1;
        dest = (Tcl_UniChar *)ckrealloc((char *)dest,
                                        dest_capacity * sizeof(Tcl_UniChar));
        err = U_ZERO_ERROR;
        dest_len = u_strToUpper(dest, dest_capacity,
                                Tcl_GetUnicode(objv[idx]), -1,
                                loc, &err);
    }

    if (U_FAILURE(err)) {
        set_icu_error_result(interp, "u_strToUpper", err);
        ckfree((char *)dest);
        return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, Tcl_NewUnicodeObj(dest, dest_len));
    ckfree((char *)dest);
    return TCL_OK;
}

critcl::ccommand icu::string::tolower {cdata interp objc objv} {
    Tcl_UniChar *dest = NULL;
    uint32_t dest_capacity = 0;
    const char *loc = NULL;
    UErrorCode err = U_ZERO_ERROR;
    int idx = 1;

    if (!(objc == 2 || objc == 4)) {
        Tcl_WrongNumArgs(interp, 1, objv, "?-locale locale? string");
        return TCL_ERROR;
    }

    if (objc == 4) {
        idx = 3;
        const char *arg = Tcl_GetString(objv[1]);
        if (strcmp(arg, "-locale") == 0) {
            loc = Tcl_GetString(objv[2]);
        } else if (arg[0] == '-') {
            Tcl_SetResult(interp, "Unknown option", TCL_STATIC);
            return TCL_ERROR;
        } else {
            Tcl_WrongNumArgs(interp, 1, objv, "?-locale locale? string");
            return TCL_ERROR;
        }
    }

    dest_capacity = Tcl_GetCharLength(objv[idx]) + 1;
    dest = (Tcl_UniChar *)ckalloc(dest_capacity * sizeof(Tcl_UniChar));

    uint32_t dest_len = u_strToLower(dest, dest_capacity,
                                     Tcl_GetUnicode(objv[idx]), -1,
                                     loc, &err);
    if (err == U_BUFFER_OVERFLOW_ERROR || dest_len > dest_capacity) {
        dest_capacity = dest_len + 1;
        dest = (Tcl_UniChar *)ckrealloc((char *)dest,
                                        dest_capacity * sizeof(Tcl_UniChar));
        err = U_ZERO_ERROR;
        dest_len = u_strToLower(dest, dest_capacity,
                                Tcl_GetUnicode(objv[idx]), -1,
                                loc, &err);
    }

    if (U_FAILURE(err)) {
        set_icu_error_result(interp, "u_strToLower", err);
        ckfree((char *)dest);
        return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, Tcl_NewUnicodeObj(dest, dest_len));
    ckfree((char *)dest);
    return TCL_OK;
}

critcl::ccommand icu::string::totitle {cdata interp objc objv} {
    Tcl_UniChar *dest = NULL;
    uint32_t dest_capacity = 0;
    const char *loc = NULL;
    UErrorCode err = U_ZERO_ERROR;
    int idx = 1;

    if (!(objc == 2 || objc == 4)) {
        Tcl_WrongNumArgs(interp, 1, objv, "?-locale locale? string");
        return TCL_ERROR;
    }

    if (objc == 4) {
        idx = 3;
        const char *arg = Tcl_GetString(objv[1]);
        if (strcmp(arg, "-locale") == 0) {
            loc = Tcl_GetString(objv[2]);
        } else if (arg[0] == '-') {
            Tcl_SetResult(interp, "Unknown option", TCL_STATIC);
            return TCL_ERROR;
        } else {
            Tcl_WrongNumArgs(interp, 1, objv, "?-locale locale? string");
            return TCL_ERROR;
        }
    }

    dest_capacity = Tcl_GetCharLength(objv[idx]) + 1;
    dest = (Tcl_UniChar *)ckalloc(dest_capacity * sizeof(Tcl_UniChar));

    uint32_t dest_len = u_strToTitle(dest, dest_capacity,
                                     Tcl_GetUnicode(objv[idx]), -1,
                                     NULL, loc, &err);
    if (err == U_BUFFER_OVERFLOW_ERROR || dest_len > dest_capacity) {
        dest_capacity = dest_len + 1;
        dest = (Tcl_UniChar *)ckrealloc((char *)dest,
                                        dest_capacity * sizeof(Tcl_UniChar));
        err = U_ZERO_ERROR;
        dest_len = u_strToTitle(dest, dest_capacity,
                                Tcl_GetUnicode(objv[idx]), -1,
                                NULL, loc, &err);
    }

    if (U_FAILURE(err)) {
        set_icu_error_result(interp, "u_strToTitle", err);
        ckfree((char *)dest);
        return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, Tcl_NewUnicodeObj(dest, dest_len));
    ckfree((char *)dest);
    return TCL_OK;
}

critcl::ccode {
    int do_normalize(const UNormalizer2 *norm, Tcl_Interp *interp, int objc,
                     Tcl_Obj * const * objv) {
        UErrorCode err = U_ZERO_ERROR;
        Tcl_UniChar *dest = NULL;
        int32_t destlen = 0, destcap = 0;

        if (objc == 1) {
            Tcl_SetResult(interp, "", TCL_STATIC);
            return TCL_OK;
        }

        for (int i = 1; i < objc; i += 1) {
            destcap += Tcl_GetCharLength(objv[i]);
        }
        destcap *= 2;
        destcap += 1;
        dest = (Tcl_UniChar *)ckalloc(destcap * sizeof(Tcl_UniChar));
        destlen = unorm2_normalize(norm, Tcl_GetUnicode(objv[1]), -1,
                                   dest, destcap, &err);
        if (err == U_BUFFER_OVERFLOW_ERROR || destlen > destcap) {
            destcap = (destlen * 2) + 1;
            dest = (Tcl_UniChar *)ckrealloc((char *)dest,
                                            destcap * sizeof(Tcl_UniChar));
            err = U_ZERO_ERROR;
            destlen = unorm2_normalize(norm, Tcl_GetUnicode(objv[1]), -1,
                                       dest, destcap, &err);
        }
        if (U_FAILURE(err)) {
            set_icu_error_result(interp, "unorm2_normalize", err);
            ckfree((char *)dest);
            return TCL_ERROR;
        }
        for (int i = 2; i < objc; i += 1)
        {
         int32_t newlen = unorm2_normalizeSecondAndAppend(norm,
                                                          dest, destlen, destcap,
                                                          Tcl_GetUnicode(objv[i]),-1,
                                                          &err);
         if (err == U_BUFFER_OVERFLOW_ERROR || newlen > destcap) {
             destcap = (newlen * 2) + 1;
             dest = (Tcl_UniChar *)ckrealloc((char *)dest,
                                             destcap * sizeof(Tcl_UniChar));
             err = U_ZERO_ERROR;
             newlen = unorm2_normalizeSecondAndAppend(norm,
                                                      dest, destlen, destcap,
                                                      Tcl_GetUnicode(objv[i]), -1,
                                                      &err);
     }
         if (U_SUCCESS(err)) {
             destlen = newlen;
         } else {
             set_icu_error_result(interp, "unorm2_normalizeSecondAndAppend", err);
             ckfree((char *)dest);
             return TCL_ERROR;
         }
     }
        dest[destlen] = 0;
        Tcl_SetObjResult(interp, Tcl_NewUnicodeObj(dest, destlen));
        ckfree((char *)dest);
        return TCL_OK;
    }
}

critcl::ccommand icu::string::nfc {cdata interp objc objv} {
    UErrorCode err = U_ZERO_ERROR;
    return do_normalize(unorm2_getNFCInstance(&err), interp, objc, objv);
}

critcl::ccommand icu::string::nfd {cdata interp objc objv} {
    UErrorCode err = U_ZERO_ERROR;
    return do_normalize(unorm2_getNFDInstance(&err), interp, objc, objv);
}

critcl::ccommand icu::string::nfkc {cdata interp objc objv} {
    UErrorCode err = U_ZERO_ERROR;
    return do_normalize(unorm2_getNFKCInstance(&err), interp, objc, objv);
}

critcl::ccommand icu::string::nfkd {cdata interp objc objv} {
    UErrorCode err = U_ZERO_ERROR;
    return do_normalize(unorm2_getNFKDInstance(&err), interp, objc, objv);
}

critcl::ccode {
    static int check_norm(const UNormalizer2 *form, Tcl_Interp *interp, int objc,
                          Tcl_Obj * const *objv) {
        UErrorCode err = U_ZERO_ERROR;

        if (objc != 3) {
           Tcl_WrongNumArgs(interp, 1, objv,
                            "normalization-mode string");
           return TCL_ERROR;
        }

        int32_t len;
        Tcl_UniChar *s = Tcl_GetUnicodeFromObj(objv[2], &len);

        int res = unorm2_isNormalized(form, s, len, &err);
        if (U_FAILURE(err)) {
            set_icu_error_result(interp, "unorm2_isNormalized", err);
            return TCL_ERROR;
        }
        Tcl_SetObjResult(interp, Tcl_NewBooleanObj(res));
        return TCL_OK;
     }

    typedef UBool (*prop_func)(UChar32);
    static int check_prop(prop_func f, Tcl_Interp *interp, int objc, Tcl_Obj * const *objv) {
        int32_t len, offset = 0;
        UChar32 c;
        _Bool res = 0, strict_mode = 0;
        const Tcl_UniChar *s;
        int idx = 2;

        if (objc == 4) {
            const char * s = Tcl_GetString(objv[2]);
            if (strcmp(s, "-strict") == 0) {
                strict_mode = 1;
                idx = 3;
            } else if (s[0] == '-') {
                Tcl_SetResult(interp, "Unknown switch", TCL_STATIC);
                return TCL_ERROR;
            } else {
                Tcl_WrongNumArgs(interp, 1, objv,
                                 "subcommand ?-strict? string");
                return TCL_ERROR;
            }
        }

        s = Tcl_GetUnicodeFromObj(objv[idx], &len);

        if (strict_mode && !s[0]) {
            Tcl_SetObjResult(interp, Tcl_NewBooleanObj(0));
            return TCL_OK;
        }

        while (1) {
            U16_NEXT_OR_FFFD(s, offset, len, c);
            if (!c) {
                res = 1;
                break;
            }
            if (!f(c)) {
                res = 0;
                break;
            }
        }
        Tcl_SetObjResult(interp, Tcl_NewBooleanObj(res));
        return TCL_OK;
    }
}

critcl::ccommand icu::string::is {cdata interp objc objv} {
    UErrorCode err = U_ZERO_ERROR;
    if (objc < 3 || objc > 4) {
        Tcl_WrongNumArgs(interp, 1, objv, "subcommand ?-strict? string");
        return TCL_ERROR;
    }

    const char *subcommand = Tcl_GetString(objv[1]);
    // TODO: Replace with a lookup table
    if (strcmp(subcommand, "nfc") == 0) {
        return check_norm(unorm2_getNFCInstance(&err), interp, objc, objv);
    } else if (strcmp(subcommand, "nfd") == 0) {
        return check_norm(unorm2_getNFDInstance(&err), interp, objc, objv);
    } else if (strcmp(subcommand, "nfkc") == 0) {
        return check_norm(unorm2_getNFKCInstance(&err), interp, objc, objv);
    } else if (strcmp(subcommand, "nfkd") == 0) {
        return check_norm(unorm2_getNFKDInstance(&err), interp, objc, objv);
    } else if (strcmp(subcommand, "lower") == 0) {
        return check_prop(u_islower, interp, objc, objv);
    } else if (strcmp(subcommand, "upper") == 0) {
        return check_prop(u_isupper, interp, objc, objv);
    } else if (strcmp(subcommand, "title") == 0) {
        return check_prop(u_istitle, interp, objc, objv);
    } else if (strcmp(subcommand, "digit") == 0) {
        return check_prop(u_isdigit, interp, objc, objv);
    } else if (strcmp(subcommand, "alpha") == 0) {
        return check_prop(u_isalpha, interp, objc, objv);
    } else if (strcmp(subcommand, "alnum") == 0) {
        return check_prop(u_isalnum, interp, objc, objv);
    } else if (strcmp(subcommand, "punct") == 0) {
        return check_prop(u_ispunct, interp, objc, objv);
    } else if (strcmp(subcommand, "graph") == 0) {
        return check_prop(u_isgraph, interp, objc, objv);
    } else if (strcmp(subcommand, "blank") == 0) {
        return check_prop(u_isblank, interp, objc, objv);
    } else if (strcmp(subcommand, "space") == 0) {
        return check_prop(u_isspace, interp, objc, objv);
    } else if (strcmp(subcommand, "cntrl") == 0) {
        return check_prop(u_iscntrl, interp, objc, objv);
    } else if (strcmp(subcommand, "print") == 0) {
        return check_prop(u_isprint, interp, objc, objv);
    } else if (strcmp(subcommand, "base") == 0) {
        return check_prop(u_isbase, interp, objc, objv);
    } else {
        Tcl_SetResult(interp, "unknown is subcommand", TCL_STATIC);
        return TCL_ERROR;
    }
    return TCL_OK;
}

critcl::ccode {
    static int split_codepoints(Tcl_Interp *interp, Tcl_Obj *obj) {
        int len;
        const Tcl_UniChar *s = Tcl_GetUnicodeFromObj(obj, &len);
        UChar32 c;
        int offset = 0;
        Tcl_Obj *lst = Tcl_NewListObj(0, NULL);
        Tcl_IncrRefCount(lst);

        U16_NEXT_OR_FFFD(s, offset, len, c);
        while (c) {
            if (Tcl_ListObjAppendElement(interp, lst, Tcl_NewIntObj(c)) != TCL_OK) {
                Tcl_DecrRefCount(lst);
                return TCL_ERROR;
            }
            U16_NEXT_OR_FFFD(s, offset, len, c);
        }
        Tcl_SetObjResult(interp, lst);
        Tcl_DecrRefCount(lst);
        return TCL_OK;
    }
}

critcl::ccommand icu::string::break {cdata interp objc objv} {
    _Bool include_rules = 0;

    if (!(objc == 3 || objc == 5)) {
        Tcl_WrongNumArgs(interp, 1, objv, "subcommand ?-locale locale? string");
        return TCL_ERROR;
    }

    const char *loc = NULL;
    int idx = 2;
    UBreakIteratorType type = UBRK_CHARACTER;

    const char *subcommand = Tcl_GetString(objv[1]);
    if (strcmp(subcommand, "codepoints") == 0) {
        return split_codepoints(interp, objv[2]);
    } else if (strcmp(subcommand, "characters") == 0) {
        type = UBRK_CHARACTER;
    } else if (strcmp(subcommand, "words") == 0) {
        type = UBRK_WORD;
    } else if (strcmp(subcommand, "sentences") == 0) {
        type = UBRK_SENTENCE;
    } else if (strcmp(subcommand, "lines") == 0) {
        type = UBRK_LINE;
        include_rules = 1;
    } else {
        Tcl_SetResult(interp, "Uknown subcommand", TCL_STATIC);
        return TCL_ERROR;
    }

    if (objc == 5) {
        const char *opt = Tcl_GetString(objv[2]);
        if (strcmp(opt, "-locale") == 0) {
            loc = Tcl_GetString(objv[3]);
            idx = 4;
        } else if (opt[0] == '-') {
            Tcl_SetResult(interp, "Uknown option", TCL_STATIC);
            return TCL_ERROR;
        } else {
            Tcl_WrongNumArgs(interp, 1, objv, "subcommand ?-locale locale? string");
            return TCL_ERROR;
        }
    }

    int32_t len;
    const Tcl_UniChar *s = Tcl_GetUnicodeFromObj(objv[idx], &len);
    UErrorCode err = U_ZERO_ERROR;
    UBreakIterator *i = ubrk_open(type, loc, s, len, &err);
    if (U_FAILURE(err)) {
        set_icu_error_result(interp, "ubrk_open", err);
        return TCL_ERROR;
    }

    Tcl_Obj *res = Tcl_NewListObj(0, NULL);
    uint32_t start_pos = 0, end_pos;
    Tcl_IncrRefCount(res);
    while ((end_pos = ubrk_next(i)) != UBRK_DONE) {
        UChar32 c;
        U16_GET_OR_FFFD(s, 0, start_pos, len, c);
        if (type == UBRK_WORD && u_isspace(c)) {
            start_pos = end_pos;
            continue;
        }

        if (include_rules) {
            int32_t rule = ubrk_getRuleStatus(i);
            const char *break_type = "";
            Tcl_Obj *pair = Tcl_NewListObj(0, NULL);
            Tcl_IncrRefCount(pair);
            if (Tcl_ListObjAppendElement(interp, pair,
                                         Tcl_NewUnicodeObj(s + start_pos,
                                                           end_pos - start_pos))
                != TCL_OK) {
                Tcl_DecrRefCount(pair);
                Tcl_DecrRefCount(res);
                ubrk_close(i);
                return TCL_ERROR;
            }

            switch (type) {
                case UBRK_LINE:

                if (rule >= UBRK_LINE_SOFT && rule < UBRK_LINE_SOFT_LIMIT) {
                    break_type = "soft";
                } else if (rule >= UBRK_LINE_HARD && rule < UBRK_LINE_HARD_LIMIT) {
                    break_type = "hard";
                }
                break;
                default:
                (void)0;
            }

            if (Tcl_ListObjAppendElement(interp, pair, Tcl_NewStringObj(break_type, -1))
                != TCL_OK) {
                Tcl_DecrRefCount(pair);
                Tcl_DecrRefCount(res);
                ubrk_close(i);
                return TCL_ERROR;
            }
            if (Tcl_ListObjAppendElement(interp, res, pair) != TCL_OK) {
                Tcl_DecrRefCount(pair);
                Tcl_DecrRefCount(res);
                ubrk_close(i);
                return TCL_ERROR;
            }
            Tcl_DecrRefCount(pair);
        } else {
            if (Tcl_ListObjAppendElement(interp, res,
                                         Tcl_NewUnicodeObj(s + start_pos,
                                                           end_pos - start_pos))
                != TCL_OK) {
                Tcl_DecrRefCount(res);
                ubrk_close(i);
                return TCL_ERROR;
            }
        }
        start_pos = end_pos;
    }
    ubrk_close(i);
    Tcl_SetObjResult(interp, res);
    Tcl_DecrRefCount(res);
    return TCL_OK;
}

critcl::ccode {
    static void free_collator(ClientData cd) {
        ucol_close((UCollator *)cd);
    }

    static int do_collator(ClientData cd, Tcl_Interp *interp, int objc,
                           Tcl_Obj * const objv[]) {
       if (objc == 2 && strcmp(Tcl_GetString(objv[1]), "-locale") == 0) {
           UErrorCode err = U_ZERO_ERROR;
           const char *name = ucol_getLocaleByType((UCollator *)cd,
                                                   ULOC_ACTUAL_LOCALE,
                                                   &err);
          if (U_FAILURE(err)) {
              set_icu_error_result(interp, "Unable to get collation locale",
                                   err);
              return TCL_ERROR;
          }
          if (name) {
             Tcl_SetResult(interp, (char *)name, TCL_VOLATILE);
           } else {
             Tcl_SetResult(interp, "", TCL_STATIC);
           }
           return TCL_OK;
      }
      if (objc != 4) {
          Tcl_WrongNumArgs(interp, 1, objv, "string string");
          return TCL_ERROR;
      }
      int res;
      UCollator *coll = (UCollator *)cd;
      const char *command = Tcl_GetString(objv[1]);
      if (strcmp(command, "compare") == 0) {
          switch (ucol_strcoll(coll, Tcl_GetUnicode(objv[2]), -1,
                               Tcl_GetUnicode(objv[3]), -1)) {
                                   case UCOL_EQUAL:
                                   res = 0;
                                   break;
                                   case UCOL_GREATER:
                                   res = 1;
                                   break;
                                   case UCOL_LESS:
                                   res = -1;
                                   break;
                               }
          Tcl_SetObjResult(interp, Tcl_NewIntObj(res));
          return TCL_OK;
      } else if (strcmp(command, "equal") == 0) {
          res = ucol_equal(coll, Tcl_GetUnicode(objv[2]), -1,
                            Tcl_GetUnicode(objv[3]), -1);
      } else if (strcmp(command, "greater") == 0) {
          res = ucol_greater(coll, Tcl_GetUnicode(objv[2]), -1,
                             Tcl_GetUnicode(objv[3]), -1);
      } else if (strcmp(command, "greaterorequal") == 0) {
          res = ucol_greaterOrEqual(coll, Tcl_GetUnicode(objv[2]), -1,
                                    Tcl_GetUnicode(objv[3]), -1);
      } else {
          Tcl_SetResult(interp, "Unknown subcommand", TCL_STATIC);
          return TCL_ERROR;
      }
      Tcl_SetObjResult(interp, Tcl_NewBooleanObj(res));
      return TCL_OK;
   }
}

critcl::ccommand icu::collator {cdata interp objc objv} {
    static int counter = 1;
    char *name = NULL;
    int made_name = 0;
    const char *loc = NULL;
    UErrorCode err = U_ZERO_ERROR;

    if (objc > 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "?name? ?locale?");
        return TCL_ERROR;
    }

    if (objc == 3) {
        name = Tcl_GetString(objv[1]);
        loc = Tcl_GetString(objv[2]);
    } else if (objc == 2) {
        loc = Tcl_GetString(objv[1]);
    }

    UCollator *coll = ucol_open(loc, &err);
    if (U_FAILURE(err)) {
        set_icu_error_result(interp, "Unable to create collator", err);
        return TCL_ERROR;
    }

    if (!name) {
        const char *ns = Tcl_GetCurrentNamespace(interp)->fullName;
        int len = snprintf(NULL, 0, "%s::collator%d", ns, counter);
        name = Tcl_Alloc(len + 1);
        snprintf(name, len + 1, "%s%scollator%d", ns,
                 strcmp(ns, "::") == 0 ? "" : "::", counter);
        counter += 1;
        made_name = 1;
    }
    Tcl_CreateObjCommand(interp, name, do_collator, coll, free_collator);
    if (made_name) {
        Tcl_SetResult(interp, name, Tcl_Free);
    } else {
        Tcl_SetObjResult(interp, objv[1]);
    }
    return TCL_OK;
}

critcl::ccommand icu::locale::default {cdata interp objc objv} {
    if (objc > 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "?locale?");
        return TCL_ERROR;
    }

    if (objc == 2) {
        // Set default locale
        UErrorCode err = U_ZERO_ERROR;
        uloc_setDefault(Tcl_GetString(objv[1]), &err);
        if (U_FAILURE(err)) {
            set_icu_error_result(interp, "uloc_setDefault", err);
            return TCL_ERROR;
        }
    }

    Tcl_SetResult(interp, (char *)uloc_getDefault(), TCL_VOLATILE);
    return TCL_OK;
}

critcl::ccommand icu::locale::get {cdata interp objc objv} {
    if (objc == 1 || objc > 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "subcommand ?locale?");
        return TCL_ERROR;
    }

    const char *loc;
    if (objc == 3) {
        loc = Tcl_GetString(objv[2]);
    } else {
        loc = uloc_getDefault();
    }

    const char *func = "";
    char buffer[1024];
    UErrorCode err = U_ZERO_ERROR;
    uint32_t len = sizeof buffer;
    const char *subcommand = Tcl_GetString(objv[1]);

    if (strcmp(subcommand, "language") == 0) {
        func = "uloc_getLanguage";
        len = uloc_getLanguage(loc, buffer, len, &err);
    } else if (strcmp(subcommand, "script") == 0) {
        func = "uloc_getScript";
        len = uloc_getScript(loc, buffer,len, &err);
    } else if (strcmp(subcommand, "country") == 0) {
        func = "uloc_getCountry";
        len = uloc_getCountry(loc, buffer, len, &err);
    } else if (strcmp(subcommand, "variant") == 0) {
        func = "uloc_getVariant";
        len = uloc_getVariant(loc, buffer, len, &err);
    } else if (strcmp(subcommand, "name") == 0) {
        func = "uloc_getName";
        len = uloc_getName(loc, buffer, len, &err);
    } else if (strcmp(subcommand, "canonname") == 0) {
        func = "uloc_canonicalize";
        len = uloc_canonicalize(loc, buffer, len, &err);
    } else if (strcmp(subcommand, "righttoleft") == 0) {
        if (uloc_isRightToLeft(loc)) {
            buffer[0] = '1';
        } else {
            buffer[0] = '0';
        }
        len = 1;
    } else if (strcmp(subcommand, "character-orientation") == 0 ||
               strcmp(subcommand, "line-orientation") == 0) {
        ULayoutType o;
        UErrorCode err = U_ZERO_ERROR;
        if (subcommand[0] == 'c') {
            o = uloc_getCharacterOrientation(loc, &err);
        } else {
            o = uloc_getLineOrientation(loc, &err);
        }
        if (U_FAILURE(err)) {
            set_icu_error_result(interp, subcommand[0] == 'c' ?
                                 "uloc_getCharacterOrientation"
                                 : "uloc_getLineOrientation", err);
            return TCL_ERROR;
        }
        switch (o) {
            case ULOC_LAYOUT_LTR:
            strcpy(buffer, "left-to-right");
            break;
            case ULOC_LAYOUT_RTL:
            strcpy(buffer, "right-to-left");
            break;
            case ULOC_LAYOUT_TTB:
            strcpy(buffer, "top-to-bottom");
            break;
            case ULOC_LAYOUT_BTT:
            strcpy(buffer, "bottom-to-top");
            break;
            default:
            strcpy(buffer, "unknown");
        }
        len = strlen(buffer);
    } else {
        Tcl_SetResult(interp, "unknown icu::locale subcommand", TCL_STATIC);
        return TCL_ERROR;
    }
    if (U_FAILURE(err)) {
        set_icu_error_result(interp, func, err);
        return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_NewStringObj(buffer, len));
    return TCL_OK;
}

critcl::ccommand icu::locale::languages {cdata interp objc objv} {
    if (objc > 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "?pattern?");
        return TCL_ERROR;
    }

    const char *pattern = NULL;
    if (objc == 2) {
        pattern = Tcl_GetString(objv[1]);
    }

    Tcl_Obj *langs = Tcl_NewListObj(0, NULL);
    Tcl_IncrRefCount(langs);
    const char * const *raw = uloc_getISOLanguages();
    if (raw) {
        for (int i = 0; raw[i]; i += 1) {
           if (pattern && !Tcl_StringMatch(raw[i], pattern)) { continue; }
           if (Tcl_ListObjAppendElement(interp, langs,
                                        Tcl_NewStringObj(raw[i], strlen(raw[i]))) != TCL_OK) {
               Tcl_DecrRefCount(langs);
               return TCL_ERROR;
           }
       }
    }
    Tcl_SetObjResult(interp, langs);
    Tcl_DecrRefCount(langs);
    return TCL_OK;
}

critcl::ccommand icu::locale::countries {cdata interp objc objv} {
    if (objc > 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "?pattern?");
        return TCL_ERROR;
    }

    const char *pattern = NULL;
    if (objc == 2) {
        pattern = Tcl_GetString(objv[1]);
    }

    Tcl_Obj *countries = Tcl_NewListObj(0, NULL);
    Tcl_IncrRefCount(countries);
    const char * const *raw = uloc_getISOCountries();
    if (raw) {
        for (int i = 0; raw[i]; i += 1) {
           if (pattern && !Tcl_StringMatch(raw[i], pattern)) { continue; }
           if (Tcl_ListObjAppendElement(interp, countries,
                                        Tcl_NewStringObj(raw[i], strlen(raw[i]))) != TCL_OK) {
               Tcl_DecrRefCount(countries);
               return TCL_ERROR;
           }
       }
    }
    Tcl_SetObjResult(interp, countries);
    Tcl_DecrRefCount(countries);
    return TCL_OK;
}

critcl::ccommand icu::locale::list {cdata interp objc objv} {
        if (objc > 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "?pattern?");
        return TCL_ERROR;
    }

    const char *pattern = NULL;
    if (objc == 2) {
        pattern = Tcl_GetString(objv[1]);
    }

    #if U_ICU_VERSION_MAJOR_NUM >= 65
    UErrorCode err = U_ZERO_ERROR;
    UEnumeration *raw = uloc_openAvailableByType(ULOC_AVAILABLE_DEFAULT, &err);
    if (U_FAILURE(err)) {
        set_icu_error_result(interp, "uloc_openAvailableByType", err);
        return TCL_ERROR;
    }
    Tcl_Obj *locales = Tcl_NewListObj(0, NULL);
    Tcl_IncrRefCount(locales);
    const char *loc;
    uint32_t len;
    while ((loc = uenum_next(raw, &len, &err))) {
        if (U_FAILURE(err)) {
            set_icu_error_result(interp, "uenum_next", err);
            Tcl_DecrRefCount(locales);
            return TCL_ERROR;
        }
        if (pattern && !Tcl_StringMatch(loc, pattern)) { continue; }
        if (Tcl_ListObjAppendElement(interp, locales, Tcl_NewStringObj(loc, len)) != TCL_OK) {
            Tcl_DecrRefCount(locales);
            return TCL_ERROR;
        }
    }
    uenum_close(raw);
    #else
    uint32_t nlocales = uloc_countAvailable();
    Tcl_Obj *locales = Tcl_NewListObj(0, NULL);
    Tcl_IncrRefCount(locales);
    for (int i = 0; i < nlocales; i += 1) {
         const char *loc = uloc_getAvailable(i);
         if (!loc) { continue; }
         if (pattern && !Tcl_StringMatch(loc, pattern)) { continue; }
         if (Tcl_ListObjAppendElement(interp, locales,
                                      Tcl_NewStringObj(loc, -1)) != TCL_OK) {
             Tcl_DecrRefCount(locales);
             return TCL_ERROR;
         }
     }
    #endif
    Tcl_SetObjResult(interp, locales);
    Tcl_DecrRefCount(locales);
    return TCL_OK;
}

critcl::ccommand icu::format::list {cdata interp objc objv} {
    UErrorCode err = U_ZERO_ERROR;
    const char *loc = NULL;
    #if U_ICU_VERSION_MAJOR_NUM >= 67
    UListFormatterType type = ULISTFMT_TYPE_AND;
    UListFormatterWidth width = ULISTFMT_WIDTH_WIDE;
    #endif
    if (objc == 1 || objc > 8) {
        Tcl_WrongNumArgs(interp, 1, objv,
                         "?-locale locale? ?-type and|or|units? ?-width wide|short|narrow? lst");
        return TCL_ERROR;
    }
    int i;
    for (i = 1; i < objc - 1; i += 2)
    {
     const char *opt = Tcl_GetString(objv[i]);
     if (strcmp(opt, "-locale") == 0) {
         loc = Tcl_GetString(objv[i+1]);
     } else if (strcmp(opt, "-type") == 0) {
         #if U_ICU_VERSION_MAJOR_NUM >= 67
         const char *arg = Tcl_GetString(objv[i + 1]);
         if (strcmp(arg, "and") == 0) {
             type = ULISTFMT_TYPE_AND;
         } else if (strcmp(arg, "or") == 0) {
             type = ULISTFMT_TYPE_OR;
         } else if (strcmp(arg, "units") == 0) {
             type = ULISTFMT_TYPE_UNITS;
         } else {
             Tcl_SetResult(interp, "Invalid argument for -type", TCL_STATIC);
             return TCL_ERROR;
         }
         #endif
     } else if (strcmp(opt, "-width") == 0) {
         #if U_ICU_VERSION_MAJOR_NUM >= 67
         const char *arg = Tcl_GetString(objv[i + 1]);
         if (strcmp(arg, "wide") == 0) {
             width = ULISTFMT_WIDTH_WIDE;
         } else if (strcmp(arg, "short") == 0) {
             width = ULISTFMT_WIDTH_SHORT;
         } else if (strcmp(arg, "narrow") == 0) {
             width = ULISTFMT_WIDTH_NARROW;
         } else {
             Tcl_SetResult(interp, "Invalid argument for -width", TCL_STATIC);
             return TCL_ERROR;
         }
         #endif
     } else if (opt[0] == '-') {
         Tcl_SetResult(interp, "Unknown option", TCL_STATIC);
         return TCL_ERROR;
     } else {
         break;
     }
 }
    if (i != objc - 1) {
        Tcl_WrongNumArgs(interp, 1, objv,
                         "?-locale locale? ?-type and|or|units? ?-width wide|short|narrow? lst");
        return TCL_ERROR;
    }

    #if U_ICU_VERSION_MAJOR_NUM >= 67
    UListFormatter *fmt = ulistfmt_openForType(loc, type, width, &err);
    if (U_FAILURE(err)) {
        set_icu_error_result(interp, "ulistfmt_openForType", err);
        return TCL_ERROR;
    }
    #else
    UListFormatter *fmt = ulistfmt_open(loc, &err);
    if (U_FAILURE(err)) {
        set_icu_error_result(interp, "ulistfmt_open", err);
        return TCL_ERROR;
    }
    #endif

    int32_t llen;
    if (Tcl_ListObjLength(interp, objv[i], &llen) != TCL_OK) {
        ulistfmt_close(fmt);
        return TCL_ERROR;
    }
    const UChar **strings = (const UChar **)ckalloc(llen * sizeof(UChar *));
    int32_t *slens = (int32_t *)ckalloc(llen * sizeof(int32_t));
    int32_t totlen = 0;
    for (int n = 0; n < llen; n += 1)
    {
     Tcl_Obj *o;
     if (Tcl_ListObjIndex(interp, objv[i], n, &o) != TCL_OK) {
         ckfree((char *)strings);
         ckfree((char *)slens);
         ulistfmt_close(fmt);
         return TCL_ERROR;
     }
     strings[n] = Tcl_GetUnicodeFromObj(o, &slens[n]);
     totlen += slens[n];
    }
    totlen *= 2;
    totlen += 1;
    UChar *result = (UChar *)ckalloc(totlen * sizeof(UChar));
    int32_t rlen = ulistfmt_format(fmt, strings, slens, llen,
                                   result, totlen, &err);
    if (err == U_BUFFER_OVERFLOW_ERROR || rlen > totlen) {
        rlen += 1;
        result = (UChar *)ckrealloc(result, rlen * sizeof(UChar));
        totlen = rlen;
        err = U_ZERO_ERROR;
        rlen = ulistfmt_format(fmt, strings, slens, llen,
                               result, totlen, &err);
    }
    if (U_FAILURE(err)) {
        set_icu_error_result(interp, "ulistfmt_format", err);
        ckfree((char *)result);
        ckfree((char *)strings);
        ckfree((char *)slens);
        ulistfmt_close(fmt);
        return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_NewUnicodeObj(result, rlen));
    ckfree((char *)result);
    ckfree((char *)strings);
    ckfree((char *)slens);
    ulistfmt_close(fmt);
    return TCL_OK;
}

critcl::tsources icu_tcl_funcs.tcl

proc icu::_test {} {
    critcl::load
    puts "Using ICU $icu::icu_version and Unicode $icu::unicode_version"

    # Locales.
    puts "Default locale is [icu::locale get name [icu::locale default]] ([icu::locale get canonname])"
    puts "Language: [icu::locale get language] Script: [icu::locale get script]"
    puts "Variant: [icu::locale get variant] Country: [icu::locale get country]"
    puts "Read [icu::locale get character-orientation] and [icu::locale get line-orientation]"

    puts "Known languages: {[icu::format list [icu::locale languages]]}"
    puts "Known countries: {[icu::format list [icu::locale countries]]}"
    puts "Known locales: {[icu::format list [icu::locale list]]}"

    # String searching
    set pos [icu::string first_of food od]
    puts "pos $pos"
    set pos [icu::string first_of food xy]
    puts "pos $pos"
    set c [icu::string index abc 1]
    puts "c is >$c<"
    set c [icu::string index food 6]
    puts "c is >$c<"

    set s "rutabega"
    puts "range $s 0 3: [icu::string range $s 0 3]"
    puts "range $s 3 3: [icu::string range $s 3 3]"
    puts "range $s 7 20: [icu::string range $s 7 20]"

    # Case changes
    set s "fOoBaR \u0130I\u0131i"
    set uc_s [icu::string toupper $s]
    set lc_s [icu::string tolower $s]
    puts "uppercase $s: $uc_s"
    puts "lowercase $s: $lc_s"
    puts "turkish uppercase $s: [icu::string toupper -locale tr_TR $s]"
    puts "turkish lowercase $s: [icu::string tolower -locale tr_TR $s]"
    puts "titlecase $s: [icu::string totitle $s]"
    puts "casefolded $s: [icu::string foldcase $s]"
    puts "casefolded excluded $s: [icu::string foldcase -exclude-special-i $s]"

    # Normalization
    if {$::tcl_version >= 8.7} {
        set thugs {"𝖙𝖍𝖚𝖌 𝖑𝖎𝖋𝖊" "𝓽𝓱𝓾𝓰 𝓵𝓲𝓯𝓮" "𝓉𝒽𝓊𝑔 𝓁𝒾𝒻𝑒" "𝕥𝕙𝕦𝕘 𝕝𝕚𝕗𝕖"
            "ｔｈｕｇ ｌｉｆｅ"}
        set lif0 "𝖑𝖎𝖋"
        set pos [icu::string first $lif0 [lindex $thugs 0]]
        puts "Location of $lif0: $pos"
        puts "index: >[icu::string index [lindex $thugs 0] $pos]<"
    }
    lappend thugs "ｔｈｕｇ ｌｉｆｅ"
    set lif1 "ｌｉｆ"
    puts "Location of $lif1: [icu::string last $lif1 [lindex $thugs end]]"
    foreach thug $thugs {
        puts "string length {$thug} -> [::string length $thug]"
        puts "icu::string length {$thug} -> [icu::string length $thug]"
        puts "NFC: $thug [icu::string nfc "-> " $thug " represent"]"
        puts "NFD: $thug [icu::string nfd "-> " $thug " represent"]"
        puts "NFKC: $thug [icu::string nfkc "-> " $thug " represent"]"
        puts "NFKD: $thug [icu::string nfkd "-> " $thug " represent"]"
    }

    # Comparision
    puts "compare -nocase {$s} {$uc_s}: [icu::string compare -nocase $s $uc_s]"
    puts "compare -nocase -exclude-special-i {$s} {$uc_s}: [icu::string compare -exclude-special-i -nocase $s $uc_s]"
    puts "compare {$s} {$lc_s}: [icu::string compare $s $lc_s]"
    set s "FO\u00C9"
    set lc_s "foe\u0301"
    puts "compare -equivalence {$s} {$lc_s}: [icu::string compare -equivalence $s $lc_s]"
    puts "compare -equivalence -nocase {$s} {$lc_s}: [icu::string compare -equivalence -nocase $s $lc_s]"

    puts "is upper $s: [icu::string is upper $s]"
    puts "is upper -strict {}: [icu::string is upper -strict ""]"

    # collators
    set coll [icu::collator tr_TR]
    puts "coll name $coll and locale [$coll -locale]"
    puts "compare {$s} {$uc_s}: [$coll compare $s $uc_s]"
    rename $coll ""
    icu::collator myColl en_US
    puts "compare {$s} {$uc_s}: [myColl compare $s $uc_s]"

    # character stuff
    set acp [icu::char value A]
    puts "char value A: $acp"
    puts "char tochar $acp: [icu::char tochar $acp]"
    set name [icu::char name $acp]
    puts "char name $acp: $name"
    puts "char lookup {$name}: [icu::char lookup $name]"
    puts "char script $acp: [icu::char script $acp]"
    set cp [icu::char value \(]
    puts "char ismirrored \(: [icu::char is mirrored $cp]"
    puts "char mirrorchar \(: [icu::char tochar [icu::char mirrorchar $cp]]"
    puts "char pairedbracket \(: [icu::char tochar [icu::char pairedbracket $cp]]"
    set cp [icu::char value 9]
    puts "char decimal $cp: [icu::char decimal $cp]"
    puts "char digit $cp 16: [icu::char digit $cp 16]"
    puts "char number 0x00BC: [icu::char number 0x00BC]"

    # Breaks
    set s "Fee fie foe fum."
    foreach word [icu::string break words $s] {
        puts "{$word}"
    }

    set s "foe\u0301 man"
    foreach char [icu::string break characters $s] {
        puts "{$char}"
    }

    puts "{[icu::string break codepoints $s]}"

    set s "This is a sentence. And this is another. Finally a third."
    foreach sent [icu::string break sentences $s] {
        puts "{$sent}"
    }

    foreach line [icu::string break lines $s] {
        puts "{$line}"
    }
}

# If this is the main script...
if {[info exists argv0] &&
    ([file tail [info script]] eq [file tail $argv0])} {
    icu::_test
}

package provide icu 0.4
