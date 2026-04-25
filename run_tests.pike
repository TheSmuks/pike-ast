//! PikeAst test runner.
//!
//! @code
//! pike path/to/pmp/bin/pmp.pike run run_tests.pike tests/
//! @endcode

int main(int argc, array(string) argv) {
  mapping options = ([]);
  array(string) tags = ({});
  array(string) exclude_tags = ({});

  array opts = Getopt.find_all_options(argv, ({
    ({"verbose",   Getopt.NO_ARG,       ({"-v", "--verbose"}),          "VERBOSE", 0}),
    ({"stop",      Getopt.NO_ARG,       ({"-s", "--stop-on-failure"}),  "STOP", 0}),
    ({"no_color",  Getopt.NO_ARG,       ({"--no-color"}),               "NO_COLOR", 0}),
    ({"junit",     Getopt.HAS_ARG,      ({"--junit"}),                  "JUNIT", 0}),
    ({"tag",       Getopt.HAS_ARG,      ({"-t", "--tag"}),             "TAG", 0}),
    ({"exclude",   Getopt.HAS_ARG,      ({"-e", "--exclude-tag"}),     "EXCLUDE", 0}),
    ({"filter",    Getopt.HAS_ARG,      ({"-f", "--filter"}),          "FILTER", 0}),
    ({"list",      Getopt.MAY_HAVE_ARG, ({"--list"}),                   "LIST", 0}),
    ({"strict",    Getopt.NO_ARG,       ({"--strict"}),                 "STRICT", 0}),
    ({"tap",       Getopt.NO_ARG,       ({"--tap"}),                    "TAP", 0}),
    ({"retry",     Getopt.HAS_ARG,      ({"--retry"}),                  "RETRY", 0}),
    ({"timeout",   Getopt.HAS_ARG,      ({"--timeout"}),                "TIMEOUT", 0}),
    ({"randomize", Getopt.NO_ARG,       ({"--randomize"}),              "RANDOMIZE", 0}),
    ({"seed",      Getopt.HAS_ARG,      ({"--seed"}),                   "SEED", 0}),
    ({"version",   Getopt.NO_ARG,       ({"--version"}),                "VERSION", 0}),
    ({"help",      Getopt.NO_ARG,       ({"-h", "--help"}),            "HELP", 0}),
  }));

  foreach (opts; ; array opt) {
    switch (opt[0]) {
      case "verbose":  options->verbose = 1; break;
      case "stop":     options->stop_on_failure = 1; break;
      case "no_color": options->no_color = 1; break;
      case "junit":    options->junit = opt[1]; break;
      case "tag":       tags += ({ opt[1] }); break;
      case "exclude":   exclude_tags += ({ opt[1] }); break;
      case "filter":    options->filter = opt[1]; break;
      case "list":
        options->list_only = 1;
        if (opt[1] == "verbose") options->list_verbose = 1;
        break;
      case "strict":    options->strict = 1; break;
      case "tap":       options->tap = 1; break;
      case "retry":     options->retry = (int)opt[1]; break;
      case "timeout":   options->timeout = (int)opt[1]; break;
      case "randomize": options->randomize = 1; break;
      case "seed":      options->seed = (int)opt[1]; break;
      case "version":
        write("PikeAst " + PikeAst.PIKE_AST_VERSION + "\n");
        return 0;
      case "help":
        _usage();
        return 0;
    }
  }

  options->tags = tags;
  options->exclude_tags = exclude_tags;

  array(string) paths = Getopt.get_args(argv)[1..];

  object runner = PUnit.TestRunner(options);
  int exit_code = runner->run(paths);

  return exit_code;
}

void _usage() {
  write("Usage: pike run_tests.pike [options] <directories...>\n"
        "\n"
        "Options:\n"
        "  -v, --verbose          Show each test name with status\n"
        "  -t, --tag=TAG          Run only tests with this tag\n"
        "  -e, --exclude-tag=TAG  Skip tests with this tag\n"
        "  -f, --filter=GLOB      Run only test methods matching glob\n"
        "  -s, --stop-on-failure  Stop after first failure\n"
        "  --list                 List test names without running\n"
        "  --strict               Treat validation warnings as errors\n"
        "  --no-color             Disable ANSI colors\n"
        "  --timeout=N            Per-test timeout in seconds\n"
        "  --retry=N              Retry failed tests up to N times\n"
        "  --randomize            Run tests in random order\n"
        "  --seed=N               Random seed for --randomize\n"
        "  --junit=FILE           Write JUnit XML report to FILE\n"
        "  --tap                  Output TAP v13 to stdout\n"
        "  --version              Show version and exit\n"
        "  -h, --help             Show this help\n"
        "\n"
        "Exit code: 0 if all pass, 1 if any failure.\n");
}
