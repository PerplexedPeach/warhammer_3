import decimal
import random

def format_number(num):
    try:
        dec = decimal.Decimal(num)
    except:
        return 'bad'
    tup = dec.as_tuple()
    delta = len(tup.digits) + tup.exponent
    digits = ''.join(str(d) for d in tup.digits)
    if delta <= 0:
        zeros = abs(tup.exponent) - len(tup.digits)
        val = '0.' + ('0'*zeros) + digits
    else:
        val = digits[:delta] + ('0'*tup.exponent) + '.' + digits[delta:]
    val = val.rstrip('0')
    if val[-1] == '.':
        val = val[:-1]
    if tup.sign:
        return '-' + val
    return val

def tsv_to_media_wiki(raw_str: str):
    headers = ["Effect", "Scope", "Value"]
    lines = [line.split() for line in raw_str.splitlines()]
    out_lines = ['{| class="wikitable"|-', '!' + '!!'.join(headers)]
    for line in lines:
        processed_line = []
        for v in line:
            try:
                processed_line.append(format_number(float(v)))
            except ValueError:
                # TODO convert to icons and localized description
                processed_line.append(v)
        out_lines.append('|-\n|' + '||'.join(processed_line))
    out_lines.append("|}")

    return '\n'.join(out_lines)


print("Paste content. Enter twice after to process it.")
while True:
    contents = []
    while True:
        try:
            line = input()
        except EOFError:
            break
        if line == "":
            break
        contents.append(line)
    print(tsv_to_media_wiki('\n'.join(contents)))
