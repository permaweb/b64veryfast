#!/usr/bin/python3

def tr(x, alphabet):
    """Translate a 6-bit value to the Base64 alphabet."""
    return ord(alphabet[x])

def table(fn):
    """Generate a 12-bit lookup table."""
    ret = []
    for n in range(0, 2**12):
        pre = "\n\t" if n % 8 == 0 else " "
        pre = "\t" if n == 0 else pre
        ret.append("{}0x{:04X}U,".format(pre, fn(n)))
    return "".join(ret)

def table_be(alphabet):
    """Generate a 12-bit big-endian lookup table."""
    return table(lambda n: (tr(n & 0x3F, alphabet) << 0) | (tr(n >> 6, alphabet) << 8))

def table_le(alphabet):
    """Generate a 12-bit little-endian lookup table."""
    return table(lambda n: (tr(n >> 6, alphabet) << 0) | (tr(n & 0x3F, alphabet) << 8))

def emit_table(name, alphabet):
    """Generate one 12-bit lookup table."""
    return [
        "const uint16_t {}[] = {{".format(name),
        "#if BASE64_LITTLE_ENDIAN",
        table_le(alphabet),
        "#else",
        table_be(alphabet),
        "#endif",
        "};",
    ]

def main():
    """Entry point."""
    base64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' \
      + 'abcdefghijklmnopqrstuvwxyz' \
      + '0123456789' \
      + '+/'
    base64url = base64[:-2] + '-_'
    lines = [
        "#include <stdint.h>",
        "",
    ]
    lines.extend(emit_table("base64_table_enc_12bit", base64))
    lines.append("")
    lines.extend(emit_table("base64_table_enc_12bit_url", base64url))
    for line in lines:
        print(line)

if __name__ == "__main__":
    main()
