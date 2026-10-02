# ----------------------------
# Makefile Options
# ----------------------------

NAME = mc
ICON = icon.png
DESCRIPTION = "Midnight Commander look-alike"
COMPRESSED = NO
ARCHIVED = NO
RAM_START=0x40000
RAM_SIZE=0x50000
CFLAGS = -Werror -Wall -Wextra -Oz -DCEDEV
CXXFLAGS = -Werror -Wall -Wextra -Oz - DCEDEV
LDHAS_EXIT_HANDLER:=0
# ----------------------------

include $(shell agondev-config --makefile)

# hub's client library, from its hub-libs release (see hub/VERSION). After the
# include, which sets CFLAGS and PROJECTLIBDIR itself.
CFLAGS += -Ihub/include
PROJECTLIBDIR := hub/lib
LIBS := -lhub

