savedcmd_rex_test.mod := printf '%s\n'   rex_test.o | awk '!x[$$0]++ { print("./"$$0) }' > rex_test.mod
