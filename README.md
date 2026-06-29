# Ornith Harness Experiment

Evaluating the open-source coding model **`ornith:35b`** (Ollama, local) — advertised as
"Opus-4.7-level" — by putting it in a **compile-test harness** driven by Claude (Opus 4.8 in
Claude Code), with a compiler as the judge. Task: emulate `printf()` in x86-64 assembly.

**Empirical verdict:** the harness moves it from "won't assemble" → "compiles" → correct
structure, **but it never reaches a correct `printf`**. It fixes *mechanical* problems
(`;`→`#`, set a missing register) and **diverges on *structural* ones** (the varargs ABI)
*even when handed the fix verbatim*. "Opus-4.7-level" is a category error: a quantized
34.7B Qwen MoE under the **MIT license** (not MIT the university).

---

## Contents

| File | Description |
|---|---|
| `conversation.md` | Session transcript (printf critique → Ornith investigation → harness → article). |
| `ornith-harness-medium.md` | Medium-ready article (EN, ~870 words): *"The Compiler Doesn't Lie".* |
| **`harness/`** | The harness code. |
| `harness/chat.py` | Driver: posts messages to the Ollama `/api/chat` endpoint, keeps context, logs thinking/response. |
| `harness/prompt1.txt` | The task prompt (emulate printf, ABI + GAS toolchain constraints). |
| `harness/ornith-dialogue.json` | Full Claude↔Ornith dialogue (every turn + re-injected feedback). |
| `harness/ledger.txt` | Per-iteration stats (wall time, tokens, thinking length, code emitted, outcome). |
| **`reference-printf/`** | The reference implementation that **works** (written by Claude). |
| `reference-printf/myprintf.s` | x86-64 printf (GAS, Intel syntax): `%s %d %c %%`, INT_MIN, spilled varargs. |
| `reference-printf/test.c` | C test + expected output. |
| **`ornith-output/`** | Ornith's best attempt + evidence. |
| `ornith-output/ornith-sol.s` | Ornith's last output (iteration 5 regression: does not assemble). |
| `ornith-output/run_out.txt` | Wrong runtime output (incorrect argument values). |
| `ornith-output/last_build_errors.txt` | Assembler errors from the last iteration. |
| **`critique-demo/`** | Demonstration that a third-party critique's "Correction B" does not hold up. |
| `critique-demo/correctionB.s` | The "Correction B" transcribed: does not assemble (`mov rdx, edx`). |
| `critique-demo/demoB.s`, `mainB.c` | Minimally-repaired version → prints garbage instead of "42" (rax never loaded). |

---

## Reproduce

**The harness** (requires Ollama with `ornith:35b`, and `OLLAMA_HOST` pointing at the server):
```bash
cd harness
# seed conv.json from prompt1.txt, then:
python3 chat.py conv.json        # one turn; re-inject the errors and run again
```
Note: `chat.py` reads the server from the `OLLAMA_HOST` environment variable
(default `http://127.0.0.1:11434`). `ornith` is a reasoning model: budget a high `num_predict`
(≥48k) or it never reaches its answer (everything goes into `thinking`).

**The reference implementation** (which works):
```bash
cd reference-printf
gcc -no-pie test.c myprintf.s -o t && ./t
```

**The broken "Correction B":**
```bash
cd critique-demo
gcc -c correctionB.s -o correctionB.o     # -> Error: operand type mismatch (mov rdx, edx)
gcc -no-pie mainB.c demoB.s -o demoB && ./demoB   # input 42 -> binary garbage
```
