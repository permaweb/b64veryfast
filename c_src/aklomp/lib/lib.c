#include <stdint.h>
#include <stddef.h>
#ifdef _OPENMP
#include <omp.h>
#endif

#include "../include/libbase64.h"
#include "tables/tables.h"
#include "codecs.h"
#include "env.h"

// These static function pointers are initialized once when the library is
// first used, and remain in use for the remaining lifetime of the program.
// The idea being that CPU features don't change at runtime.
static struct codec codec = { NULL, NULL };

static void
base64_url_translate (char *out, size_t outlen)
{
	size_t i;

	for (i = 0; i < outlen; i++) {
		if (out[i] == '+') {
			out[i] = '-';
		}
		else if (out[i] == '/') {
			out[i] = '_';
		}
	}
}

size_t
base64_encoded_size (size_t srclen, int flags)
{
	if (flags & BASE64_NO_PADDING) {
		const size_t rem = srclen % 3;
		return (srclen / 3) * 4 + (rem ? rem + 1 : 0);
	}
	return ((srclen + 2) / 3) * 4;
}

int
base64_decoded_size (const char *src, size_t srclen, int flags, size_t *outlen)
{
	size_t padding = 0;
	size_t rem;

	if (outlen == NULL) {
		return 0;
	}
	if (srclen == 0) {
		*outlen = 0;
		return 1;
	}

	if (src[srclen - 1] == '=') {
		padding = 1;
		if (srclen >= 2 && src[srclen - 2] == '=') {
			padding = 2;
		}
	}

	if (padding) {
		if (srclen % 4 != 0) {
			return 0;
		}
		*outlen = (srclen / 4) * 3 - padding;
		return 1;
	}

	rem = srclen % 4;
	if (rem == 1 || (rem != 0 && !(flags & BASE64_NO_PADDING))) {
		return 0;
	}
	*outlen = (srclen / 4) * 3 + (rem ? rem - 1 : 0);
	return 1;
}

void
base64_stream_encode_init (struct base64_state *state, int flags)
{
	// If any of the codec flags are set, redo choice:
	if (codec.enc == NULL || flags & 0xFF) {
		codec_choose(&codec, flags);
	}
	state->eof = 0;
	state->bytes = 0;
	state->carry = 0;
	state->flags = flags;
}

void
base64_stream_encode
	( struct base64_state	*state
	, const char		*src
	, size_t		 srclen
	, char			*out
	, size_t		*outlen
	)
{
	codec.enc(state, src, srclen, out, outlen);
}

void
base64_stream_encode_final
	( struct base64_state	*state
	, char			*out
	, size_t		*outlen
	)
{
	uint8_t *o = (uint8_t *)out;

	if (state->bytes == 1) {
		*o++ = base64_table_enc_6bit[state->carry];
		if (state->flags & BASE64_NO_PADDING) {
			*outlen = 1;
			return;
		}
		*o++ = '=';
		*o++ = '=';
		*outlen = 3;
		return;
	}
	if (state->bytes == 2) {
		*o++ = base64_table_enc_6bit[state->carry];
		if (state->flags & BASE64_NO_PADDING) {
			*outlen = 1;
			return;
		}
		*o++ = '=';
		*outlen = 2;
		return;
	}
	*outlen = 0;
}

void
base64_stream_decode_init (struct base64_state *state, int flags)
{
	// If any of the codec flags are set, redo choice:
	if (codec.dec == NULL || flags & 0xFFFF) {
		codec_choose(&codec, flags);
	}
	state->eof = 0;
	state->bytes = 0;
	state->carry = 0;
	state->flags = flags;
}

int
base64_stream_decode
	( struct base64_state	*state
	, const char		*src
	, size_t		 srclen
	, char			*out
	, size_t		*outlen
	)
{
	return codec.dec(state, src, srclen, out, outlen);
}

#ifdef _OPENMP

	// Due to the overhead of initializing OpenMP and creating a team of
	// threads, we require the data length to be larger than a threshold:
	#define OMP_THRESHOLD 20000

	// Conditionally include OpenMP-accelerated codec implementations:
	#include "lib_openmp.c"
#endif

void
base64_encode
	( const char	*src
	, size_t	 srclen
	, char		*out
	, size_t	*outlen
	, int		 flags
	)
{
	size_t s;
	size_t t;
	struct base64_state state;

	#ifdef _OPENMP
	if (srclen >= OMP_THRESHOLD && !(flags & BASE64_URL_NOPAD)) {
		base64_encode_openmp(src, srclen, out, outlen, flags);
		return;
	}
	#endif

	// Init the stream reader:
	base64_stream_encode_init(&state, flags);

	// Feed the whole string to the stream reader:
	base64_stream_encode(&state, src, srclen, out, &s);

	// Finalize the stream by writing trailer if any:
	base64_stream_encode_final(&state, out + s, &t);

	// Final output length is stream length plus tail:
	*outlen = s + t;
	if ((flags & BASE64_URL_SAFE) && !(state.flags & BASE64_INTERNAL_URL_DIRECT)) {
		base64_url_translate(out, *outlen);
	}
}

int
base64_decode
	( const char	*src
	, size_t	 srclen
	, char		*out
	, size_t	*outlen
	, int		 flags
	)
{
	int ret;
	struct base64_state state;

	#ifdef _OPENMP
	if (srclen >= OMP_THRESHOLD && !(flags & BASE64_URL_NOPAD)) {
		return base64_decode_openmp(src, srclen, out, outlen, flags);
	}
	#endif

	// Init the stream reader:
	base64_stream_decode_init(&state, flags);

	// Feed the whole string to the stream reader:
	ret = base64_stream_decode(&state, src, srclen, out, outlen);

	// If when decoding a whole block, we're still waiting for input then fail:
	if (ret && (state.bytes == 0)) {
		return ret;
	}
	if (ret
			&& (flags & BASE64_NO_PADDING)
			&& state.eof == 0
			&& (state.bytes == 2 || state.bytes == 3)) {
		return ret;
	}
	return 0;
}
