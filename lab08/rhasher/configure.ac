AC_PREREQ([2.69])
AC_INIT([lab08-rhasher],[1.0],[https://github.com/Dimasos88/altpkg-streltsov/issues])
AC_CONFIG_SRCDIR([hash.c])
AC_CONFIG_HEADERS([config.h])
AM_INIT_AUTOMAKE([foreign])
AC_PROG_CC
AC_CHECK_LIB([rhash],[rhash_init],[RHASH_LIBS="-lrhash"],[AC_MSG_ERROR([librhash development library is required])])
AC_CHECK_HEADER([rhash.h],[],[AC_MSG_ERROR([rhash.h is required])])
AC_ARG_WITH([readline],[AS_HELP_STRING([--without-readline],[force getline])],[],[with_readline=auto])
AS_IF([test "x$with_readline" != xno],[
  AC_CHECK_HEADER([readline/readline.h],[
    AC_CHECK_LIB([readline],[readline],[READLINE_LIBS="-lreadline"
      AC_DEFINE([USE_READLINE],[1],[Enable GNU Readline])],[])
  ])
])
AC_SUBST([RHASH_LIBS])
AC_SUBST([READLINE_LIBS])
AC_CONFIG_FILES([Makefile])
AC_OUTPUT
