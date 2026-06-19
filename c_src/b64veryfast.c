#include <stddef.h>
#include <stdint.h>

#include "erl_nif.h"
#include "aklomp/include/libbase64.h"

#define B64VERYFAST_DIRTY_THRESHOLD (256U * 1024U)

typedef ERL_NIF_TERM (*b64veryfast_nif_fn)(ErlNifEnv*, int, const ERL_NIF_TERM[]);

static ERL_NIF_TERM
enomem(ErlNifEnv* env)
{
    return enif_raise_exception(env, enif_make_atom(env, "enomem"));
}

static int
decoded_size_compat(const ErlNifBinary* in, int flags, size_t* outlen, size_t* srclen)
{
    size_t len = in->size;

    while (len > 0 && in->data[len - 1] == '=') {
        len--;
    }
    if (len < 2) {
        *outlen = 0;
        *srclen = 0;
        return 1;
    }

    *srclen = len;
    return base64_decoded_size((const char*)in->data, len, flags | BASE64_NO_PADDING, outlen);
}

static ERL_NIF_TERM
encode_do(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[], int flags)
{
    ErlNifBinary in;
    ERL_NIF_TERM out_term;
    unsigned char* out;
    size_t outlen;
    size_t written = 0;

    if (argc != 1 || !enif_inspect_binary(env, argv[0], &in)) {
        return enif_make_badarg(env);
    }

    outlen = base64_encoded_size(in.size, flags);
    out = enif_make_new_binary(env, outlen, &out_term);
    if (outlen != 0 && out == NULL) {
        return enomem(env);
    }
    if (outlen == 0) {
        return out_term;
    }

    base64_encode((const char*)in.data, in.size, (char*)out, &written, flags);
    if (written != outlen) {
        return enif_make_badarg(env);
    }
    return out_term;
}

static ERL_NIF_TERM
decode_do(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[], int flags)
{
    ErlNifBinary in;
    ERL_NIF_TERM out_term;
    unsigned char* out;
    size_t outlen;
    size_t srclen;
    size_t written = 0;

    if (argc != 1 || !enif_inspect_binary(env, argv[0], &in)) {
        return enif_make_badarg(env);
    }
    if (!decoded_size_compat(&in, flags, &outlen, &srclen)) {
        return enif_make_badarg(env);
    }

    out = enif_make_new_binary(env, outlen, &out_term);
    if (outlen != 0 && out == NULL) {
        return enomem(env);
    }
    if (outlen == 0) {
        return out_term;
    }

    if (!base64_decode((const char*)in.data, srclen, (char*)out, &written, flags | BASE64_NO_PADDING) ||
        written != outlen) {
        return enif_make_badarg(env);
    }
    return out_term;
}

static ERL_NIF_TERM
encode64_do(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    return encode_do(env, argc, argv, 0);
}

static ERL_NIF_TERM
decode64_do(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    return decode_do(env, argc, argv, 0);
}

static ERL_NIF_TERM
decode64_trusted_do(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    return decode_do(env, argc, argv, BASE64_TRUSTED);
}

static ERL_NIF_TERM
encode64_url_do(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    return encode_do(env, argc, argv, BASE64_URL_NOPAD);
}

static ERL_NIF_TERM
decode64_url_do(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    return decode_do(env, argc, argv, BASE64_URL_NOPAD);
}

static ERL_NIF_TERM
decode64_url_trusted_do(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    return decode_do(env, argc, argv, BASE64_URL_NOPAD | BASE64_TRUSTED);
}

#ifdef ERL_NIF_DIRTY_JOB_CPU_BOUND
static ERL_NIF_TERM
schedule_if_large(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[],
                  b64veryfast_nif_fn run, const char* name)
{
    ErlNifBinary in;

    if (argc != 1 || !enif_inspect_binary(env, argv[0], &in)) {
        return enif_make_badarg(env);
    }
    if (in.size >= B64VERYFAST_DIRTY_THRESHOLD) {
        return enif_schedule_nif(env, name, ERL_NIF_DIRTY_JOB_CPU_BOUND, run, argc, argv);
    }
    return run(env, argc, argv);
}

static ERL_NIF_TERM
encode64(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    return schedule_if_large(env, argc, argv, encode64_do, "encode64_dirty");
}

static ERL_NIF_TERM
decode64(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    return schedule_if_large(env, argc, argv, decode64_do, "decode64_dirty");
}

static ERL_NIF_TERM
decode64_trusted(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    return schedule_if_large(env, argc, argv, decode64_trusted_do, "decode64_trusted_dirty");
}

static ERL_NIF_TERM
encode64_url(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    return schedule_if_large(env, argc, argv, encode64_url_do, "encode64_url_dirty");
}

static ERL_NIF_TERM
decode64_url(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    return schedule_if_large(env, argc, argv, decode64_url_do, "decode64_url_dirty");
}

static ERL_NIF_TERM
decode64_url_trusted(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
    return schedule_if_large(env, argc, argv, decode64_url_trusted_do, "decode64_url_trusted_dirty");
}
#else
#define encode64 encode64_do
#define decode64 decode64_do
#define decode64_trusted decode64_trusted_do
#define encode64_url encode64_url_do
#define decode64_url decode64_url_do
#define decode64_url_trusted decode64_url_trusted_do
#endif

static ErlNifFunc funcs[] = {
    {"encode64", 1, encode64, 0},
    {"decode64", 1, decode64, 0},
    {"decode64_trusted", 1, decode64_trusted, 0},
    {"encode64_url", 1, encode64_url, 0},
    {"decode64_url", 1, decode64_url, 0},
    {"decode64_url_trusted", 1, decode64_url_trusted, 0}
};

ERL_NIF_INIT(b64veryfast, funcs, NULL, NULL, NULL, NULL)
