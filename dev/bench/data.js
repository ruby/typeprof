window.BENCHMARK_DATA = {
  "lastUpdate": 1788922787045,
  "repoUrl": "https://github.com/ruby/typeprof",
  "entries": {
    "Analysis time": [
      {
        "commit": {
          "author": {
            "email": "sinsoku.listy@gmail.com",
            "name": "Takumi Shotoku",
            "username": "sinsoku"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "62c7d8d9cd6d407d8e62c8b685d3866dff6e7749",
          "message": "Add a benchmark workflow for real-world projects (#449)\n\nThe scenario tests only cover small inputs, so nothing caught a change\nthat slowed the analysis down or dropped type coverage on real code.\nTrack both over time, so that a gradual regression is visible.\n\nThe same script runs on pull requests, where only a crash or a hang\nfails the job. It replaces the dog bench step, which analyzed only\nTypeProf's own source; tool/dog_bench.rb stays for ad-hoc profiling.",
          "timestamp": "2026-09-01T19:38:51+09:00",
          "tree_id": "da6224576cbd4f6afddd430f6f1437a669106009",
          "url": "https://github.com/ruby/typeprof/commit/62c7d8d9cd6d407d8e62c8b685d3866dff6e7749"
        },
        "date": 1788259246159,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 3.93,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 2.73,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 15.11,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 70.89,
            "unit": "s"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "sinsoku.listy@gmail.com",
            "name": "Takumi Shotoku",
            "username": "sinsoku"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "1eef91dff8e1aff2050edb8c466cb07b888d7ce8",
          "message": "Bump version to v0.33.0 (#475)",
          "timestamp": "2026-09-03T23:48:35+09:00",
          "tree_id": "1f15a0d158cd5f960c5de1c584fefea2dd0a83c1",
          "url": "https://github.com/ruby/typeprof/commit/1eef91dff8e1aff2050edb8c466cb07b888d7ce8"
        },
        "date": 1788447042214,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 4.38,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.18,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 17.62,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 78.51,
            "unit": "s"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "51983447+ahogappa@users.noreply.github.com",
            "name": "ahogappa",
            "username": "ahogappa"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "7d668de074014fa08c2e4aa295a8d450adafb19c",
          "message": "Accept a Prism::ParseResult as input in place of Ruby source text (#476)\n\nService#update_rb_ast(path, parse_result) analyzes a Ruby file from a\nPrism::ParseResult that the caller has already produced. The path plays\nthe same role as before: it identifies the file, and re-submitting the\nsame path replaces the previous analysis with a diff against it.\nupdate_rb_file now reads and parses, then delegates to it.\n\nAST.parse_rb is split so the Prism.parse call is separate from building\nthe ProgramNode (AST.build_rb). A ParseResult is required rather than a\nbare Prism node because comments (`#:` annotations, `typeprof:ignore`)\nand the Prism::Source used for position encoding are only reachable\nthrough it.\n\n\nClaude-Session: https://claude.ai/code/session_01KHWGVBXpPwoYJ5QsDHLMro\n\nCo-authored-by: Claude <noreply@anthropic.com>",
          "timestamp": "2026-09-07T23:27:07+09:00",
          "tree_id": "d12cd82a72416cefd78968ffd7dbb44290e668c6",
          "url": "https://github.com/ruby/typeprof/commit/7d668de074014fa08c2e4aa295a8d450adafb19c"
        },
        "date": 1788791348736,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 4.55,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.13,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 17.84,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 81.64,
            "unit": "s"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "sinsoku.listy@gmail.com",
            "name": "Takumi Shotoku",
            "username": "sinsoku"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "9eb87fbd5ea914263e50cb77daa9464f29c79aef",
          "message": "Resolve type variables of a reopened declaration by position (#477)\n\n* Resolve type variables of a reopened declaration by position\n\nRBS 4.1 renamed the core's type parameters, e.g. `Array[Elem]` to\n`Array[E]`, but RBS files in rbs collections (activesupport, the rbs gem's\nown shims) still reopen them as `Array[Elem]`, which RBS allows. TypeProf\nlooked up type variables only by the names of the first declaration, so\nusing it with such a collection crashed with \"unknown type variable:\nElem\". Let SigTyVarNode fall back to the name at the same position in the\nmodule entity, which also makes the shim workaround in 91bd108a\nunnecessary.\n\n* Resolve a declaration's type parameters by position only\r\n\r\nTrying the name first got `class Hash[V, K]; def key_of: () -> V` wrong\r\nwhen the reopened declaration swaps the names.\n\nCo-authored-by: Yusuke Endoh <mame@ruby-lang.org>\n\n---------\n\nCo-authored-by: Yusuke Endoh <mame@ruby-lang.org>",
          "timestamp": "2026-09-09T11:57:31+09:00",
          "tree_id": "08a0d80cd1e003e5c415d6959c7f300cb4a461ba",
          "url": "https://github.com/ruby/typeprof/commit/9eb87fbd5ea914263e50cb77daa9464f29c79aef"
        },
        "date": 1788922785036,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 5.03,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.6,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 23.09,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 86.05,
            "unit": "s"
          }
        ]
      }
    ],
    "Type coverage": [
      {
        "commit": {
          "author": {
            "email": "sinsoku.listy@gmail.com",
            "name": "Takumi Shotoku",
            "username": "sinsoku"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "62c7d8d9cd6d407d8e62c8b685d3866dff6e7749",
          "message": "Add a benchmark workflow for real-world projects (#449)\n\nThe scenario tests only cover small inputs, so nothing caught a change\nthat slowed the analysis down or dropped type coverage on real code.\nTrack both over time, so that a gradual regression is visible.\n\nThe same script runs on pull requests, where only a crash or a hang\nfails the job. It replaces the dog bench step, which analyzed only\nTypeProf's own source; tool/dog_bench.rb stays for ad-hoc profiling.",
          "timestamp": "2026-09-01T19:38:51+09:00",
          "tree_id": "da6224576cbd4f6afddd430f6f1437a669106009",
          "url": "https://github.com/ruby/typeprof/commit/62c7d8d9cd6d407d8e62c8b685d3866dff6e7749"
        },
        "date": 1788259248536,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 78.56,
            "unit": "%"
          },
          {
            "name": "optcarrot",
            "value": 86.49,
            "unit": "%"
          },
          {
            "name": "rubygems.org",
            "value": 31.37,
            "unit": "%"
          },
          {
            "name": "redmine",
            "value": 35.61,
            "unit": "%"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "sinsoku.listy@gmail.com",
            "name": "Takumi Shotoku",
            "username": "sinsoku"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "1eef91dff8e1aff2050edb8c466cb07b888d7ce8",
          "message": "Bump version to v0.33.0 (#475)",
          "timestamp": "2026-09-03T23:48:35+09:00",
          "tree_id": "1f15a0d158cd5f960c5de1c584fefea2dd0a83c1",
          "url": "https://github.com/ruby/typeprof/commit/1eef91dff8e1aff2050edb8c466cb07b888d7ce8"
        },
        "date": 1788447044701,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 78.56,
            "unit": "%"
          },
          {
            "name": "optcarrot",
            "value": 86.49,
            "unit": "%"
          },
          {
            "name": "rubygems.org",
            "value": 31.37,
            "unit": "%"
          },
          {
            "name": "redmine",
            "value": 35.61,
            "unit": "%"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "51983447+ahogappa@users.noreply.github.com",
            "name": "ahogappa",
            "username": "ahogappa"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "7d668de074014fa08c2e4aa295a8d450adafb19c",
          "message": "Accept a Prism::ParseResult as input in place of Ruby source text (#476)\n\nService#update_rb_ast(path, parse_result) analyzes a Ruby file from a\nPrism::ParseResult that the caller has already produced. The path plays\nthe same role as before: it identifies the file, and re-submitting the\nsame path replaces the previous analysis with a diff against it.\nupdate_rb_file now reads and parses, then delegates to it.\n\nAST.parse_rb is split so the Prism.parse call is separate from building\nthe ProgramNode (AST.build_rb). A ParseResult is required rather than a\nbare Prism node because comments (`#:` annotations, `typeprof:ignore`)\nand the Prism::Source used for position encoding are only reachable\nthrough it.\n\n\nClaude-Session: https://claude.ai/code/session_01KHWGVBXpPwoYJ5QsDHLMro\n\nCo-authored-by: Claude <noreply@anthropic.com>",
          "timestamp": "2026-09-07T23:27:07+09:00",
          "tree_id": "d12cd82a72416cefd78968ffd7dbb44290e668c6",
          "url": "https://github.com/ruby/typeprof/commit/7d668de074014fa08c2e4aa295a8d450adafb19c"
        },
        "date": 1788791350504,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 78.56,
            "unit": "%"
          },
          {
            "name": "optcarrot",
            "value": 86.49,
            "unit": "%"
          },
          {
            "name": "rubygems.org",
            "value": 31.37,
            "unit": "%"
          },
          {
            "name": "redmine",
            "value": 35.61,
            "unit": "%"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "sinsoku.listy@gmail.com",
            "name": "Takumi Shotoku",
            "username": "sinsoku"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "9eb87fbd5ea914263e50cb77daa9464f29c79aef",
          "message": "Resolve type variables of a reopened declaration by position (#477)\n\n* Resolve type variables of a reopened declaration by position\n\nRBS 4.1 renamed the core's type parameters, e.g. `Array[Elem]` to\n`Array[E]`, but RBS files in rbs collections (activesupport, the rbs gem's\nown shims) still reopen them as `Array[Elem]`, which RBS allows. TypeProf\nlooked up type variables only by the names of the first declaration, so\nusing it with such a collection crashed with \"unknown type variable:\nElem\". Let SigTyVarNode fall back to the name at the same position in the\nmodule entity, which also makes the shim workaround in 91bd108a\nunnecessary.\n\n* Resolve a declaration's type parameters by position only\r\n\r\nTrying the name first got `class Hash[V, K]; def key_of: () -> V` wrong\r\nwhen the reopened declaration swaps the names.\n\nCo-authored-by: Yusuke Endoh <mame@ruby-lang.org>\n\n---------\n\nCo-authored-by: Yusuke Endoh <mame@ruby-lang.org>",
          "timestamp": "2026-09-09T11:57:31+09:00",
          "tree_id": "08a0d80cd1e003e5c415d6959c7f300cb4a461ba",
          "url": "https://github.com/ruby/typeprof/commit/9eb87fbd5ea914263e50cb77daa9464f29c79aef"
        },
        "date": 1788922786695,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 78.56,
            "unit": "%"
          },
          {
            "name": "optcarrot",
            "value": 86.49,
            "unit": "%"
          },
          {
            "name": "rubygems.org",
            "value": 31.37,
            "unit": "%"
          },
          {
            "name": "redmine",
            "value": 35.61,
            "unit": "%"
          }
        ]
      }
    ]
  }
}