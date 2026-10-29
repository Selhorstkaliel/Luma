#!/usr/bin/env python3
"""Semântica do Lume: o Python gerado faz o que o programa diz (sem interface)."""
import unittest
from pathlib import Path

from _util import LUME, run_lume


class TestSemantics(unittest.TestCase):
    def test_print_formats_lume_values(self):
        self.assertEqual(run_lume('print(true, false, nil, [1, "a"], 7 / 2, 7 % 2)\n'),
                         'true false nil [1, "a"] 3.5 1\n')

    def test_functions_recursion_and_loops(self):
        out = run_lume((LUME / "examples/fatorial.lume").read_text())
        self.assertEqual(out, "fatoriais: [1, 2, 6, 24, 120]\nsoma: 153 par? false\n")

    def test_closure_rebinds_outer_variable(self):
        src = ("fn make() {\n  let n = 0\n  fn inc() {\n    n = n + 1\n    return n\n  }\n  return inc\n}\n"
               "let f = make()\nf()\nprint(f())\n")
        self.assertEqual(run_lume(src), "2\n")

    def test_global_rebind_from_function(self):
        self.assertEqual(run_lume("let c = 0\nfn bump() {\n  c = c + 1\n}\nbump()\nbump()\nprint(c)\n"), "2\n")

    def test_if_else_if_chain(self):
        src = ('fn grade(x) {\n  if x > 8 {\n    return "a"\n  } else if x > 5 {\n    return "b"\n'
               '  } else {\n    return "c"\n  }\n}\nprint(grade(9), grade(6), grade(1))\n')
        self.assertEqual(run_lume(src), "a b c\n")

    def test_python_keywords_are_safe_names(self):
        self.assertEqual(run_lume("let class = 2\nlet lambda = 3\nprint(class * lambda)\n"), "6\n")

    def test_index_and_attribute_assignment(self):
        self.assertEqual(run_lume("let xs = [1, 2, 3]\nxs[0] = 9\nprint(xs)\n"), "[9, 2, 3]\n")

    def test_examples_compile(self):
        for f in sorted((LUME / "examples").glob("*.lume")):
            with self.subTest(exemplo=f.name):
                from lumec.compiler import compile_source
                compile_source(f.read_text(), f.name)

    def test_cli_reports_runtime_error_line(self):
        import subprocess
        import sys
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "erro.lume"
            p.write_text('let x = 1\nprint(x + "a")\n')
            r = subprocess.run([sys.executable, str(LUME / "bin/lumec"), "run", str(p)], capture_output=True, text=True)
        self.assertEqual(r.returncode, 1)
        self.assertIn("erro.lume:2: erro de execução: TypeError", r.stderr)


if __name__ == "__main__":
    unittest.main()
