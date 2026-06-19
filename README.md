# b64veryfast

`b64veryfast` is an extremely fast Base64 and Base64url
encoding/decoding library for Erlang binaries.

The short version: this is a thin, binary-only Erlang NIF over the
SIMD-oriented [`aklomp/base64`](https://github.com/aklomp/base64) C backend.
The NIF reads Erlang input binaries without copying, allocates the exact output
binary once, writes directly into that new binary, and schedules large calls on
dirty CPU schedulers. On this Apple arm64 benchmark host it reaches about
24 GiB/s encode, 11.5 GiB/s checked decode, and 12.6 GiB/s trusted decode for
1 MiB binaries.

This project is forked from
[`zuckschwerdt/b64fast`](https://github.com/zuckschwerdt/b64fast). Credit to
that project for the original Erlang API shape and NIF package. The execution
backend is based on [`aklomp/base64`](https://github.com/aklomp/base64), with
credit to its authors and contributors for the high-performance Base64 codecs.

## Benchmarks

These benchmarks measure end-to-end Erlang calls, including the NIF boundary,
input inspection, output allocation, and C codec execution. They are not raw C
kernel-only numbers.

The plotted sweep uses 37 approximately log-spaced payload sizes from 16 B to
4 MiB. Each payload size has five runs over the same random binary. The small
points are those individual runs; the lines are medians at each size. The
graph uses a logarithmic x-axis for payload size and a linear y-axis for
throughput. Dark marks are encode; lighter marks are decode. The dashed
`b64veryfast trusted` line is checked against known-good input and skips
block-level alphabet validation in the hot decoder loop.

Raw data:

- [bench/results/apple-arm64-otp28.csv](bench/results/apple-arm64-otp28.csv)
- [bench/results/apple-arm64-otp28-summary.csv](bench/results/apple-arm64-otp28-summary.csv)

Environment:

| Item | Value |
|---|---|
| Host | Apple arm64, Darwin 25.4.0 |
| Compiler | Apple clang 21.0.0 |
| Erlang/OTP | OTP 28, ERTS 16.4 |
| `b64veryfast` engine | `NEON64_CFLAGS=-mcpu=native` |
| Original `b64fast` | [`zuckschwerdt/b64fast`](https://github.com/zuckschwerdt/b64fast) `c7088362` |
| Rust URL-safe NIF | [`permaweb/b64rs`](https://github.com/permaweb/b64rs) `94b7d8e5` |

Benchmark caveats:

- Rerun on your production CPU. SIMD engine availability, compiler flags,
  scheduler pressure, and memory bandwidth matter.
- Small payloads are dominated by call overhead and allocation. Large payloads
  show the codec throughput more clearly.
- `b64fast` only provides standard Base64 in this comparison. `b64rs` only
  provides URL-safe no-padding Base64 in this comparison.
- The `b64veryfast` `_url` functions track the standard functions closely, so
  the graph shows one `b64veryfast` pair and leaves the URL-safe details in the
  raw CSV.
- The trusted decode variants are only for input that has already been
  validated or was produced by a trusted encoder. They still allocate bounded
  Erlang output binaries, but malformed trusted input has unspecified decoded
  bytes and may still fail on the non-vector tail.
- Decode throughput is reported against decoded output bytes, so encode and
  decode numbers are directly comparable for the same input size.

### Throughput Graph

![Base64 throughput by payload size](docs/benchmarks/throughput.svg)

### Selected Results

Median throughput, MiB/s, rounded to the nearest MiB/s. The full precision
values are in the summary CSV.

Encode:

| Library | 32 B | 512 B | 4 KiB | 64 KiB | 1 MiB | 4 MiB |
|---|---:|---:|---:|---:|---:|---:|
| OTP `base64` | 378 | 685 | 790 | 794 | 685 | 666 |
| Original `b64fast` | 140 | 1,462 | 3,244 | 4,046 | 4,127 | 4,083 |
| `b64rs` URL-safe | 716 | 4,279 | 7,993 | 11,755 | 11,676 | 12,083 |
| `b64veryfast` | 1,256 | 6,812 | 18,608 | 23,478 | 24,048 | 23,194 |

Decode:

| Library | 32 B | 512 B | 4 KiB | 64 KiB | 1 MiB | 4 MiB |
|---|---:|---:|---:|---:|---:|---:|
| OTP `base64` | 246 | 510 | 555 | 554 | 535 | 511 |
| Original `b64fast` | 139 | 1,465 | 3,452 | 4,148 | 4,156 | 4,023 |
| `b64rs` URL-safe | 499 | 2,467 | 3,939 | 4,125 | 4,188 | 4,458 |
| `b64veryfast` | 1,195 | 5,499 | 10,758 | 12,333 | 11,468 | 12,352 |
| `b64veryfast` trusted | 1,189 | 5,532 | 12,027 | 13,625 | 12,584 | 13,529 |

At 1 MiB, `b64veryfast` is about 35.1x faster than OTP encode, 21.4x faster
than OTP decode, 5.8x faster than original `b64fast` encode, and 2.8x faster
than original `b64fast` decode on this host. `decode64_trusted/1` is about
1.10x faster than checked `decode64/1` at 1 MiB, and about 3.0x faster than
original `b64fast` decode.

The `_url` variants follow the same performance profile. At 1 MiB,
`b64veryfast:encode64_url/1` measured `23443.22 MiB/s`,
`b64veryfast:decode64_url/1` measured `11258.36 MiB/s`, and
`b64veryfast:decode64_url_trusted/1` measured `12430.40 MiB/s`, effectively
matching the standard Base64 path. Against `b64rs`, the URL-safe path is about
2.0x faster on encode, 2.7x faster on checked decode, and 3.0x faster on
trusted decode at 1 MiB.

### Reproducing The Benchmarks

Compile this library:

```sh
rebar3 compile
```

Build optional comparison libraries:

```sh
rm -rf /private/tmp/b64fast-original
git clone --depth 1 https://github.com/zuckschwerdt/b64fast.git /private/tmp/b64fast-original
(cd /private/tmp/b64fast-original && rebar3 compile)
```

Run the benchmark. `B64FAST_EBIN` and `B64RS_EBIN` are optional; missing
comparison libraries are skipped.

```sh
B64FAST_EBIN=/private/tmp/b64fast-original/_build/default/lib/b64fast/ebin \
B64RS_EBIN=/path/to/b64rs/ebin \
bench/bench.escript bench/results/apple-arm64-otp28.csv
```

Render the graph and summary CSV:

```sh
bench/plot.py bench/results/apple-arm64-otp28.csv docs/benchmarks
```

## Architecture

`b64veryfast` has three layers:

| Layer | Role |
|---|---|
| `src/b64veryfast.erl` | Public Erlang module and NIF loader |
| `c_src/b64veryfast.c` | Erlang NIF boundary, memory handling, scheduling, flag selection |
| `c_src/aklomp/` | Vendored `aklomp/base64` codec backend |

The NIF boundary is intentionally small. It validates that input is a binary,
inspects it with `enif_inspect_binary`, asks the backend for the exact output
size, allocates that output with `enif_make_new_binary`, and passes the input
pointer plus output pointer into `aklomp/base64`.

This means the hot path avoids avoidable copies:

- The input is read from Erlang-owned binary memory and is never mutated.
- The output is a freshly allocated Erlang binary, so C writes only into memory
  it has just received for that purpose.
- There is no Erlang-level post-processing pass for URL-safe output.

Large calls are scheduled on dirty CPU schedulers at 256 KiB and above. Small
calls run on normal schedulers to avoid dirty scheduler overhead. This threshold
is deliberately conservative: large binary work should not block normal BEAM
schedulers, while tiny binary work should stay cheap.

The vendored backend carries URL-safe and no-padding flags used by
`encode64_url/1` and `decode64_url/1`. Standard `decode64/1` accepts padded and
unpadded input, preserving useful original `b64fast` compatibility. Decoding
does not ignore whitespace.

The trusted decode functions use the same memory discipline as checked decode:
the NIF reads the inspected Erlang binary, allocates one new Erlang output
binary, and writes only into that output. The difference is the backend flag:
`decode64_trusted/1` and `decode64_url_trusted/1` skip the per-block alphabet
classification/reduction in the SIMD and scalar hot loops. They are suitable
when another layer has already guaranteed that the input is valid Base64 or
Base64url.

## API

All functions accept and return binaries. Non-binary input raises `badarg`.

```erlang
b64veryfast:encode64(Bin).      % standard padded Base64
b64veryfast:decode64(Bin).      % standard Base64 decode
b64veryfast:decode64_trusted(Bin).
b64veryfast:encode64_url(Bin).  % URL-safe Base64 without padding
b64veryfast:decode64_url(Bin).  % URL-safe Base64 decode
b64veryfast:decode64_url_trusted(Bin).
```

Use the trusted decode variants only for known-good input. Invalid bytes are
not a memory safety issue for the NIF, but the decoded bytes are unspecified
and some malformed tails may still raise `badarg`.

Example:

```erlang
1> b64veryfast:encode64(<<"zany">>).
<<"emFueQ==">>

2> b64veryfast:encode64_url(<<251, 255>>).
<<"-_8">>

3> b64veryfast:decode64_url(<<"-_8">>).
<<251,255>>
```

## Installation

Add the dependency to `rebar.config`:

```erlang
{deps, [
    {b64veryfast, {git, "https://github.com/permaweb/b64veryfast.git",
        {branch, "master"}}}
]}.
```

Then compile as usual:

```sh
rebar3 compile
```

## Compilation

The build uses the top-level `Makefile` to compile `priv/b64veryfast.so`. By
default it detects the host architecture and enables the fastest compiler flags
that are safe for that architecture.

Inspect the selected engine flags with:

```sh
make print-config
```

On the benchmark host used above, that prints:

```text
HOST_ARCH=arm64
HOST_OS=Darwin
NEON64_CFLAGS=-mcpu=native
NEON32_CFLAGS=
AVX512_CFLAGS=
AVX2_CFLAGS=
AVX_CFLAGS=
SSE42_CFLAGS=
SSE41_CFLAGS=
SSSE3_CFLAGS=
```

Each detected engine can be overridden with a `B64_VERYFAST_`-prefixed
environment variable:

| Variable | Purpose |
|---|---|
| `B64_VERYFAST_NEON64_CFLAGS` | arm64 NEON engine flags |
| `B64_VERYFAST_NEON32_CFLAGS` | 32-bit ARM NEON engine flags |
| `B64_VERYFAST_AVX512_CFLAGS` | x86 AVX512 engine flags |
| `B64_VERYFAST_AVX2_CFLAGS` | x86 AVX2 engine flags |
| `B64_VERYFAST_AVX_CFLAGS` | x86 AVX engine flags |
| `B64_VERYFAST_SSE42_CFLAGS` | x86 SSE4.2 engine flags |
| `B64_VERYFAST_SSE41_CFLAGS` | x86 SSE4.1 engine flags |
| `B64_VERYFAST_SSSE3_CFLAGS` | x86 SSSE3 engine flags |
| `B64_VERYFAST_CFLAGS` | additional common C compiler flags |
| `B64_VERYFAST_LDFLAGS` | additional shared-library linker flags |

If an engine variable is present, its value is used exactly. Set it to an empty
value to disable that engine:

```sh
B64_VERYFAST_NEON64_CFLAGS= rebar3 compile
```

Examples:

```sh
B64_VERYFAST_NEON64_CFLAGS="-mcpu=native" rebar3 compile
B64_VERYFAST_AVX2_CFLAGS="-mavx2" rebar3 compile
B64_VERYFAST_CFLAGS="-O3 -DNDEBUG" rebar3 compile
```

On x86, `aklomp/base64` can compile multiple engines and choose among them at
runtime. On ARM, the build enables the relevant NEON engine at compile time when
the compiler accepts the selected flags.

The generated `c_src/aklomp/lib/config.h` records which engines were enabled
for a build. It is a build artifact and is removed by `make clean`.

## Choosing A Library

Use `b64veryfast` when binary Base64/Base64url work is on a hot path and a NIF
is acceptable. Use OTP `base64` when you need pure Erlang/OTP-only behavior,
when throughput is irrelevant, or when deploying native code is undesirable.

For tiny binaries, benchmark in your actual call pattern; NIF call overhead can
be more important than raw codec speed. For medium and large binaries,
`b64veryfast` is the clear throughput winner in the benchmark above.

## License

`b64veryfast` keeps the MIT license from the original `b64fast` package. The
vendored `aklomp/base64` sources keep their upstream license notices.
