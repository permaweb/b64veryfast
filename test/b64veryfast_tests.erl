-module(b64veryfast_tests).

-include_lib("eunit/include/eunit.hrl").

bad_encode_test() ->
    ?assertException(error, badarg, b64veryfast:encode64( 42    )),
    ?assertException(error, badarg, b64veryfast:encode64( foo   )),
    ?assertException(error, badarg, b64veryfast:encode64( "foo" )),
    ?assertException(error, badarg, b64veryfast:encode64( {foo} )),
    ?assertException(error, badarg, b64veryfast:encode64_url( 42    )),
    ?assertException(error, badarg, b64veryfast:encode64_url( foo   )),
    ?assertException(error, badarg, b64veryfast:encode64_url( "foo" )),
    ?assertException(error, badarg, b64veryfast:encode64_url( {foo} )).

bad_decode_test() ->
    ?assertException(error, badarg, b64veryfast:decode64( 42    )),
    ?assertException(error, badarg, b64veryfast:decode64( foo   )),
    ?assertException(error, badarg, b64veryfast:decode64( "foo" )),
    ?assertException(error, badarg, b64veryfast:decode64( {foo} )),
    ?assertException(error, badarg, b64veryfast:decode64_unchecked( 42    )),
    ?assertException(error, badarg, b64veryfast:decode64_unchecked( foo   )),
    ?assertException(error, badarg, b64veryfast:decode64_unchecked( "foo" )),
    ?assertException(error, badarg, b64veryfast:decode64_unchecked( {foo} )),
    ?assertException(error, badarg, b64veryfast:decode64_url( 42    )),
    ?assertException(error, badarg, b64veryfast:decode64_url( foo   )),
    ?assertException(error, badarg, b64veryfast:decode64_url( "foo" )),
    ?assertException(error, badarg, b64veryfast:decode64_url( {foo} )),
    ?assertException(error, badarg, b64veryfast:decode64_url_unchecked( 42    )),
    ?assertException(error, badarg, b64veryfast:decode64_url_unchecked( foo   )),
    ?assertException(error, badarg, b64veryfast:decode64_url_unchecked( "foo" )),
    ?assertException(error, badarg, b64veryfast:decode64_url_unchecked( {foo} )).

encode_test() ->
    ?assert(b64veryfast:encode64(<< "zany" >>) =:= << "emFueQ==" >>),
    ?assert(b64veryfast:encode64(<< "zan"  >>) =:= << "emFu"     >>),
    ?assert(b64veryfast:encode64(<< "za"   >>) =:= << "emE="     >>),
    ?assert(b64veryfast:encode64(<< "z"    >>) =:= << "eg=="     >>),
    ?assert(b64veryfast:encode64(<<        >>) =:= <<            >>).

decode_test() ->
    ?assert(b64veryfast:decode64(<< "emFueQ==" >>) =:= << "zany" >>),
    ?assert(b64veryfast:decode64(<< "emFu"     >>) =:= << "zan"  >>),
    ?assert(b64veryfast:decode64(<< "emE="     >>) =:= << "za"   >>),
    ?assert(b64veryfast:decode64(<< "eg=="     >>) =:= << "z"    >>),
    ?assert(b64veryfast:decode64(<<            >>) =:= <<        >>).

decode_unchecked_test() ->
    ?assert(b64veryfast:decode64_unchecked(<< "emFueQ==" >>) =:= << "zany" >>),
    ?assert(b64veryfast:decode64_unchecked(<< "emFu"     >>) =:= << "zan"  >>),
    ?assert(b64veryfast:decode64_unchecked(<< "emE="     >>) =:= << "za"   >>),
    ?assert(b64veryfast:decode64_unchecked(<< "eg=="     >>) =:= << "z"    >>),
    ?assert(b64veryfast:decode64_unchecked(<<            >>) =:= <<        >>).

encode_url_test() ->
    ?assert(b64veryfast:encode64_url(<< "zany" >>) =:= << "emFueQ" >>),
    ?assert(b64veryfast:encode64_url(<< "zan"  >>) =:= << "emFu"   >>),
    ?assert(b64veryfast:encode64_url(<< "za"   >>) =:= << "emE"    >>),
    ?assert(b64veryfast:encode64_url(<< "z"    >>) =:= << "eg"     >>),
    ?assert(b64veryfast:encode64_url(<< 251    >>) =:= << "-w"     >>),
    ?assert(b64veryfast:encode64_url(<< 251, 255 >>) =:= << "-_8"  >>),
    ?assert(b64veryfast:encode64_url(<<        >>) =:= <<          >>).

decode_url_test() ->
    ?assert(b64veryfast:decode64_url(<< "emFueQ" >>) =:= << "zany" >>),
    ?assert(b64veryfast:decode64_url(<< "emFu"   >>) =:= << "zan"  >>),
    ?assert(b64veryfast:decode64_url(<< "emE"    >>) =:= << "za"   >>),
    ?assert(b64veryfast:decode64_url(<< "eg"     >>) =:= << "z"    >>),
    ?assert(b64veryfast:decode64_url(<< "-w"     >>) =:= << 251    >>),
    ?assert(b64veryfast:decode64_url(<< "-w=="   >>) =:= << 251    >>),
    ?assert(b64veryfast:decode64_url(<< "-_8"    >>) =:= << 251, 255 >>),
    ?assert(b64veryfast:decode64_url(<<          >>) =:= <<        >>).

decode_url_unchecked_test() ->
    ?assert(b64veryfast:decode64_url_unchecked(<< "emFueQ" >>) =:= << "zany" >>),
    ?assert(b64veryfast:decode64_url_unchecked(<< "emFu"   >>) =:= << "zan"  >>),
    ?assert(b64veryfast:decode64_url_unchecked(<< "emE"    >>) =:= << "za"   >>),
    ?assert(b64veryfast:decode64_url_unchecked(<< "eg"     >>) =:= << "z"    >>),
    ?assert(b64veryfast:decode64_url_unchecked(<< "-w"     >>) =:= << 251    >>),
    ?assert(b64veryfast:decode64_url_unchecked(<< "-w=="   >>) =:= << 251    >>),
    ?assert(b64veryfast:decode64_url_unchecked(<< "-_8"    >>) =:= << 251, 255 >>),
    ?assert(b64veryfast:decode64_url_unchecked(<<          >>) =:= <<        >>).

decode_url_unchecked_x86_vector_test() ->
    Enc = <<"r9XYa4rlR_uQMFyhEy_B-WHgX7XNIwe7MWiu-Yu2LPhhCQ">>,
    Data =
        <<175,213,216,107,138,229,71,251,144,48,92,161,19,47,193,249,
          97,224,95,181,205,35,7,187,49,104,174,249,139,182,44,248,97,9>>,
    ?assertEqual(Data, b64veryfast:decode64_url(Enc)),
    ?assertEqual(Data, b64veryfast:decode64_url_unchecked(Enc)).

% TODO: skip whitespace
%padded_decode_test() ->
%    ?assert(b64veryfast:decode64(<< " emFu" >>) =:= << "zan" >>),
%    ?assert(b64veryfast:decode64(<< "em Fu" >>) =:= << "zan" >>),
%    ?assert(b64veryfast:decode64(<< "emFu " >>) =:= << "zan" >>),
%    ?assert(b64veryfast:decode64(<< "    "  >>) =:= <<       >>),
%    ?assert(b64veryfast:decode64(<< "   ="  >>) =:= <<       >>),
%    ?assert(b64veryfast:decode64(<< "  =="  >>) =:= <<       >>),
%    ?assert(b64veryfast:decode64(<< "=   "  >>) =:= <<       >>),
%    ?assert(b64veryfast:decode64(<< "==  "  >>) =:= <<       >>).

truncated_decode_test() ->
    ?assert(b64veryfast:decode64(<< "AAAA" >>) =:= << 0,0,0 >>),
    ?assert(b64veryfast:decode64(<< "AAA=" >>) =:= << 0,0   >>),
    ?assert(b64veryfast:decode64(<< "AAA"  >>) =:= << 0,0   >>),
    ?assert(b64veryfast:decode64(<< "AA==" >>) =:= << 0     >>),
    ?assert(b64veryfast:decode64(<< "AA="  >>) =:= << 0     >>),
    ?assert(b64veryfast:decode64(<< "AA"   >>) =:= << 0     >>),
    ?assert(b64veryfast:decode64(<< "A=="  >>) =:= <<       >>),
    ?assert(b64veryfast:decode64(<< "A="   >>) =:= <<       >>),
    ?assert(b64veryfast:decode64(<< "A"    >>) =:= <<       >>),
    ?assert(b64veryfast:decode64(<< "=="   >>) =:= <<       >>),
    ?assert(b64veryfast:decode64(<< "="    >>) =:= <<       >>),
    ?assert(b64veryfast:decode64(<<        >>) =:= <<       >>).

backtoback_encode_test() ->
    Data = binary:copy(<<"0123456789">>, 100000), % 1 MiB of data
    ?assert(base64:encode(Data) =:= b64veryfast:encode64(Data)).

backtoback_decode_test() ->
    Data = binary:copy(<<"0123456789">>, 100000), % 1 MiB of data
%    Enc = b64veryfast:encode64(Data),
    Enc = base64:encode(Data),
    ?assert(base64:decode(Enc) =:= b64veryfast:decode64(Enc)),
    ?assert(Data =:= b64veryfast:decode64_unchecked(Enc)).

backtoback_url_test() ->
    Data = binary:copy(<<"0123456789">>, 100000), % 1 MiB of data
    Enc = url_encode_ref(Data),
    ?assert(Enc =:= b64veryfast:encode64_url(Data)),
    ?assert(Data =:= b64veryfast:decode64_url(Enc)),
    ?assert(Data =:= b64veryfast:decode64_url_unchecked(Enc)).

url_encode_ref(Data) ->
    NoPad = binary:replace(base64:encode(Data), <<"=">>, <<>>, [global]),
    binary:replace(
        binary:replace(NoPad, <<"+">>, <<"-">>, [global]),
        <<"/">>,
        <<"_">>,
        [global]
    ).

speed_test() ->
    Data = binary:copy(<<"0123456789">>, 100000), % 1 MiB of data

    {Elapsed1, Enc1} = timer:tc(base64, encode, [Data]),
    io:fwrite(standard_error, "erlang encode ~B us ~f MiB/s~n",
      [Elapsed1, byte_size(Data) / Elapsed1]),

    {Elapsed2, _Dec1} = timer:tc(base64, decode, [Enc1]),
    io:fwrite(standard_error, "erlang decode ~B us ~f MiB/s~n",
      [Elapsed2, byte_size(Enc1) / Elapsed2]),

    {Elapsed3, Enc2} = timer:tc(b64veryfast, encode64, [Data]),
    io:fwrite(standard_error, "NIF encode ~B us ~f MiB/s~n",
      [Elapsed3, byte_size(Data) / Elapsed3]),

    {Elapsed4, _Dec2} = timer:tc(b64veryfast, decode64, [Enc2]),
    io:fwrite(standard_error, "NIF decode ~B us ~f MiB/s~n",
      [Elapsed4, byte_size(Enc2) / Elapsed4]).

speed10_test() ->
    Data = binary:copy(<<"0123456789">>, 1000000), % 10 MiB of data

    {Elapsed3, Enc2} = timer:tc(b64veryfast, encode64, [Data]),
    io:fwrite(standard_error, "NIF encode ~B us ~f MiB/s~n",
      [Elapsed3, byte_size(Data) / Elapsed3]),

    {Elapsed4, _Dec2} = timer:tc(b64veryfast, decode64, [Enc2]),
    io:fwrite(standard_error, "NIF decode ~B us ~f MiB/s~n",
      [Elapsed4, byte_size(Enc2) / Elapsed4]).

speed100_test() ->
    Data = binary:copy(<<"0123456789">>, 10000000), % 100 MiB of data

    {Elapsed3, Enc2} = timer:tc(b64veryfast, encode64, [Data]),
    io:fwrite(standard_error, "NIF encode ~B us ~f MiB/s~n",
      [Elapsed3, byte_size(Data) / Elapsed3]),

    {Elapsed4, _Dec2} = timer:tc(b64veryfast, decode64, [Enc2]),
    io:fwrite(standard_error, "NIF decode ~B us ~f MiB/s~n",
      [Elapsed4, byte_size(Enc2) / Elapsed4]).
