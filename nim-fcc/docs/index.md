`nimfa -lang:c -std:ansi -platform:linux -arch:amd64 -no-stdlib -no-prelude -entry:"_start" linux_x86_64_entry.c main.c -out:linux_x86_64.elf`

```nim
let sources = @["linux_x86_64_entry.c", "main.c"]
let cflags = @["-no-stdlib", "-no-prelude"]
let out_assembly_filename = "linux_x86_64.elf"

let options = NimfaOptions(
  lang: "c",
  standard: "ansi",
  platform: "linux",
  arch: "amd64",
  entry: "_start"
  with_prelude: false,
  with_stdlib: false
)

let compiler = nimfa.make_cc(front: "c", back: "fasmg");

let objs: nimfa.Object;
for source in sources:
  objs.add(compiler.run(options, sources, cflags));
```
