# b64veryfast

`b64veryfast` is a high-throughput Base64 and Base64url encoding/decoding
library for Erlang binaries.

It is a thin, binary-only Erlang NIF over the SIMD-oriented
[`aklomp/base64`](https://github.com/aklomp/base64) C backend. The NIF receives
Erlang input binaries without copying, allocates the exact output binary once,
writes directly into that new binary, and schedules large calls on dirty CPU
schedulers. URL-safe operations are handled inside the backend rather than by
post-processing in Erlang.

In the benchmark environment documented in the Benchmarks section, peak median
throughput is `23.8 GiB/s` encode, `12.2 GiB/s` checked, and `13.5 GiB/s`
for trusted-input (no input range checking, etc.) decode.

This project is forked from
[`zuckschwerdt/b64fast`](https://github.com/zuckschwerdt/b64fast). Credit to
that project for the original Erlang project shape and NIF package. The execution
backend is based on [`aklomp/base64`](https://github.com/aklomp/base64), with
credit to its authors and contributors for the high-performance Base64 codecs.

## Why It Is `VeryFast`™️

- `aklomp/base64` provides architecture-specific SIMD codecs, including NEON on
  Apple arm64 and AVX/SSE families on x86.
- The NIF reads the input binary in place, computes the exact output size, and
  writes directly into one newly allocated Erlang binary.
- URL-safe encoding and decoding are handled by the C backend, avoiding an
  Erlang post-processing pass for `+`/`/`/`=` translation.
- Large payloads are scheduled on dirty CPU schedulers so long-running native
  work does not occupy normal BEAM schedulers.
- Trusted decode variants can skip per-block alphabet classification when a
  caller has already guaranteed valid input.

## Benchmarks

![Base64 throughput by payload size](docs/benchmarks/throughput.svg)

These benchmarks measure end-to-end Erlang calls: NIF boundary crossing, input
inspection, output allocation, and codec execution. They are not raw C
kernel-only numbers.

The sweep uses 185 approximately log-spaced payload sizes from 16 B to 16 MiB.
Each payload size has five runs over the same random binary. The graph uses a
logarithmic x-axis for payload size and a linear y-axis for throughput. Points
are individual runs; lines are per-size medians. Dark marks are encode, lighter
marks are decode, crimson marks are `b64veryfast`, and the dashed crimson line
is `decode64_trusted/1`.

The benchmark warms each operation and payload size with up to 5,000 iterations,
then forces Erlang garbage collection before each measured run. It does not pin
schedulers, isolate cores, or disable other host activity, so scatter in the
points is expected.

### Selected Results

Median throughput, MiB/s, rounded to the nearest MiB/s. The full precision
values are in the summary CSV.

Encode (`MiB/s`):

| Library | 32 B | 512 B | 4 KiB | 64 KiB | 1 MiB | 4 MiB | 16 MiB |
|---|---:|---:|---:|---:|---:|---:|---:|
| OTP `base64` | 344 | 674 | 776 | 791 | 715 | 705 | 646 |
| Original `b64fast` | 131 | 1,267 | 3,352 | 4,049 | 3,352 | 3,953 | 4,166 |
| `b64rs` URL-safe | 666 | 4,565 | 9,570 | 11,159 | 7,456 | 8,813 | 12,153 |
| **`b64veryfast`** | **1,132** | **7,287** | **18,401** | **21,386** | **11,638** | **14,528** | **24,372** |

Decode (`MiB/s`):

| Library | 32 B | 512 B | 4 KiB | 64 KiB | 1 MiB | 4 MiB | 16 MiB |
|---|---:|---:|---:|---:|---:|---:|---:|
| OTP `base64` | 262 | 513 | 560 | 557 | 526 | 528 | 520 |
| Original `b64fast` | 131 | 1,407 | 3,381 | 4,109 | 3,468 | 4,030 | 4,181 |
| `b64rs` URL-safe | 484 | 2,521 | 3,916 | 4,099 | 3,758 | 3,911 | 4,454 |
| **`b64veryfast`** | **1,385** | **5,252** | **10,635** | **12,275** | **8,171** | **9,431** | **12,515** |
| **`b64veryfast` trusted** | **1,094** | **5,390** | **11,607** | **13,617** | **8,900** | **10,523** | **13,875** |

At the largest measured payload, `b64veryfast` measures `24372 MiB/s` encode
and `12515 MiB/s` checked decode. `decode64_trusted/1` measures `13875 MiB/s`,
about 1.1x faster than checked decode at that size.

The `_url` variants follow the same performance profile as the standard
Base64 variants. The full URL-safe measurements are included in the raw and
summary CSV files.

## API

All functions accept and return binaries. Non-binary input raises `badarg`.
Checked decode rejects malformed Base64 or Base64url input by raising
`badarg`; functions do not return `{ok, Binary}` or `{error, Reason}` tuples.
Trusted decode is for known-good input only.

```erlang
b64veryfast:encode64(Bin).         % standard padded Base64
b64veryfast:decode64(Bin).         % standard Base64 decode
b64veryfast:decode64_trusted(Bin). % trusted standard Base64 decode
b64veryfast:encode64_url(Bin).     % URL-safe Base64 without padding
b64veryfast:decode64_url(Bin).     % URL-safe Base64 decode
b64veryfast:decode64_url_trusted(Bin). % trusted URL-safe Base64 decode
```

Trusted decode is not a validator. Use it only for Base64 produced by code you
trust, or for input that has already been validated elsewhere. Malformed input
is not a memory-safety issue for the NIF, but the decoded bytes are unspecified
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
accepted by the compiler for that host.

Inspect the selected engine flags with:

```sh
make print-config
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

Flags such as `-mcpu=native` and `-march=native` optimize for the build host.
They are appropriate for local deployment on the same CPU family, but may not
be suitable for release artifacts that will be moved to older or different
machines.

On x86, `aklomp/base64` can compile multiple engines and choose among them at
runtime. On ARM, the build enables the relevant NEON engine at compile time when
the compiler accepts the selected flags.

The generated `c_src/aklomp/lib/config.h` records which engines were enabled
for a build. It is a build artifact and is removed by `make clean`.

## Architecture

`b64veryfast` has three layers:

| Layer | Role |
|---|---|
| `src/b64veryfast.erl` | Public Erlang module and NIF loader |
| `c_src/b64veryfast.c` | Erlang NIF boundary, memory handling, scheduling, flag selection |
| `c_src/aklomp/` | Vendored `aklomp/base64` codec backend |

The NIF boundary is intentionally small:

1. Validate that input is a binary.
2. Inspect the input with `enif_inspect_binary`.
3. Ask the backend for the exact output size.
4. Allocate the output with `enif_make_new_binary`.
5. Pass the input pointer and output pointer to `aklomp/base64`.

This means the hot path avoids avoidable copies:

- The input is read from Erlang-owned binary memory and is never mutated.
- The output is a freshly allocated Erlang binary, so C writes only into memory
  it has just received for that purpose.
- There is no Erlang-level post-processing pass for URL-safe output.

Large calls are scheduled on dirty CPU schedulers at 256 KiB and above. Small
calls run on normal schedulers to avoid dirty scheduler overhead. This threshold
is deliberately conservative: large binary work should not block normal BEAM
schedulers, while tiny binary work should stay cheap. Dirty NIFs still consume
dirty CPU schedulers and memory bandwidth, so high-concurrency large-payload
workloads should be capacity-tested under realistic load.

The vendored backend carries URL-safe and no-padding flags used by the `_url`
functions. Decode functions accept padded or unpadded input for their
respective alphabets, preserving useful original `b64fast` compatibility.
Decoding does not ignore whitespace.

| Function family | Alphabet | Encode padding | Decode padding | Whitespace |
|---|---|---|---|---|
| `encode64/1`, `decode64/1` | Standard `+` and `/` | Emits `=` | Accepts padded or unpadded | Rejected |
| `encode64_url/1`, `decode64_url/1` | URL-safe `-` and `_` | Omits `=` | Accepts padded or unpadded | Rejected |

The trusted decode functions use the same memory discipline as checked decode.
They read the inspected Erlang binary, allocate one new Erlang output binary,
and write only into that output. The difference is the backend flag:
`decode64_trusted/1` and `decode64_url_trusted/1` skip per-block alphabet
classification in the SIMD and scalar hot loops. Use them only when another
layer has already guaranteed that the input is valid Base64 or Base64url.

## Reproducing The Benchmarks

Compile this library:

```sh
rebar3 compile
```

Build optional comparison libraries:

```sh
rm -rf /private/tmp/b64fast-original
git clone --depth 1 https://github.com/zuckschwerdt/b64fast.git /private/tmp/b64fast-original
(cd /private/tmp/b64fast-original && rebar3 compile)

rm -rf /private/tmp/b64rs
git clone https://github.com/permaweb/b64rs.git /private/tmp/b64rs
(cd /private/tmp/b64rs && git checkout 94b7d8e5 && rebar3 compile)
```

Run the benchmark. `B64FAST_EBIN` and `B64RS_EBIN` are optional; missing
comparison libraries are skipped.

```sh
B64FAST_EBIN=/private/tmp/b64fast-original/_build/default/lib/b64fast/ebin \
B64RS_EBIN=/private/tmp/b64rs/_build/default/lib/b64rs/ebin \
bench/bench.escript bench/results/apple-arm64-otp28.csv
```

Render the graph and summary CSV:

```sh
bench/plot.py bench/results/apple-arm64-otp28.csv docs/benchmarks
```

The measurements in this `README` were generated in the following test environment:

| Item | Value |
|---|---|
| Host | Apple arm64, Darwin 25.4.0 |
| Compiler | Apple clang 21.0.0 |
| Erlang/OTP | OTP 28, ERTS 16.4 |
| `b64veryfast` engine | `NEON64_CFLAGS=-mcpu=native` |
| Original `b64fast` | [`zuckschwerdt/b64fast`](https://github.com/zuckschwerdt/b64fast) `c7088362` |
| Rust URL-safe NIF | [`permaweb/b64rs`](https://github.com/permaweb/b64rs) `94b7d8e5` |

Raw data:

- [bench/results/apple-arm64-otp28.csv](bench/results/apple-arm64-otp28.csv)
- [bench/results/apple-arm64-otp28-summary.csv](bench/results/apple-arm64-otp28-summary.csv)

## License

`b64veryfast` keeps the MIT license from the original `b64fast` package; see
[LICENSE](LICENSE). The vendored `aklomp/base64` sources keep their upstream
BSD-2-Clause license notice; see [c_src/aklomp/LICENSE](c_src/aklomp/LICENSE).
