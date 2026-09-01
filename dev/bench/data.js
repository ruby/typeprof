window.BENCHMARK_DATA = {
  "lastUpdate": 1788259247148,
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
      }
    ]
  }
}