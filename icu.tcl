package require Tcl 8.6
package require critcl

if {![critcl::compiling]} {
    error "This extension cannot be compiled without critcl enabled"
}

critcl::cflags {*}[exec icu-config --cflags]
critcl::ldflags {*}[exec icu-config --ldflags-searchpath]
critcl::clibraries {*}[exec icu-config --ldflags-libsonly]

namespace eval icu {
    variable version 0.1
    variable icu_version {}

    namespace export {[a-z]*}
}

critcl::ccode {
    #include <unicode/uversion.h>
    #include <unicode/ustring.h>
    #include <unicode/ucol.h>
    #include <stdlib.h>
    #include <stdio.h>
    #include <string.h>
}

critcl::cinit {
    Tcl_CreateNamespace(ip, "icu", NULL, NULL);
    Tcl_CreateNamespace(ip, "icu::string", NULL, NULL);
    Tcl_SetVar2Ex(ip, "icu::icu_version", NULL, Tcl_NewStringObj(U_ICU_VERSION, -1), 0);
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
    Tcl_SetObjResult(interp, Tcl_NewIntObj(u_countChar32(Tcl_GetUnicode(objv[1]), -1)));
    return TCL_OK;
}

# Return the index of the first codepoint in string that is included in characters.
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

critcl::ccode {
    static void free_collator(ClientData cd) {
        ucol_close((UCollator *)cd);
    }

    static int do_collator(ClientData cd, Tcl_Interp *interp, int objc,
                           Tcl_Obj * const objv[]) {
       if (objc == 2 && strcmp(Tcl_GetString(objv[1]), "-locale") == 0) {
          UErrorCode err = U_ZERO_ERROR;
          const char *name = ucol_getLocaleByType((UCollator *)cd, ULOC_ACTUAL_LOCALE,
                                                  &err);
          if (U_FAILURE(err)) {
               set_icu_error_result(interp, "Unable to get collation locale", err);
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
    puts "Using $icu::icu_version"
    set pos [icu::string first_of food od]
    puts "pos $pos"
    set pos [icu::string first_of food xy]
    puts "pos $pos"
    set coll [icu::collator en_US]
    puts "coll name $coll"
    puts "compare foo bar: [$coll foo bar]"
    puts "collator locale: [$coll -locale]"
    rename $coll ""
    icu::collator myColl en_US
    puts "compare bar foo: [myColl bar foo]"
}

# If this is the main script...
if {[info exists argv0] && ([file tail [info script]] eq [file tail $argv0])} {
    icu::test
}

package provide icu $icu::version
