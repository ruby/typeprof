window.BENCHMARK_DATA = {
  "lastUpdate": 1790144723302,
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
      }
    ]
  }
}