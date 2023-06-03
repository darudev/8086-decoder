package main

import "core:fmt"
import "core:os"

eac_table := [8]string{
    "bx + si",
    "bx + di",
    "bp + si",
    "bp + di",
    "si",
    "di",
    "bp",
    "bx",
}
word_registers := [8]string{"ax", "cx", "dx", "bx", "sp", "bp", "si", "di"}
byte_registers := [8]string{"al", "cl", "dl", "bl", "ah", "ch", "dh", "bh"}

// OP-codes
// Example: 100010dw >> 2 gives 0010 0010 (0x22)
MOV_REG_MEM_TO_FROM_REG: u8 = 0b0010_0010
MOV_IMMEDIATE_TO_REG: u8 = 0b0000_1011
ADD_REG_MEM_WITH_REG_TO_EITHER: u8 = 0b0000_0000
SUB_REG_MEM_WITH_REG_TO_EITHER: u8 = 0b0000_1010
CMP_REG_MEM_WITH_REG_TO_EITHER: u8 = 0b0000_1110
COMMON_IMMEDIATE_REG_MEM: u8 = 0b0010_0000
ADD_IMMEDIATE_TO_ACCUMULATOR: u8 = 0b000_000_10
SUB_IMMEDIATE_TO_ACCUMULATOR: u8 = 0b000_101_10
CMP_IMMEDIATE_TO_ACCUMULATOR: u8 = 0b000_111_10
JNE: u8 = 0b0111_0101
JE: u8 = 0b0111_0100
JL: u8 = 0b0111_1100
JLE: u8 = 0b0111_1110
JB: u8 = 0b0111_0010
JBE: u8 = 0b0111_0110
JP: u8 = 0b0111_1010
JO: u8 = 0b0111_0000
JS: u8 = 0b0111_1000
JNL: u8 = 0b0111_1101
JG: u8 = 0b0111_1111
JNB: u8 = 0b0111_0011
JA: u8 = 0b0111_0111
JNP: u8 = 0b0111_1011
JNO: u8 = 0b0111_0001
JNS: u8 = 0b0111_1001
LOOP: u8 = 0b1110_0010
LOOPZ: u8 = 0b1110_0001
LOOPNZ: u8 = 0b1110_0000
JCXZ: u8 = 0b1110_0011


main :: proc() {

    // Read instructions file
    bytes, ok := os.read_entire_file_from_filename("instructions")
    if !ok {
        fmt.println("Error opening file.")
        return
    }
    
    // Debug print bytes and bits
    // fmt.printf("------------------------------\n\n")
    // for byte, index in bytes {
    //     fmt.printf("byte_%03d: 0x%02X, bits: %08b\n", index, byte, byte)
    // }
    // fmt.printf("------------------------------\n\n")

    fmt.printf("\n------------- 8086 Decoder -----------------\n")

    // Decode
    i := 0
    for i < len(bytes) {
        if (bytes[i] >> 2) == MOV_REG_MEM_TO_FROM_REG {
            bytes_read := common_disp("mov", bytes, i)
            i += bytes_read
            continue
        }

        if (bytes[i] >> 2) == ADD_REG_MEM_WITH_REG_TO_EITHER {
            bytes_read := common_disp("add", bytes, i)
            i += bytes_read
            continue
        }

        if (bytes[i] >> 2) == SUB_REG_MEM_WITH_REG_TO_EITHER {
            bytes_read := common_disp("sub", bytes, i)
            i += bytes_read
            continue
        }

        if (bytes[i] >> 2) == CMP_REG_MEM_WITH_REG_TO_EITHER {
            bytes_read := common_disp("cmp", bytes, i)
            i += bytes_read
            continue
        }

        if (bytes[i] >> 4) == MOV_IMMEDIATE_TO_REG {
            is_word_operation := bit_is_set(bytes[i], 0b0000_1000)
            reg_field: u8 = (bytes[i] & 0b0000_0111)
            dest, src: string
            if is_word_operation {
                // next bytes
                i += 1
                low_data := bytes[i]

                i += 1
                high_data := bytes[i]

                word_value: u16 = u16(low_data) | (u16(high_data) << 8)
                dest = word_registers[reg_field]
                src = fmt.aprintf("%d", word_value)
            } else {
                i += 1
                dest = byte_registers[reg_field]
                byte_value:= bytes[i]
                src = fmt.aprintf("%d", byte_value)
            }

            fmt.printf("mov %s, %s\n", dest, src)
            i += 1
            continue
        }
        
        if (bytes[i] >> 2) == COMMON_IMMEDIATE_REG_MEM {

            has_sign_extension := bit_is_set(bytes[i], 0b0000_0010)
            is_word_operation := bit_is_set(bytes[i], 0b0000_0001)

            // [MOD REG R/M] byte
            i += 1

            mod_field: u8 = (bytes[i] >> 6)
            reg_field: u8 = (bytes[i] & 0b0011_1000) >> 3
            rm_field: u8 = (bytes[i] & 0b0000_0111)

            name: string
            switch reg_field {
                case 0b000:
                    name = "add"
                case 0b101:
                    name = "sub"
                case 0b111:
                    name = "cmp"
            }

            if (mod_field == 0b00 && rm_field == 0b110) {

                // Next bytes
                i += 1
                low_data := bytes[i]

                i += 1
                high_data := bytes[i]

                direct_address: u16 = u16(low_data) | (u16(high_data) << 8)

                i += 1
                data := bytes[i]

                fmt.printf("%s [%d], %d\n", name, direct_address, data)

                i += 1
                continue
            }

            if (mod_field == 0b00) {
                rm_register := eac_table[rm_field]

                i += 1
                data := bytes[i]

                fmt.printf("%s [%s], %d\n", name, rm_register, data)

                i += 1
                continue
            }

            if (mod_field == 0b10) {
                rm_register := eac_table[rm_field]

                disp_value: u16
                if (is_word_operation) {
                    i += 1
                    disp_low := bytes[i]

                    i += 1
                    disp_high := bytes[i]

                    disp_value = u16(disp_low) | (u16(disp_high) << 8)

                } else {
                    i += 1
                    disp_value := bytes[i]
                }

                i += 1
                data := bytes[i]

                fmt.printf("%s [%s + %d], %d\n", name, rm_register, disp_value, data)

                i += 1
                continue

            }

            if (mod_field == 0b11) {
                rm_register := word_registers[rm_field] if is_word_operation else byte_registers[rm_field]

                if (!has_sign_extension && is_word_operation) {
                    i += 1
                    data_one := bytes[i]

                    i += 1
                    data_two := bytes[i]

                    value: u16 = u16(data_one) | (u16(data_two) << 8)

                    fmt.printf("%s %s, %d\n", name, rm_register, value)

                    i += 1
                    continue
                }

                if (has_sign_extension) {
                    i += 1
                    value := bytes[i]

                    fmt.printf("%s %s, %d\n", name, rm_register, value)

                    i += 1
                    continue
                }
            }
        }

        if (bytes[i] >> 1) == ADD_IMMEDIATE_TO_ACCUMULATOR {
            bytes_read := parse_arithmetic_immediate_to_accumulator("add", bytes, i)
            i += bytes_read
            continue
        }

        if (bytes[i] >> 1) == SUB_IMMEDIATE_TO_ACCUMULATOR {
            bytes_read := parse_arithmetic_immediate_to_accumulator("sub", bytes, i)
            i += bytes_read
            continue
        }

        if (bytes[i] >> 1) == CMP_IMMEDIATE_TO_ACCUMULATOR {
            bytes_read := parse_arithmetic_immediate_to_accumulator("cmp", bytes, i)
            i += bytes_read
            continue
        }

        if (bytes[i]) == JNE {
            i += 1
            value := i8(bytes[i])
            fmt.printf("jne %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == JE {
            i += 1
            value := i8(bytes[i])
            fmt.printf("je %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == JL {
            i += 1
            value := i8(bytes[i])
            fmt.printf("jl %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == JLE {
            i += 1
            value := i8(bytes[i])
            fmt.printf("jle %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == JB {
            i += 1
            value := i8(bytes[i])
            fmt.printf("jb %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == JBE {
            i += 1
            value := i8(bytes[i])
            fmt.printf("jbe %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == JP {
            i += 1
            value := i8(bytes[i])
            fmt.printf("jp %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == JO {
            i += 1
            value := i8(bytes[i])
            fmt.printf("jo %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == JS {
            i += 1
            value := i8(bytes[i])
            fmt.printf("js %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == JNL {
            i += 1
            value := i8(bytes[i])
            fmt.printf("jnl %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == JG {
            i += 1
            value := i8(bytes[i])
            fmt.printf("jg %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == JNB {
            i += 1
            value := i8(bytes[i])
            fmt.printf("jnb %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == JA {
            i += 1
            value := i8(bytes[i])
            fmt.printf("ja %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == JNP {
            i += 1
            value := i8(bytes[i])
            fmt.printf("jnp %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == JNO {
            i += 1
            value := i8(bytes[i])
            fmt.printf("jno %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == JNS {
            i += 1
            value := i8(bytes[i])
            fmt.printf("jns %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == LOOP {
            i += 1
            value := i8(bytes[i])
            fmt.printf("loop %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == LOOPZ {
            i += 1
            value := i8(bytes[i])
            fmt.printf("loopz %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == LOOPNZ {
            i += 1
            value := i8(bytes[i])
            fmt.printf("loopnz %d\n", value)

            i += 1
            continue
        }

        if (bytes[i]) == JCXZ {
            i += 1
            value := i8(bytes[i])
            fmt.printf("jcxz %d\n", value)

            i += 1
            continue
        }
    }
}

