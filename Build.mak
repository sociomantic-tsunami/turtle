export ALLOW_STOMPING_PREVENTION=0

override LDFLAGS += -lebtree -llzo2 -lrt -lpcre -lgcrypt -lgpg-error -lglib-2.0
override DFLAGS  += -w

# Enable coverage report in CI
ifdef CI
COVFLAG:=-cov
endif

$O/%unittests: override LDFLAGS += -lpcre

# dummy apps used in tests
$B/dummy_cli: $C/src/dummy_cli/main.d
$B/dummy_daemon: $C/src/dummy_daemon/main.d

$O/test-notrunning.stamp: $B/dummy_cli
$O/test-controlsocket.stamp: $B/dummy_daemon

# examples of turtle usage
$B/example-daemon: $C/example/daemon/main.d
$B/example-cli: $C/example/cli/main.d
$B/example-manual: $C/example/manual/main.d

all: $B/dummy_cli $B/dummy_daemon \
	$B/example-daemon $B/example-cli $B/example-manual

# suggested makefile idiom to quickly run turtle based test suite
# allows to benefit from all environment variables set by Makd and
# thus makes manual usage of --projdir and --topdir unnecessary
#
# any text passed via TURTLE_ARGS will be used as extra CLI arguments:
#     make run-example TURTLE_ARGS="--help"
#     make run-example TURTLE_ARGS="--id=7"
run-daemon-example: $B/example-daemon
	$(call exec, $B/example-daemon $(TURTLE_ARGS))

run-cli-example: $B/example-cli
	$(call exec, $B/example-cli $(TURTLE_ARGS))

# Enable coverage generation from unittests
$O/%unittests: override DFLAGS += $(COVFLAG)
