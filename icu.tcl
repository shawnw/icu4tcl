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

critcl::license {Shawn Wagner} {MIT license}

critcl::summary {TCL bindings to ICU}

critcl::description {This package exports ICU (International
Components For Unicode) functionality to Tcl to improve its unicode
handling capability.}

critcl::cflags {*}[exec icu-config --cflags]
critcl::ldflags {*}[exec icu-config --ldflags-searchpath]
critcl::clibraries {*}[exec icu-config --ldflags-libsonly]

namespace eval icu {
    variable version 0.1
    variable icu_version {}
    variable unicode_version {}

    namespace export {[a-z]*}
}

critcl::ccode {
    #include <unicode/uversion.h>
    #include <unicode/ustring.h>
    #include <unicode/ucol.h>
    #include <unicode/ubrk.h>
    #include <stdlib.h>
    #include <stdio.h>
    #include <string.h>
}

critcl::cinit {
    _Static_assert(sizeof(UChar) == sizeof(Tcl_UniChar),
                   "Tcl_UniChar and UChar sizes differ");
    Tcl_CreateNamespace(ip, "icu", NULL, NULL);
    Tcl_CreateNamespace(ip, "icu::string", NULL, NULL);
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
    _Bool nocase = 0;

    if (objc < 3 || objc > 5) {
        Tcl_WrongNumArgs(interp, 1, objv,
                         "?-nocase? ?-exclude-special-i? s1 s2");
        return TCL_ERROR;
    }

    while (idx < objc - 2) {
        const char *opt = Tcl_GetString(objv[idx++]);
        if (strcmp(opt, "-nocase") == 0) {
            nocase = 1;
        } else if (strcmp(opt, "-exclude-special-i") == 0) {
            options |= U_FOLD_CASE_EXCLUDE_SPECIAL_I;
        } else if (opt[0] == '-') {
            Tcl_SetResult(interp, "unknown option", TCL_STATIC);
            return TCL_ERROR;
        } else {
            Tcl_WrongNumArgs(interp, 1, objv,
                             "?-nocase? ?-exclude-special-i? s1 s2");
            return TCL_ERROR;
        }
    }

    uint32_t res;
    if (nocase) {
        UErrorCode err = U_ZERO_ERROR;
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
        Tcl_SetObjResult(interp, Tcl_NewIntObj(pos));
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
        Tcl_SetObjResult(interp, Tcl_NewIntObj(pos));
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
    dest = ckalloc(dest_capacity * sizeof(Tcl_UniChar));
    uint32_t dest_len = u_strFoldCase(dest, dest_capacity,
                                      Tcl_GetUnicode(objv[idx]), -1,
                                      options, &err);
    if (err == U_BUFFER_OVERFLOW_ERROR || dest_len > dest_capacity) {
        dest_capacity = dest_len + 1;
        dest = ckrealloc(dest, dest_capacity * sizeof(Tcl_UniChar));
        err = U_ZERO_ERROR;
        dest_len = u_strFoldCase(dest, dest_capacity,
                                 Tcl_GetUnicode(objv[idx]), -1,
                                 options, &err);
    }

    if (U_FAILURE(err)) {
        set_icu_error_result(interp, "u_strFoldCase", err);
        ckfree(dest);
        return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, Tcl_NewUnicodeObj(dest, dest_len));
    ckfree(dest);
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
    dest = ckalloc(dest_capacity * sizeof(Tcl_UniChar));

    uint32_t dest_len = u_strToUpper(dest, dest_capacity,
                                     Tcl_GetUnicode(objv[idx]), -1,
                                     loc, &err);
    if (err == U_BUFFER_OVERFLOW_ERROR || dest_len > dest_capacity) {
        dest_capacity = dest_len + 1;
        dest = ckrealloc(dest, dest_capacity * sizeof(Tcl_UniChar));
        err = U_ZERO_ERROR;
        dest_len = u_strToUpper(dest, dest_capacity,
                                Tcl_GetUnicode(objv[idx]), -1,
                                loc, &err);
    }

    if (U_FAILURE(err)) {
        set_icu_error_result(interp, "u_strToUpper", err);
        ckfree(dest);
        return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, Tcl_NewUnicodeObj(dest, dest_len));
    ckfree(dest);
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
    dest = ckalloc(dest_capacity * sizeof(Tcl_UniChar));

    uint32_t dest_len = u_strToLower(dest, dest_capacity,
                                     Tcl_GetUnicode(objv[idx]), -1,
                                     loc, &err);
    if (err == U_BUFFER_OVERFLOW_ERROR || dest_len > dest_capacity) {
        dest_capacity = dest_len + 1;
        dest = ckrealloc(dest, dest_capacity * sizeof(Tcl_UniChar));
        err = U_ZERO_ERROR;
        dest_len = u_strToLower(dest, dest_capacity,
                                Tcl_GetUnicode(objv[idx]), -1,
                                loc, &err);
    }

    if (U_FAILURE(err)) {
        set_icu_error_result(interp, "u_strToLower", err);
        ckfree(dest);
        return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, Tcl_NewUnicodeObj(dest, dest_len));
    ckfree(dest);
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
    dest = ckalloc(dest_capacity * sizeof(Tcl_UniChar));

    uint32_t dest_len = u_strToTitle(dest, dest_capacity,
                                     Tcl_GetUnicode(objv[idx]), -1,
                                     NULL, loc, &err);
    if (err == U_BUFFER_OVERFLOW_ERROR || dest_len > dest_capacity) {
        dest_capacity = dest_len + 1;
        dest = ckrealloc(dest, dest_capacity * sizeof(Tcl_UniChar));
        err = U_ZERO_ERROR;
        dest_len = u_strToTitle(dest, dest_capacity,
                                Tcl_GetUnicode(objv[idx]), -1,
                                NULL, loc, &err);
    }

    if (U_FAILURE(err)) {
        set_icu_error_result(interp, "u_strToTitle", err);
        ckfree(dest);
        return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, Tcl_NewUnicodeObj(dest, dest_len));
    ckfree(dest);
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
      if (objc != 3) {
          Tcl_WrongNumArgs(interp, 1, objv, "string string");
          return TCL_ERROR;
      }
      int res;
      switch (ucol_strcoll((UCollator *)cd, Tcl_GetUnicode(objv[1]), -1,
                                            Tcl_GetUnicode(objv[2]), -1)) {
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
    }
}

critcl::ccommand icu::collator {cdata interp objc objv} {
    static int counter = 1;
    char *name = NULL;
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
        snprintf(name, len + 1, "%s::collator%d", ns, counter);
        counter += 1;
    }
    Tcl_CreateObjCommand(interp, name, do_collator, coll, free_collator);
    if (objc == 2) {
        Tcl_SetResult(interp, name, Tcl_Free);
    } else {
        Tcl_SetObjResult(interp, objv[1]);
    }
    return TCL_OK;
}

namespace eval icu::string {
    namespace export {[a-zA-Z]*}
    namespace ensemble create
}

proc icu::test {} {
    critcl::load
    puts "Using $icu::icu_version and $icu::unicode_version"
    set pos [icu::string first_of food od]
    puts "pos $pos"
    set pos [icu::string first_of food xy]
    puts "pos $pos"

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


    # Comparision
    puts "compare -nocase {$s} {$uc_s}: [icu::string compare -nocase $s $uc_s]"
    puts "compare -nocase -exclude-special-i {$s} {$uc_s}: [icu::string compare -exclude-special-i -nocase $s $uc_s]"
    puts "compare {$s} {$lc_s}: [icu::string compare $s $lc_s]"

    # collators
    set coll [icu::collator tr_TR]
    puts "coll name $coll and locale [$coll -locale]"
    puts "compare {$s} {$uc_s}: [$coll $s $uc_s]"
    rename $coll ""
    icu::collator myColl en_US
    puts "compare {$s} {$uc_s}: [myColl $s $uc_s]"

}

# If this is the main script...
if {[info exists argv0] &&
    ([file tail [info script]] eq [file tail $argv0])} {
    icu::test
}

package provide icu $icu::version
