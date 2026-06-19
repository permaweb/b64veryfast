#!/usr/bin/env escript
%%! -noshell
-mode(compile).

main(Args) ->
    Out = case Args of
        [Path] -> Path;
        [] -> "bench/results/current.csv"
    end,
    add_path("B64VERYFAST_EBIN", "_build/default/lib/b64veryfast/ebin"),
    add_path("B64FAST_EBIN", "/private/tmp/b64fast-original/_build/default/lib/b64fast/ebin"),
    add_path("B64RS_EBIN", ""),
    application:ensure_all_started(crypto),
    filelib:ensure_dir(Out),
    {ok, Io} = file:open(Out, [write]),
    ok = file:write(Io, "family,library,operation,size_bytes,iterations,run,elapsed_us,mib_per_s\n"),
    Inputs = inputs(),
    Defs = definitions(),
    lists:foreach(fun(Input) ->
        lists:foreach(fun(Def) ->
            benchmark(Io, Input, Def)
        end, Defs)
    end, Inputs),
    ok = file:close(Io).

add_path(Env, Default) ->
    Path = case os:getenv(Env) of
        false -> Default;
        Value -> Value
    end,
    case Path of
        "" -> ok;
        _ -> code:add_patha(filename:absname(Path)), ok
    end.

inputs() ->
    Sizes = [
        16, 23, 32, 45, 64, 91, 128, 181, 256, 362, 512, 724,
        1024, 1448, 2048, 2896, 4096, 5793, 8192, 11585, 16384,
        23170, 32768, 46341, 65536, 92682, 131072, 185364, 262144,
        370728, 524288, 741455, 1048576, 1482910, 2097152, 2965821,
        4194304
    ],
    [{Size, iterations(Size), crypto:strong_rand_bytes(Size)} || Size <- Sizes].

iterations(Size) ->
    TargetBytes = 96 * 1024 * 1024,
    Iters0 = (TargetBytes + Size - 1) div Size,
    erlang:max(8, erlang:min(500000, Iters0)).

definitions() ->
    Std = [
        {"standard", "otp-base64", "encode",
            fun(Bin, _StdEnc, _UrlEnc) -> fun() -> base64:encode(Bin) end end},
        {"standard", "otp-base64", "decode",
            fun(_Bin, StdEnc, _UrlEnc) -> fun() -> base64:decode(StdEnc) end end}
    ],
    StdB64Fast = case has_module(b64fast) of
        true ->
            [
                {"standard", "b64fast", "encode",
                    fun(Bin, _StdEnc, _UrlEnc) -> fun() -> b64fast:encode64(Bin) end end},
                {"standard", "b64fast", "decode",
                    fun(_Bin, StdEnc, _UrlEnc) -> fun() -> b64fast:decode64(StdEnc) end end}
            ];
        false -> []
    end,
    StdVeryFast = [
        {"standard", "b64veryfast", "encode",
            fun(Bin, _StdEnc, _UrlEnc) -> fun() -> b64veryfast:encode64(Bin) end end},
        {"standard", "b64veryfast", "decode",
            fun(_Bin, StdEnc, _UrlEnc) -> fun() -> b64veryfast:decode64(StdEnc) end end}
    ],
    Url = [
        {"base64url", "otp-base64-url", "encode",
            fun(Bin, _StdEnc, _UrlEnc) ->
                fun() -> base64:encode(Bin, #{mode => urlsafe, padding => false}) end
            end},
        {"base64url", "otp-base64-url", "decode",
            fun(_Bin, _StdEnc, UrlEnc) ->
                fun() -> base64:decode(UrlEnc, #{mode => urlsafe, padding => false}) end
            end}
    ],
    UrlB64Rs = case has_module(b64rs) of
        true ->
            [
                {"base64url", "b64rs", "encode",
                    fun(Bin, _StdEnc, _UrlEnc) -> fun() -> b64rs:encode(Bin) end end},
                {"base64url", "b64rs", "decode",
                    fun(_Bin, _StdEnc, UrlEnc) -> fun() -> b64rs:decode(UrlEnc) end end}
            ];
        false -> []
    end,
    UrlVeryFast = [
        {"base64url", "b64veryfast-url", "encode",
            fun(Bin, _StdEnc, _UrlEnc) -> fun() -> b64veryfast:encode64_url(Bin) end end},
        {"base64url", "b64veryfast-url", "decode",
            fun(_Bin, _StdEnc, UrlEnc) -> fun() -> b64veryfast:decode64_url(UrlEnc) end end}
    ],
    Std ++ StdB64Fast ++ StdVeryFast ++ Url ++ UrlB64Rs ++ UrlVeryFast.

has_module(Mod) ->
    case code:ensure_loaded(Mod) of
        {module, Mod} -> true;
        _ -> false
    end.

benchmark(Io, {Size, Iters, Bin}, {Family, Library, Operation, MakeFun}) ->
    StdEnc = base64:encode(Bin),
    UrlEnc = base64:encode(Bin, #{mode => urlsafe, padding => false}),
    Fun = MakeFun(Bin, StdEnc, UrlEnc),
    warmup(Fun, erlang:min(Iters, 5000)),
    lists:foreach(fun(Run) ->
        erlang:garbage_collect(),
        {Elapsed, _LastSize} = timer:tc(fun() ->
            Last = loop(Fun, Iters, <<>>),
            byte_size(Last)
        end),
        MiBPerS = (Size * Iters * 1000000) / Elapsed / 1048576,
        file:write(Io, io_lib:format("~s,~s,~s,~B,~B,~B,~B,~.6f~n", [
            Family, Library, Operation, Size, Iters, Run, Elapsed, MiBPerS
        ]))
    end, lists:seq(1, 5)).

warmup(Fun, Iters) ->
    _ = loop(Fun, Iters, <<>>),
    ok.

loop(_Fun, 0, Last) ->
    Last;
loop(Fun, Iters, _Last) ->
    loop(Fun, Iters - 1, Fun()).
