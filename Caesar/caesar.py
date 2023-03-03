
while True:
    pt = input("text: ")
    shift = int(input("shift: "))
    ct = ""
    for letter in pt:
        if 0x41 <= ord(letter) <= 0x5A:
            ct += chr((((ord(letter) - 0x41) + shift ) % 26) + 0x41)
        elif 0x61 <= ord(letter) <= 0x7A:
            ct += chr((((ord(letter)-0x61) + shift ) %26) + 0x61)
        else:
            ct += letter
    
    print(ct)
