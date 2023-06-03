package main

import "core:fmt"

bit_is_set :: proc(byte: u8, mask: u8) -> bool {
    if (byte & mask) > 0 {
        return true
    } else {
        return false
    }
}

parse_dest_src_displacement :: proc(reg_holds_destination: bool, reg_register: string, rm_register: string, value: u16 = 0) -> string {
    dest, src: string
    if reg_holds_destination {
        dest = reg_register
        if (value > 0) {
            src = fmt.aprintf("[%s + %d]", rm_register, value)
        } else {
            src = fmt.aprintf("[%s]", rm_register)
        }
    } else {
        src = reg_register
        if (value > 0) {
            dest = fmt.aprintf("[%s + %d]", rm_register, value)
        } else {
            dest = fmt.aprintf("[%s]", rm_register)
        }
    }

    return fmt.aprintf("%s, %s", dest, src)
}

common_disp :: proc(name: string, bytes: []u8, pos: int) -> int {
    bytes_read := 0
    i := pos

    // OPCODE byte
    reg_holds_destination := bit_is_set(bytes[i], 0b00000010)
    is_word_operation := bit_is_set(bytes[i], 0b00000001)

    // [MOD REG R/M] byte
    i += 1
    bytes_read += 1

    mod_field: u8 = (bytes[i] >> 6)
    reg_field: u8 = (bytes[i] & 0b0011_1000) >> 3
    rm_field: u8 = (bytes[i] & 0b0000_0111)

    // Special asterisk* case
    if mod_field == 0b00 && rm_field == 0b110 {
        reg_register := word_registers[reg_field]

        // Next bytes
        i += 1
        bytes_read += 1
        low_data := bytes[i]

        i += 1
        bytes_read += 1
        high_data := bytes[i]

        direct_address: u16 = u16(low_data) | (u16(high_data) << 8)

        fmt.printf("%s %s, [%d]\n", name, reg_register, direct_address)
        bytes_read += 1
        return bytes_read

    }

    if mod_field == 0b00 {
        reg_register := word_registers[reg_field] if is_word_operation else byte_registers[reg_field]
        rm_register := eac_table[rm_field]

        operands := parse_dest_src_displacement(reg_holds_destination, reg_register, rm_register)
        fmt.printf("%s %s\n", name, operands)
        bytes_read += 1
        return bytes_read
    }

    if mod_field == 0b01 {
        reg_register := word_registers[reg_field] if is_word_operation else byte_registers[reg_field]
        rm_register := eac_table[rm_field]

        // Next byte
        i += 1
        bytes_read += 1
        byte_value := bytes[i]

        operands := parse_dest_src_displacement(reg_holds_destination, reg_register, rm_register, u16(byte_value))
        fmt.printf("%s %s\n", name, operands)
        bytes_read += 1
        return bytes_read
    }
    
    if mod_field == 0b10 {
        reg_register := word_registers[reg_field] if is_word_operation else byte_registers[reg_field]
        rm_register := eac_table[rm_field]

        // Next bytes
        i += 1
        bytes_read += 1
        low_data := bytes[i]

        i += 1
        bytes_read += 1
        high_data := bytes[i]

        word_value: u16 = u16(low_data) | (u16(high_data) << 8)
    
        operands := parse_dest_src_displacement(reg_holds_destination, reg_register, rm_register, word_value)
        fmt.printf("%s %s\n", name, operands)
        bytes_read += 1
        return bytes_read
    }

    if mod_field == 0b11 {
        reg_register := word_registers[reg_field] if is_word_operation else byte_registers[reg_field]
        rm_register := word_registers[rm_field] if is_word_operation else byte_registers[rm_field]

        dest, src: string
        if reg_holds_destination {
            dest = reg_register
            src = rm_register
        } else {
            dest = rm_register
            src = reg_register
        }

        fmt.printf("%s %s, %s\n", name, dest, src)
        bytes_read += 1
        return bytes_read
    }

    return bytes_read
}


parse_arithmetic_immediate_to_accumulator :: proc(name: string, bytes: []u8, pos: int) -> int {
    bytes_read := 0
    i := pos

    is_word_operation := bit_is_set(bytes[i], 0b0000_0001)


    if (is_word_operation) {

        i += 1
        data_one := bytes[i]
        bytes_read += 1

        i += 1
        data_two := bytes[i]
        bytes_read += 1

        value: u16 = u16(data_one) | (u16(data_two) << 8)

        fmt.printf("%s ax, %d\n", name, value)

        i += 1
        bytes_read += 1
    } else {

        i += 1
        value := bytes[i]
        bytes_read += 1

        fmt.printf("%s al, %d\n", name, value)

        i += 1
        bytes_read += 1
    }

    return bytes_read
}












