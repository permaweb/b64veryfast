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
        16, 17, 19, 20, 22, 23, 25, 27, 29, 32, 34, 37,
        40, 43, 46, 50, 53, 58, 62, 67, 72, 78, 84, 91,
        98, 105, 113, 122, 132, 142, 153, 165, 178, 192, 207, 224,
        241, 260, 280, 302, 326, 351, 379, 408, 440, 475, 512, 552,
        595, 642, 692, 746, 805, 868, 935, 1009, 1088, 1173, 1264, 1363,
        1470, 1585, 1709, 1843, 1987, 2143, 2310, 2491, 2686, 2896, 3123, 3367,
        3631, 3915, 4096, 4552, 4908, 5292, 5706, 6152, 6634, 7153, 7713, 8316,
        8967, 9669, 10425, 11241, 12121, 13069, 14092, 15195, 16384, 17666, 19049, 20539,
        22146, 23879, 25748, 27763, 29935, 32278, 34804, 37527, 40464, 43630, 47045, 50726,
        54695, 58975, 65536, 68567, 73932, 79717, 85956, 92682, 99935, 107755, 116187, 125279,
        135082, 145653, 157051, 169340, 182592, 196880, 212286, 228898, 246810, 266124, 286949, 309404,
        333615, 359722, 387871, 418223, 450950, 486238, 524288, 565315, 609553, 657252, 708684, 764140,
        823937, 888412, 957933, 1048576, 1113721, 1200873, 1294845, 1396170, 1505425, 1623229, 1750251, 1887213,
        2034893, 2194130, 2365827, 2550960, 2750580, 2965821, 3197905, 3448150, 3717978, 4008921, 4194304, 4660890,
        5025618, 5418887, 5842931, 6300158, 6793164, 7324749, 7897932, 8388608, 9182368, 9900915, 10675691, 11511095,
        12411872, 13383138, 14430407, 15559629, 16777216
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
            fun(_Bin, StdEnc, _UrlEnc) -> fun() -> b64veryfast:decode64(StdEnc) end end},
        {"standard", "b64veryfast-trusted", "decode",
            fun(_Bin, StdEnc, _UrlEnc) -> fun() -> b64veryfast:decode64_trusted(StdEnc) end end}
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
            fun(_Bin, _StdEnc, UrlEnc) -> fun() -> b64veryfast:decode64_url(UrlEnc) end end},
        {"base64url", "b64veryfast-url-trusted", "decode",
            fun(_Bin, _StdEnc, UrlEnc) -> fun() -> b64veryfast:decode64_url_trusted(UrlEnc) end end}
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
