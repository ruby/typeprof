window.BENCHMARK_DATA = {
  "lastUpdate": 1790601882426,
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
          "id": "27eaeda533b59ce260a66ae9cf1a727bd1d7c325",
          "message": "Bump version to v0.33.1 (#478)",
          "timestamp": "2026-09-09T12:08:12+09:00",
          "tree_id": "b7cc4f58ae1b9657216d19ef2fc60a1777ad1df4",
          "url": "https://github.com/ruby/typeprof/commit/27eaeda533b59ce260a66ae9cf1a727bd1d7c325"
        },
        "date": 1788923431382,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 4.7,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.34,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 21.16,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 87.96,
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
          "id": "68f047980980345ca600df4b4ba9779a565ced6d",
          "message": "Give the RBS instance type its type arguments (#480)\n\nType.default_param_map built the `*instance` entry with an empty argument\nlist, so a singleton method declared to return `instance` lost its type\narguments, and crashed when that result reached a type variable check\n(SigTyVarNode#typecheck got nil instead of an actual argument). After\nbase_type the receiver is always an Instance or a Singleton, so\nget_instance_type is always defined.\n\n    table = Hash[[[\"a\", \"b\"]]]  # Hash.[] is declared as `-> instance`\n    \"foo\".gsub(/o/, table)      # gsub takes `hash[String, _ToS]`",
          "timestamp": "2026-09-12T13:35:34+09:00",
          "tree_id": "f28ba924cf9b4c7917d8e2ba8f9030e18defb4d4",
          "url": "https://github.com/ruby/typeprof/commit/68f047980980345ca600df4b4ba9779a565ced6d"
        },
        "date": 1789187850874,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 4.22,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.03,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 17.51,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 78.24,
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
          "id": "74f9bd8038caaeb29b9ecf7176998f5008afade1",
          "message": "Analyze the body of a lambda literal (#481)\n\n* Extract block handling from CallBaseNode into BlockNode\n\nThe parsing of block parameters, the block-local scope, and the\ninstallation of the block body lived inside CallBaseNode. Nothing there\ndepends on being a call, and a lambda literal needs exactly the same\nhandling without being a call, so it moves into its own node that a call\nholds as a subnode. Block parameters now go through AST.parse_params and\nmulti-target binding through a shared Node helper, both of which DefNode\nalready used for the same job.\n\nEvery node now answers ret_code_range, so the escape box no longer picks\na code-range method by node class; a body-bearing node points at its\nlast statement, the rest at themselves. A diagnostic on an empty block\ntherefore points at the block instead of the whole call, and a block on\n`super do ... end` no longer falls through to a debug `pp`.\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>\n\n* Analyze the body of a lambda literal\n\n`-> {}` was a stub that produced a bare Proc and never looked inside, so\nmethod calls in the body got no diagnostics, classes and methods defined\nthere were not registered, and parameters were untyped. `lambda {}` had\nnone of these gaps because it goes through the block handling of a call.\n\nLambdaNode is a BlockNode: a lambda literal builds its scope, parameters\nand body exactly like a block. It is not modeled as a `lambda` call\nbecause `->` is syntax and must not dispatch to a user-defined `lambda`\nmethod.\n\nWhere a lambda differs from a block is how the body leaves. A block's\n`return` exits the enclosing method and its `break` exits the method\nthat yielded; a lambda's `return` and `break` both exit the lambda, so\nits body gets its own return boxes and all three escapes join the value\nthe caller of #call receives.\n\nCo-Authored-By: Claude Opus 5 <noreply@anthropic.com>\n\n* Bind the arguments of a lambda call like a method's\n\nA lambda literal carried a Block, which models what a yielding method\nhands to a block: positionals only. So a lambda whose parameters a block\ncannot express — rest, post, keywords — bound nothing, and the body read\nthose parameters as nil. Its arity was not checked either, and a sole\narray argument was deconstructed over the parameters the way a block\ndeconstructs one, which a lambda does not do.\n\nA lambda is entered like a method, so it now carries the formals a method\ncarries and Proc#call binds against them. The binding itself is the one\na method definition already used: pass_arguments moves off MethodDefBox\nonto FormalArguments, which is what both now hold.\n\nProc#call already received the whole ActualArguments and passed on only\nthe positionals, so the keywords and splat flags were there all along.\n\nCo-Authored-By: Claude Opus 5 <noreply@anthropic.com>\n\n* Handle a block parameter list ending in a comma\n\nExtracting the block parameters into BlockNode routed them through\nparse_params, which reads the rest parameter. The previous block-only\ncode read just the requireds and the optionals, so it never met the node\n`{ |a,| }` puts there: Prism::ImplicitRestNode, which has no #name.\n\nA trailing comma is the only way to write a rest without naming it in a\nblock, and it cannot appear in a method definition or a lambda literal,\nwhere it is a syntax error.\n\nCo-Authored-By: Claude Opus 5 <noreply@anthropic.com>\n\n---------\n\nCo-authored-by: Claude <noreply@anthropic.com>",
          "timestamp": "2026-09-23T14:59:59+09:00",
          "tree_id": "7d022aa0539a6421a4c42331bf51f9cac6262007",
          "url": "https://github.com/ruby/typeprof/commit/74f9bd8038caaeb29b9ecf7176998f5008afade1"
        },
        "date": 1790143326020,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 4.56,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.04,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 19.85,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 80.53,
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
          "id": "92876451f5efa8651fe9c1b24f82fb72db8d2bd3",
          "message": "Fix nested destructuring after a splat in multiple assignment (#482)\n\nMultiWriteNode#install0 collected the targets after the splat by their\nown `ret` instead of the vertex behind their DummyRHSNode. A nested\ntarget (MultiTargetNode) has a nil `ret`, which blew up as the\ndestination of a graph edge in the next reinstall. The same mistake hit\nan index or attribute writer silently: it got the return vertex of its\nown call, so the assigned value never reached it.\n\n    *a, (b, c) = 1, 2, [3, 4]\n    #=> undefined method 'on_type_added' for nil",
          "timestamp": "2026-09-23T15:09:16+09:00",
          "tree_id": "7a5b881b4bbd3e575e9b7ec061eae8923c1c5cc8",
          "url": "https://github.com/ruby/typeprof/commit/92876451f5efa8651fe9c1b24f82fb72db8d2bd3"
        },
        "date": 1790143889624,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 4.42,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.14,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 20.32,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 86.81,
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
          "id": "0d4edb438bfc5412b3bdc4e600938ad1f9f0992e",
          "message": "Support an unless guard in a pattern (#483)\n\nAST.create_pattern_node routed a guard to IfPatternNode only for\n:if_node, so `in pat unless cond` raised \"unknown pattern node type:\nunless_node\". IfPatternNode reads only the predicate and the guarded\npattern, so an unless guard needs no node of its own; only the sanity\ncheck differs, because Prism names the else slot `subsequent` on IfNode\nand `else_clause` on UnlessNode.",
          "timestamp": "2026-09-23T15:15:21+09:00",
          "tree_id": "9bdef8d4f893003ab8c3002cc56739794092f081",
          "url": "https://github.com/ruby/typeprof/commit/0d4edb438bfc5412b3bdc4e600938ad1f9f0992e"
        },
        "date": 1790144258566,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 5.09,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.17,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 19.64,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 88.65,
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
          "id": "9f28445a992317df2463a1d8cd51b2b26cbe5d11",
          "message": "Support a lambda pattern (#485)\n\n`in ->(x) { ... }` matches by `===`, but AST.create_pattern_node had no\nbranch for :lambda_node and raised \"unknown pattern node type:\nlambda_node\". Route it through the same install_pattern0 path as the\nother value patterns; CaseMatchNode#install0 discards the pattern's\nreturn value, so returning a proc instead of the subject is harmless.\nThe subject is not passed to the lambda, so its parameter stays untyped\nand the body is not checked against the matched value.",
          "timestamp": "2026-09-23T15:19:45+09:00",
          "tree_id": "66c14075983bb73a0b4aa868b64d90a7afa1c3a7",
          "url": "https://github.com/ruby/typeprof/commit/9f28445a992317df2463a1d8cd51b2b26cbe5d11"
        },
        "date": 1790144492815,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 3.61,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 2.42,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 16.78,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 68.68,
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
          "id": "0b54714c1e7cdfa8a83009716d5361643809e55f",
          "message": "Support BEGIN blocks (#486)\n\n`BEGIN { ... }` raised \"not supported yet: pre_execution_node\" and\naborted the whole run, unlike `END { ... }`, which was already\nsupported. BEGIN now shares its implementation with END but is installed\nbefore the surrounding statements instead of after, so a method or a\nlocal variable it defines reaches the statements that follow.",
          "timestamp": "2026-09-23T15:23:17+09:00",
          "tree_id": "fb02b95150f19fbff6525ffc65bfda8eba78cbf2",
          "url": "https://github.com/ruby/typeprof/commit/0b54714c1e7cdfa8a83009716d5361643809e55f"
        },
        "date": 1790144720324,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 4.41,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.02,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 19.78,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 77.08,
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
          "id": "84485681841ca476b980ad3c8cb04564aedc527a",
          "message": "Push benchmark results to gh-pages in a single push (#488)\n\nEach store step pushed to gh-pages, so GitHub Pages was deployed twice\nper run and the first deployment was always cancelled.",
          "timestamp": "2026-09-26T11:56:23+09:00",
          "tree_id": "29eb5aa18b217d8356b736fba067d6f6997b1803",
          "url": "https://github.com/ruby/typeprof/commit/84485681841ca476b980ad3c8cb04564aedc527a"
        },
        "date": 1790391514535,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 4.35,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.09,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 20.93,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 84.76,
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
          "id": "d55c0b3efe4898dc66b397d96a126c869aa9c081",
          "message": "Analyze the benchmark projects with the RBS of their gems (#487)\n\nThe projects were analyzed with `--no-collection`, so every library\nthey use was untyped. Installing their gems and the matching RBS makes\nthe numbers reflect the way TypeProf is used on a real project, at the\ncost of a longer analysis.\n\nThe gem versions and the RBS collection are pinned to a fixed date so\nthat runs stay comparable. Bundler's cooldown does the pinning, which\navoids keeping a lockfile per project in this repository.\n\nBoth workflows run the benchmark on the same Ruby, so that the gems\ninstalled for one of them can be restored by the other.",
          "timestamp": "2026-09-26T12:00:54+09:00",
          "tree_id": "b7a9f6239d41dd90d9240ffd756c7a91f49b0e4a",
          "url": "https://github.com/ruby/typeprof/commit/d55c0b3efe4898dc66b397d96a126c869aa9c081"
        },
        "date": 1790392100901,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 5.28,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 4.49,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 103.86,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 181.65,
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
          "id": "22d6b89edcbe5d7b8230e0b372afe41b6ee57719",
          "message": "Report super outside a method instead of crashing (#484)\n\nOnly a method definition sets lenv.forward_args, which a bare `super`\nshares with `...` forwarding, so `define_method(:foo) { |x| super }` ran\na bare `raise` and surfaced as a RuntimeError with no message. Report a\ndiagnostic instead and treat the call as taking no arguments. Ruby's own\nwording differs by context, an implicit argument passing error from\ndefine_method and \"super called outside of method\" at the top level, and\nTypeProf only knows that forward_args is missing, so the message quotes\nneither.",
          "timestamp": "2026-09-26T13:11:47+09:00",
          "tree_id": "0fbb34affb902295a3e3eee0fb2b7350b57b3e53",
          "url": "https://github.com/ruby/typeprof/commit/22d6b89edcbe5d7b8230e0b372afe41b6ee57719"
        },
        "date": 1790396181856,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 5.05,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.96,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 79.01,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 142.96,
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
          "id": "3125e3127f413280a423ebdfd1d1f69ea6bc93b7",
          "message": "Skip the subclass method lookup for calls on Object (#489)\n\nTop-level calls like `get` in Rails routes passed their arguments to\nunrelated methods such as Faraday's `get`, and walking every class on\neach call made the analysis of large projects like rubygems.org much\nslower.",
          "timestamp": "2026-09-27T02:31:25+09:00",
          "tree_id": "18b0c8ddc82c4bc5586b626f085859be6b12f65b",
          "url": "https://github.com/ruby/typeprof/commit/3125e3127f413280a423ebdfd1d1f69ea6bc93b7"
        },
        "date": 1790444043789,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 4.62,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.71,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 28.21,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 73.66,
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
          "id": "2e217811de3b060cad1c48b04d74a802d9afa04c",
          "message": "Fix the scope and argument binding of a lambda literal (#490)\n\n* Give an empty block body its own local scope\n\nA block or lambda with an empty body built its DummyNilNode with the\nenclosing LocalEnv, and install0 takes the body's LocalEnv as its own.\nSo `->(x) { }` bound x in the enclosing scope, and an empty lambda took\nthe enclosing method's return and the enclosing block's break as the\nvalue #call returns. An empty block had the same bug before a lambda\nliteral was analyzed at all.\n\n* Pass keywords to a lambda without keyword parameters as a hash\n\nA method with no keyword parameters takes `f(k: 1)` as a trailing\npositional hash, but a lambda call skipped that step and reported\n`->(h) { h }.call(k: 1)` as a wrong number of arguments.\n\n* Bind the block passed to a lambda call\n\nA method call binds the block it is given to its `&b` parameter, but a\nlambda call left that parameter untyped. Proc#call already receives the\nblock, so it is bound the same way.\n\n* Bind a lambda passed with `&` through its formals\n\nA lambda given with `&` to an RBS-declared method was still bound like\na block: its rest and post parameters got nothing and its arity was\nnot checked, while the same lambda called with #call bound fully.\n\n* Analyze the keyword defaults of a block\n\nparse_params builds nodes for keyword defaults, but in a block they\nwere never installed, so a call in `{ |x: helper(1)| }` got no\ndiagnostics. A block still does not bind keywords.\n\n* Add a scenario for the return type of a block passed to super\n\nThe block of `super() { ... }` used to fall through to a debug `pp` in\nwrong_return_type and report nothing.",
          "timestamp": "2026-09-27T02:35:29+09:00",
          "tree_id": "2fe7cfc81351fe1e165c3ce0340f73bfa1c02a29",
          "url": "https://github.com/ruby/typeprof/commit/2e217811de3b060cad1c48b04d74a802d9afa04c"
        },
        "date": 1790444285952,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 4.43,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.68,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 28.27,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 71.35,
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
          "id": "371f90a1b38c8efad5e843c94981cb9797eaf2d8",
          "message": "Fix wrong arity diagnostics for .new and .[] of a Struct class (#491)\n\n* Dispatch Struct.[] to the initialize of the receiver class\n\nStruct.[] is an alias for Struct.new, but TypeProf generated it from the\nmember list independently of initialize. When a struct overrode\ninitialize, `self.[]` did not follow it: the RBS showed a stale\nsignature and valid calls were reported as wrong number of arguments.\n\n* Make the members optional in the generated Struct initialize\n\nStruct.new(:x, :y).new and Struct.new(:x, :y)[] are valid, but TypeProf\nrequired every member as an argument and reported these calls as wrong\nnumber of arguments. The omitted members are not typed as nil, so the\nreaders keep the types of the given values.",
          "timestamp": "2026-09-27T18:50:40+09:00",
          "tree_id": "ca423ccf36ab459bca68d0bb2006e366abc6c0ab",
          "url": "https://github.com/ruby/typeprof/commit/371f90a1b38c8efad5e843c94981cb9797eaf2d8"
        },
        "date": 1790502792432,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 4.56,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.67,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 29.09,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 73.15,
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
          "id": "08a852bce80e91c0df883b8f9d675a02fe085921",
          "message": "Fix the arguments and the lookup of super (#492)\n\n* Pass the current values of the parameters in a bare super\n\nA bare `super` passes the current values of the parameters, including\ndefaults and reassignments, but TypeProf forwarded only what the caller\ngave, as `...` does. So `def foo(x = 0) = super` called without\narguments was reported as a wrong number of arguments for the parent.\n\n`...` and anonymous or destructured parameters have no variable the\nmethod can reassign, so they are still forwarded as given. A block or\nlambda parameter can shadow a parameter of the method, so a `super` in\nit still passes the variable of the method.\n\nA named `**rest` that stays empty never ran the box merging the keywords\ninto it, so a keyword default did not reach the parent either. The box\nnow runs once when it is created.\n\n* Resolve super in a block to the enclosing method\n\nA block took the name of the method it was passed to, so\n`[1].map { super }` in `def foo` looked up `map` instead of `foo`. It\nnow takes the name of the enclosing method, as a lambda literal already\ndid.\n\nA block outside any method then has no method name, so its `super` is\nskipped instead of reported as an undefined method with an empty name.\nA block given to define_method or define_singleton_method is the body\nof another method, so it has no method name either, and a bare `super`\nin it is reported as not supported, as Ruby raises for it at runtime.",
          "timestamp": "2026-09-28T12:54:08+09:00",
          "tree_id": "a057a6f7f7ac3c345b3cfab7744b3738bf60f6ed",
          "url": "https://github.com/ruby/typeprof/commit/08a852bce80e91c0df883b8f9d675a02fe085921"
        },
        "date": 1790567810508,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 4.5,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.58,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 28.14,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 72.27,
            "unit": "s"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "pvcresin0730@gmail.com",
            "name": "pvcresin",
            "username": "pvcresin"
          },
          "committer": {
            "email": "mame@ruby-lang.org",
            "name": "Yusuke Endoh",
            "username": "mame"
          },
          "distinct": true,
          "id": "5f6e05b68cc5fc94df8be16add32492ab7b2c129",
          "message": "Fix local variable inference across retry",
          "timestamp": "2026-09-28T22:12:16+09:00",
          "tree_id": "a3b1ee5e21fabd25c9c6c384f80a862fffef8cf0",
          "url": "https://github.com/ruby/typeprof/commit/5f6e05b68cc5fc94df8be16add32492ab7b2c129"
        },
        "date": 1790601296658,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 4.84,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.85,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 31.24,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 75.25,
            "unit": "s"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "mame@ruby-lang.org",
            "name": "Yusuke Endoh",
            "username": "mame"
          },
          "committer": {
            "email": "mame@ruby-lang.org",
            "name": "Yusuke Endoh",
            "username": "mame"
          },
          "distinct": true,
          "id": "95b7d7a47dfb96832b3077f28a28608a702fc2d5",
          "message": "Fill in omitted type arguments of RBS types\n\nA generic class or interface written without type arguments in RBS\n(e.g., `def gen: () -> Gen` for `Gen[T]`) made an Instance type with no\narguments, and matching it against `Gen[Integer]` passed nil as the\nactual argument, which crashed with \"undefined method 'each_type' for\nnil\". Fill in the missing arguments with their default types or\nuntyped.\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>",
          "timestamp": "2026-09-28T22:13:44+09:00",
          "tree_id": "9c37aea8c03ffe7117614ebc10deb5477b89595e",
          "url": "https://github.com/ruby/typeprof/commit/95b7d7a47dfb96832b3077f28a28608a702fc2d5"
        },
        "date": 1790601463819,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 4.68,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.63,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 29.2,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 74.07,
            "unit": "s"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "mame@ruby-lang.org",
            "name": "Yusuke Endoh",
            "username": "mame"
          },
          "committer": {
            "email": "mame@ruby-lang.org",
            "name": "Yusuke Endoh",
            "username": "mame"
          },
          "distinct": true,
          "id": "a375a786976e1c7b73d1705fc922f1509da6bdcf",
          "message": "Analyze a pattern guard after the pattern binds its variables\n\nIfPatternNode installed the guard before the guarded pattern, so a\nvariable bound by the pattern was still nil in the guard, and a common\nguard like `in [x] if x.even?` reported \"undefined method: nil#even?\".\nRuby evaluates the guard after the pattern matches, so install the\npattern first.\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>",
          "timestamp": "2026-09-28T22:22:02+09:00",
          "tree_id": "feabf04aec700eb9a807717614ae689e9f230b8b",
          "url": "https://github.com/ruby/typeprof/commit/a375a786976e1c7b73d1705fc922f1509da6bdcf"
        },
        "date": 1790601881271,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 4.63,
            "unit": "s"
          },
          {
            "name": "optcarrot",
            "value": 3.68,
            "unit": "s"
          },
          {
            "name": "rubygems.org",
            "value": 28.24,
            "unit": "s"
          },
          {
            "name": "redmine",
            "value": 71.25,
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
          "id": "27eaeda533b59ce260a66ae9cf1a727bd1d7c325",
          "message": "Bump version to v0.33.1 (#478)",
          "timestamp": "2026-09-09T12:08:12+09:00",
          "tree_id": "b7cc4f58ae1b9657216d19ef2fc60a1777ad1df4",
          "url": "https://github.com/ruby/typeprof/commit/27eaeda533b59ce260a66ae9cf1a727bd1d7c325"
        },
        "date": 1788923433772,
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
          "id": "68f047980980345ca600df4b4ba9779a565ced6d",
          "message": "Give the RBS instance type its type arguments (#480)\n\nType.default_param_map built the `*instance` entry with an empty argument\nlist, so a singleton method declared to return `instance` lost its type\narguments, and crashed when that result reached a type variable check\n(SigTyVarNode#typecheck got nil instead of an actual argument). After\nbase_type the receiver is always an Instance or a Singleton, so\nget_instance_type is always defined.\n\n    table = Hash[[[\"a\", \"b\"]]]  # Hash.[] is declared as `-> instance`\n    \"foo\".gsub(/o/, table)      # gsub takes `hash[String, _ToS]`",
          "timestamp": "2026-09-12T13:35:34+09:00",
          "tree_id": "f28ba924cf9b4c7917d8e2ba8f9030e18defb4d4",
          "url": "https://github.com/ruby/typeprof/commit/68f047980980345ca600df4b4ba9779a565ced6d"
        },
        "date": 1789187852622,
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
          "id": "74f9bd8038caaeb29b9ecf7176998f5008afade1",
          "message": "Analyze the body of a lambda literal (#481)\n\n* Extract block handling from CallBaseNode into BlockNode\n\nThe parsing of block parameters, the block-local scope, and the\ninstallation of the block body lived inside CallBaseNode. Nothing there\ndepends on being a call, and a lambda literal needs exactly the same\nhandling without being a call, so it moves into its own node that a call\nholds as a subnode. Block parameters now go through AST.parse_params and\nmulti-target binding through a shared Node helper, both of which DefNode\nalready used for the same job.\n\nEvery node now answers ret_code_range, so the escape box no longer picks\na code-range method by node class; a body-bearing node points at its\nlast statement, the rest at themselves. A diagnostic on an empty block\ntherefore points at the block instead of the whole call, and a block on\n`super do ... end` no longer falls through to a debug `pp`.\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>\n\n* Analyze the body of a lambda literal\n\n`-> {}` was a stub that produced a bare Proc and never looked inside, so\nmethod calls in the body got no diagnostics, classes and methods defined\nthere were not registered, and parameters were untyped. `lambda {}` had\nnone of these gaps because it goes through the block handling of a call.\n\nLambdaNode is a BlockNode: a lambda literal builds its scope, parameters\nand body exactly like a block. It is not modeled as a `lambda` call\nbecause `->` is syntax and must not dispatch to a user-defined `lambda`\nmethod.\n\nWhere a lambda differs from a block is how the body leaves. A block's\n`return` exits the enclosing method and its `break` exits the method\nthat yielded; a lambda's `return` and `break` both exit the lambda, so\nits body gets its own return boxes and all three escapes join the value\nthe caller of #call receives.\n\nCo-Authored-By: Claude Opus 5 <noreply@anthropic.com>\n\n* Bind the arguments of a lambda call like a method's\n\nA lambda literal carried a Block, which models what a yielding method\nhands to a block: positionals only. So a lambda whose parameters a block\ncannot express — rest, post, keywords — bound nothing, and the body read\nthose parameters as nil. Its arity was not checked either, and a sole\narray argument was deconstructed over the parameters the way a block\ndeconstructs one, which a lambda does not do.\n\nA lambda is entered like a method, so it now carries the formals a method\ncarries and Proc#call binds against them. The binding itself is the one\na method definition already used: pass_arguments moves off MethodDefBox\nonto FormalArguments, which is what both now hold.\n\nProc#call already received the whole ActualArguments and passed on only\nthe positionals, so the keywords and splat flags were there all along.\n\nCo-Authored-By: Claude Opus 5 <noreply@anthropic.com>\n\n* Handle a block parameter list ending in a comma\n\nExtracting the block parameters into BlockNode routed them through\nparse_params, which reads the rest parameter. The previous block-only\ncode read just the requireds and the optionals, so it never met the node\n`{ |a,| }` puts there: Prism::ImplicitRestNode, which has no #name.\n\nA trailing comma is the only way to write a rest without naming it in a\nblock, and it cannot appear in a method definition or a lambda literal,\nwhere it is a syntax error.\n\nCo-Authored-By: Claude Opus 5 <noreply@anthropic.com>\n\n---------\n\nCo-authored-by: Claude <noreply@anthropic.com>",
          "timestamp": "2026-09-23T14:59:59+09:00",
          "tree_id": "7d022aa0539a6421a4c42331bf51f9cac6262007",
          "url": "https://github.com/ruby/typeprof/commit/74f9bd8038caaeb29b9ecf7176998f5008afade1"
        },
        "date": 1790143328328,
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
          "id": "92876451f5efa8651fe9c1b24f82fb72db8d2bd3",
          "message": "Fix nested destructuring after a splat in multiple assignment (#482)\n\nMultiWriteNode#install0 collected the targets after the splat by their\nown `ret` instead of the vertex behind their DummyRHSNode. A nested\ntarget (MultiTargetNode) has a nil `ret`, which blew up as the\ndestination of a graph edge in the next reinstall. The same mistake hit\nan index or attribute writer silently: it got the return vertex of its\nown call, so the assigned value never reached it.\n\n    *a, (b, c) = 1, 2, [3, 4]\n    #=> undefined method 'on_type_added' for nil",
          "timestamp": "2026-09-23T15:09:16+09:00",
          "tree_id": "7a5b881b4bbd3e575e9b7ec061eae8923c1c5cc8",
          "url": "https://github.com/ruby/typeprof/commit/92876451f5efa8651fe9c1b24f82fb72db8d2bd3"
        },
        "date": 1790143892388,
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
          "id": "0d4edb438bfc5412b3bdc4e600938ad1f9f0992e",
          "message": "Support an unless guard in a pattern (#483)\n\nAST.create_pattern_node routed a guard to IfPatternNode only for\n:if_node, so `in pat unless cond` raised \"unknown pattern node type:\nunless_node\". IfPatternNode reads only the predicate and the guarded\npattern, so an unless guard needs no node of its own; only the sanity\ncheck differs, because Prism names the else slot `subsequent` on IfNode\nand `else_clause` on UnlessNode.",
          "timestamp": "2026-09-23T15:15:21+09:00",
          "tree_id": "9bdef8d4f893003ab8c3002cc56739794092f081",
          "url": "https://github.com/ruby/typeprof/commit/0d4edb438bfc5412b3bdc4e600938ad1f9f0992e"
        },
        "date": 1790144260704,
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
          "id": "9f28445a992317df2463a1d8cd51b2b26cbe5d11",
          "message": "Support a lambda pattern (#485)\n\n`in ->(x) { ... }` matches by `===`, but AST.create_pattern_node had no\nbranch for :lambda_node and raised \"unknown pattern node type:\nlambda_node\". Route it through the same install_pattern0 path as the\nother value patterns; CaseMatchNode#install0 discards the pattern's\nreturn value, so returning a proc instead of the subject is harmless.\nThe subject is not passed to the lambda, so its parameter stays untyped\nand the body is not checked against the matched value.",
          "timestamp": "2026-09-23T15:19:45+09:00",
          "tree_id": "66c14075983bb73a0b4aa868b64d90a7afa1c3a7",
          "url": "https://github.com/ruby/typeprof/commit/9f28445a992317df2463a1d8cd51b2b26cbe5d11"
        },
        "date": 1790144494414,
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
          "id": "0b54714c1e7cdfa8a83009716d5361643809e55f",
          "message": "Support BEGIN blocks (#486)\n\n`BEGIN { ... }` raised \"not supported yet: pre_execution_node\" and\naborted the whole run, unlike `END { ... }`, which was already\nsupported. BEGIN now shares its implementation with END but is installed\nbefore the surrounding statements instead of after, so a method or a\nlocal variable it defines reaches the statements that follow.",
          "timestamp": "2026-09-23T15:23:17+09:00",
          "tree_id": "fb02b95150f19fbff6525ffc65bfda8eba78cbf2",
          "url": "https://github.com/ruby/typeprof/commit/0b54714c1e7cdfa8a83009716d5361643809e55f"
        },
        "date": 1790144722674,
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
          "id": "84485681841ca476b980ad3c8cb04564aedc527a",
          "message": "Push benchmark results to gh-pages in a single push (#488)\n\nEach store step pushed to gh-pages, so GitHub Pages was deployed twice\nper run and the first deployment was always cancelled.",
          "timestamp": "2026-09-26T11:56:23+09:00",
          "tree_id": "29eb5aa18b217d8356b736fba067d6f6997b1803",
          "url": "https://github.com/ruby/typeprof/commit/84485681841ca476b980ad3c8cb04564aedc527a"
        },
        "date": 1790391515625,
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
          "id": "d55c0b3efe4898dc66b397d96a126c869aa9c081",
          "message": "Analyze the benchmark projects with the RBS of their gems (#487)\n\nThe projects were analyzed with `--no-collection`, so every library\nthey use was untyped. Installing their gems and the matching RBS makes\nthe numbers reflect the way TypeProf is used on a real project, at the\ncost of a longer analysis.\n\nThe gem versions and the RBS collection are pinned to a fixed date so\nthat runs stay comparable. Bundler's cooldown does the pinning, which\navoids keeping a lockfile per project in this repository.\n\nBoth workflows run the benchmark on the same Ruby, so that the gems\ninstalled for one of them can be restored by the other.",
          "timestamp": "2026-09-26T12:00:54+09:00",
          "tree_id": "b7a9f6239d41dd90d9240ffd756c7a91f49b0e4a",
          "url": "https://github.com/ruby/typeprof/commit/d55c0b3efe4898dc66b397d96a126c869aa9c081"
        },
        "date": 1790392102270,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 82.68,
            "unit": "%"
          },
          {
            "name": "optcarrot",
            "value": 88.02,
            "unit": "%"
          },
          {
            "name": "rubygems.org",
            "value": 35.75,
            "unit": "%"
          },
          {
            "name": "redmine",
            "value": 47,
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
          "id": "22d6b89edcbe5d7b8230e0b372afe41b6ee57719",
          "message": "Report super outside a method instead of crashing (#484)\n\nOnly a method definition sets lenv.forward_args, which a bare `super`\nshares with `...` forwarding, so `define_method(:foo) { |x| super }` ran\na bare `raise` and surfaced as a RuntimeError with no message. Report a\ndiagnostic instead and treat the call as taking no arguments. Ruby's own\nwording differs by context, an implicit argument passing error from\ndefine_method and \"super called outside of method\" at the top level, and\nTypeProf only knows that forward_args is missing, so the message quotes\nneither.",
          "timestamp": "2026-09-26T13:11:47+09:00",
          "tree_id": "0fbb34affb902295a3e3eee0fb2b7350b57b3e53",
          "url": "https://github.com/ruby/typeprof/commit/22d6b89edcbe5d7b8230e0b372afe41b6ee57719"
        },
        "date": 1790396182574,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 82.68,
            "unit": "%"
          },
          {
            "name": "optcarrot",
            "value": 88.02,
            "unit": "%"
          },
          {
            "name": "rubygems.org",
            "value": 35.75,
            "unit": "%"
          },
          {
            "name": "redmine",
            "value": 47,
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
          "id": "3125e3127f413280a423ebdfd1d1f69ea6bc93b7",
          "message": "Skip the subclass method lookup for calls on Object (#489)\n\nTop-level calls like `get` in Rails routes passed their arguments to\nunrelated methods such as Faraday's `get`, and walking every class on\neach call made the analysis of large projects like rubygems.org much\nslower.",
          "timestamp": "2026-09-27T02:31:25+09:00",
          "tree_id": "18b0c8ddc82c4bc5586b626f085859be6b12f65b",
          "url": "https://github.com/ruby/typeprof/commit/3125e3127f413280a423ebdfd1d1f69ea6bc93b7"
        },
        "date": 1790444044806,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 82.68,
            "unit": "%"
          },
          {
            "name": "optcarrot",
            "value": 88.02,
            "unit": "%"
          },
          {
            "name": "rubygems.org",
            "value": 35.74,
            "unit": "%"
          },
          {
            "name": "redmine",
            "value": 46.96,
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
          "id": "2e217811de3b060cad1c48b04d74a802d9afa04c",
          "message": "Fix the scope and argument binding of a lambda literal (#490)\n\n* Give an empty block body its own local scope\n\nA block or lambda with an empty body built its DummyNilNode with the\nenclosing LocalEnv, and install0 takes the body's LocalEnv as its own.\nSo `->(x) { }` bound x in the enclosing scope, and an empty lambda took\nthe enclosing method's return and the enclosing block's break as the\nvalue #call returns. An empty block had the same bug before a lambda\nliteral was analyzed at all.\n\n* Pass keywords to a lambda without keyword parameters as a hash\n\nA method with no keyword parameters takes `f(k: 1)` as a trailing\npositional hash, but a lambda call skipped that step and reported\n`->(h) { h }.call(k: 1)` as a wrong number of arguments.\n\n* Bind the block passed to a lambda call\n\nA method call binds the block it is given to its `&b` parameter, but a\nlambda call left that parameter untyped. Proc#call already receives the\nblock, so it is bound the same way.\n\n* Bind a lambda passed with `&` through its formals\n\nA lambda given with `&` to an RBS-declared method was still bound like\na block: its rest and post parameters got nothing and its arity was\nnot checked, while the same lambda called with #call bound fully.\n\n* Analyze the keyword defaults of a block\n\nparse_params builds nodes for keyword defaults, but in a block they\nwere never installed, so a call in `{ |x: helper(1)| }` got no\ndiagnostics. A block still does not bind keywords.\n\n* Add a scenario for the return type of a block passed to super\n\nThe block of `super() { ... }` used to fall through to a debug `pp` in\nwrong_return_type and report nothing.",
          "timestamp": "2026-09-27T02:35:29+09:00",
          "tree_id": "2fe7cfc81351fe1e165c3ce0340f73bfa1c02a29",
          "url": "https://github.com/ruby/typeprof/commit/2e217811de3b060cad1c48b04d74a802d9afa04c"
        },
        "date": 1790444286904,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 82.68,
            "unit": "%"
          },
          {
            "name": "optcarrot",
            "value": 88.02,
            "unit": "%"
          },
          {
            "name": "rubygems.org",
            "value": 35.74,
            "unit": "%"
          },
          {
            "name": "redmine",
            "value": 46.96,
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
          "id": "371f90a1b38c8efad5e843c94981cb9797eaf2d8",
          "message": "Fix wrong arity diagnostics for .new and .[] of a Struct class (#491)\n\n* Dispatch Struct.[] to the initialize of the receiver class\n\nStruct.[] is an alias for Struct.new, but TypeProf generated it from the\nmember list independently of initialize. When a struct overrode\ninitialize, `self.[]` did not follow it: the RBS showed a stale\nsignature and valid calls were reported as wrong number of arguments.\n\n* Make the members optional in the generated Struct initialize\n\nStruct.new(:x, :y).new and Struct.new(:x, :y)[] are valid, but TypeProf\nrequired every member as an argument and reported these calls as wrong\nnumber of arguments. The omitted members are not typed as nil, so the\nreaders keep the types of the given values.",
          "timestamp": "2026-09-27T18:50:40+09:00",
          "tree_id": "ca423ccf36ab459bca68d0bb2006e366abc6c0ab",
          "url": "https://github.com/ruby/typeprof/commit/371f90a1b38c8efad5e843c94981cb9797eaf2d8"
        },
        "date": 1790502793122,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 82.68,
            "unit": "%"
          },
          {
            "name": "optcarrot",
            "value": 87.95,
            "unit": "%"
          },
          {
            "name": "rubygems.org",
            "value": 35.93,
            "unit": "%"
          },
          {
            "name": "redmine",
            "value": 46.96,
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
          "id": "08a852bce80e91c0df883b8f9d675a02fe085921",
          "message": "Fix the arguments and the lookup of super (#492)\n\n* Pass the current values of the parameters in a bare super\n\nA bare `super` passes the current values of the parameters, including\ndefaults and reassignments, but TypeProf forwarded only what the caller\ngave, as `...` does. So `def foo(x = 0) = super` called without\narguments was reported as a wrong number of arguments for the parent.\n\n`...` and anonymous or destructured parameters have no variable the\nmethod can reassign, so they are still forwarded as given. A block or\nlambda parameter can shadow a parameter of the method, so a `super` in\nit still passes the variable of the method.\n\nA named `**rest` that stays empty never ran the box merging the keywords\ninto it, so a keyword default did not reach the parent either. The box\nnow runs once when it is created.\n\n* Resolve super in a block to the enclosing method\n\nA block took the name of the method it was passed to, so\n`[1].map { super }` in `def foo` looked up `map` instead of `foo`. It\nnow takes the name of the enclosing method, as a lambda literal already\ndid.\n\nA block outside any method then has no method name, so its `super` is\nskipped instead of reported as an undefined method with an empty name.\nA block given to define_method or define_singleton_method is the body\nof another method, so it has no method name either, and a bare `super`\nin it is reported as not supported, as Ruby raises for it at runtime.",
          "timestamp": "2026-09-28T12:54:08+09:00",
          "tree_id": "a057a6f7f7ac3c345b3cfab7744b3738bf60f6ed",
          "url": "https://github.com/ruby/typeprof/commit/08a852bce80e91c0df883b8f9d675a02fe085921"
        },
        "date": 1790567811542,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 82.68,
            "unit": "%"
          },
          {
            "name": "optcarrot",
            "value": 87.95,
            "unit": "%"
          },
          {
            "name": "rubygems.org",
            "value": 35.93,
            "unit": "%"
          },
          {
            "name": "redmine",
            "value": 46.96,
            "unit": "%"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "pvcresin0730@gmail.com",
            "name": "pvcresin",
            "username": "pvcresin"
          },
          "committer": {
            "email": "mame@ruby-lang.org",
            "name": "Yusuke Endoh",
            "username": "mame"
          },
          "distinct": true,
          "id": "5f6e05b68cc5fc94df8be16add32492ab7b2c129",
          "message": "Fix local variable inference across retry",
          "timestamp": "2026-09-28T22:12:16+09:00",
          "tree_id": "a3b1ee5e21fabd25c9c6c384f80a862fffef8cf0",
          "url": "https://github.com/ruby/typeprof/commit/5f6e05b68cc5fc94df8be16add32492ab7b2c129"
        },
        "date": 1790601297385,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 82.68,
            "unit": "%"
          },
          {
            "name": "optcarrot",
            "value": 87.95,
            "unit": "%"
          },
          {
            "name": "rubygems.org",
            "value": 35.93,
            "unit": "%"
          },
          {
            "name": "redmine",
            "value": 46.96,
            "unit": "%"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "mame@ruby-lang.org",
            "name": "Yusuke Endoh",
            "username": "mame"
          },
          "committer": {
            "email": "mame@ruby-lang.org",
            "name": "Yusuke Endoh",
            "username": "mame"
          },
          "distinct": true,
          "id": "95b7d7a47dfb96832b3077f28a28608a702fc2d5",
          "message": "Fill in omitted type arguments of RBS types\n\nA generic class or interface written without type arguments in RBS\n(e.g., `def gen: () -> Gen` for `Gen[T]`) made an Instance type with no\narguments, and matching it against `Gen[Integer]` passed nil as the\nactual argument, which crashed with \"undefined method 'each_type' for\nnil\". Fill in the missing arguments with their default types or\nuntyped.\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>",
          "timestamp": "2026-09-28T22:13:44+09:00",
          "tree_id": "9c37aea8c03ffe7117614ebc10deb5477b89595e",
          "url": "https://github.com/ruby/typeprof/commit/95b7d7a47dfb96832b3077f28a28608a702fc2d5"
        },
        "date": 1790601464933,
        "tool": "customBiggerIsBetter",
        "benches": [
          {
            "name": "typeprof",
            "value": 82.68,
            "unit": "%"
          },
          {
            "name": "optcarrot",
            "value": 87.95,
            "unit": "%"
          },
          {
            "name": "rubygems.org",
            "value": 35.93,
            "unit": "%"
          },
          {
            "name": "redmine",
            "value": 46.96,
            "unit": "%"
          }
        ]
      }
    ]
  }
}