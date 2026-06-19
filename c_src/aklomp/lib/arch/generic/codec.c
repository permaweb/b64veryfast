#include <stdint.h>
#include <stddef.h>
#include <string.h>

#include "../../../include/libbase64.h"
#include "../../tables/tables.h"
#include "../../codecs.h"
#include "config.h"
#include "../../env.h"

#if BASE64_WORDSIZE == 32
#  include "32/enc_loop.c"
#elif BASE64_WORDSIZE == 64
#  include "64/enc_loop.c"
#endif

#if BASE64_WORDSIZE >= 32
#  include "32/dec_loop.c"
#endif

void
base64_stream_encode_plain BASE64_ENC_PARAMS
{
	const uint16_t *enc_table =
		(state->flags & BASE64_URL_SAFE)
			? base64_table_enc_12bit_url
			: base64_table_enc_12bit;

	if (state->flags & BASE64_URL_SAFE) {
		state->flags |= BASE64_INTERNAL_URL_DIRECT;
	}
	#include "enc_head.c"
#if BASE64_WORDSIZE == 32
	enc_loop_generic_32(&s, &slen, &o, &olen, enc_table);
#elif BASE64_WORDSIZE == 64
	enc_loop_generic_64(&s, &slen, &o, &olen, enc_table);
#endif
	#include "enc_tail.c"
}

int
base64_stream_decode_plain BASE64_DEC_PARAMS
{
	#include "dec_head.c"
#if BASE64_WORDSIZE >= 32
	dec_loop_generic_32(&s, &slen, &o, &olen);
#endif
	#include "dec_tail.c"
}
