#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>

#define MAX_FILE_SIZE 1024
#define INSTRUCTION_MAX 1

char* eac_table[8] = {
    [0] = "bx + si",
    [1] = "bx + di",
    [2] = "bp + si",
    [3] = "bp + di",
    [4] = "si",
    [5] = "di",
    [6] = "bp",
    [7] = "bx",
};

char* word_registers[8] = {"ax", "cx", "dx", "bx", "sp", "bp", "si", "di"};
char* byte_registers[8] = {"al", "cl", "dl", "bl", "ah", "ch", "dh", "bh"};

int read_instructions(char* input_filename, uint8_t* bytes, size_t* bytes_count);
void parse_byte_bit_pattern(uint8_t byte, bool result[8]);
void print_byte_and_bit_pattern(FILE* log, uint8_t byte, bool* bit_pattern, size_t length);
void parse_3_bit_pattern(uint8_t value, bool result[3]);
void print_word_registers(void);
void print_byte_registers(void);


int main(int argc, char *argv[]) {


    uint8_t mov_reg_mem_to_from_reg = 0x22;         // 0010 0010
    uint8_t mov_immediate_to_reg_mem = 0x63;        // 0110 0011
    uint8_t mov_immediate_to_reg = 0x0B;            // 0000 1011
    uint8_t add_reg_mem_with_reg_to_either = 0x0;   // 0000 0000
    uint8_t add_immediate_to_reg_mem = 0x20;        // 0010 0000


    // Get the file name to read argument
    if (argc != 2) {
        fprintf(stdout, "Usage: ./8086simulator input_file\n");
        return EXIT_FAILURE;
    }
    char* input_filename = argv[1];

    // Read instructions binary file and store the bytes in an array
    uint8_t bytes[MAX_FILE_SIZE] = {0};
    size_t bytes_count;
    if (read_instructions(input_filename, bytes, &bytes_count) != 0) {
        return EXIT_FAILURE;
    }

    printf("Read %zu bytes\n", bytes_count);

    // Assambly output file
    FILE* output = fopen("output.asm", "wa");
    fprintf(output, "bits 16\n");

    // Debug print bytes and bit fields to file
    FILE* debug_print = fopen("debug_print.txt", "wa");
    for (size_t i = 0; i < bytes_count; i++) {
        bool bit_pattern[8];
        parse_byte_bit_pattern(bytes[i], bit_pattern);
        print_byte_and_bit_pattern(debug_print, bytes[i], bit_pattern, 8);
    }
    fclose(debug_print);

    // Loop through our bytes
    size_t i = 0;
    while (i < bytes_count) {
        bool bit_pattern[8];
        parse_byte_bit_pattern(bytes[i], bit_pattern);

        // Move: Register/Memory to/from Register
        if ((bytes[i] >> 2) == mov_reg_mem_to_from_reg) {
            bool reg_holds_dest = bit_pattern[6];
            bool is_word_operation = bit_pattern[7];

            // Parse next byte
            parse_byte_bit_pattern(bytes[++i], bit_pattern);

            uint8_t mod_field = (bytes[i] >> 6);
            uint8_t reg_field = (bytes[i] & 0x38) >> 3;
            uint8_t rm_field = (bytes[i] & 0x07);

            // Direct address
            if ((mod_field == 0x0) && (rm_field == 0x6)) {
                // 16 bit displacement, read two more byte
                uint8_t disp_lo_byte = bytes[++i];
                uint8_t disp_hi_byte = bytes[++i];
                uint16_t two_byte_displacement = disp_hi_byte << 8 | disp_lo_byte;
                fprintf(output, "mov %s, [%u]\n", word_registers[reg_field], two_byte_displacement);
                i++;
                continue;
            }

            // Register mode, no displacement
            if (mod_field == 0x03) {
                char* reg_operand = is_word_operation ? word_registers[reg_field]: byte_registers[reg_field]; 
                char* rm_operand = is_word_operation ? word_registers[rm_field]: byte_registers[rm_field];
                if (reg_holds_dest) {
                    fprintf(output, "mov %s, %s\n", reg_operand, rm_operand);
                } else {
                    fprintf(output, "mov %s, %s\n", rm_operand, reg_operand);
                }
                i++;
                continue;
            }
            
            // Effective Address Calculation
            char* eac_operand = eac_table[rm_field];
            char* reg_operand = is_word_operation ? word_registers[reg_field]: byte_registers[reg_field];

            if (mod_field == 0x0) {
                if (reg_holds_dest) {
                    fprintf(output, "mov %s, [%s]\n", reg_operand, eac_operand);
                } else {
                    fprintf(output, "mov [%s], %s\n", eac_operand, reg_operand);
                }
                i++;
                continue;
            }

            if (mod_field == 0x1) {
                // 8 bit displacement, read one more byte
                uint8_t disp_lo_byte = bytes[++i];
                if (reg_holds_dest) {
                    if (disp_lo_byte) {
                        fprintf(output, "mov %s, [%s + %u]\n", reg_operand, eac_operand, disp_lo_byte);
                    } else {
                        fprintf(output, "mov %s, [%s]\n", reg_operand, eac_operand);
                    }
                } else {
                    if (disp_lo_byte) {
                        fprintf(output, "mov [%s + %u], %s\n", eac_operand, disp_lo_byte, reg_operand);
                    } else {
                        fprintf(output, "mov [%s], %s\n", eac_operand, reg_operand);
                    }
                }
                i++;
                continue;
            }

            if (mod_field == 0x2) {
                // 16 bit displacement, read two more byte
                uint8_t disp_lo_byte = bytes[++i];
                uint8_t disp_hi_byte = bytes[++i];
                uint16_t two_byte_displacement = disp_hi_byte << 8 | disp_lo_byte;
                if (reg_holds_dest) {
                    if (two_byte_displacement) {
                        fprintf(output, "mov %s, [%s + %u]\n", reg_operand, eac_operand, two_byte_displacement);
                    } else {
                        fprintf(output, "mov %s, [%s]\n", reg_operand, eac_operand);
                    }
                } else {
                    if (two_byte_displacement) {
                        fprintf(output, "mov [%s + %u], %s\n", eac_operand, two_byte_displacement, reg_operand);
                    } else {
                        fprintf(output, "mov [%s], %s\n", eac_operand, reg_operand);
                    }
                }
                i++;
                continue;
            }
        }


        // Move: Immediate to register/memory
        if ((bytes[i] >> 1) == mov_immediate_to_reg_mem) {
            printf("current byte is %zu: %02X\n", i, bytes[i]);
            printf("byte: %zu: %02X\n", i+1, bytes[i]);
        }

        // Move: Immediate to register
        if ((bytes[i] >> 4) == mov_immediate_to_reg) {
            bool is_word_operation = (bytes[i] & 0x08) ? true : false;
            uint8_t reg_field = bytes[i] & 0x07;

            if (is_word_operation) {
                uint8_t low_data = bytes[++i];
                uint8_t high_data = bytes[++i];
                uint16_t word_value = (high_data << 8) | low_data;
                fprintf(output, "mov %s, %u\n", word_registers[reg_field], word_value);
            } else {
                uint8_t byte_value = bytes[++i];
                fprintf(output, "mov %s, %u\n", byte_registers[reg_field], byte_value);
            }
            i++;
            continue;
        }

        // Add: Reg/memory with register to either
        if ((bytes[i] >> 2) == add_reg_mem_with_reg_to_either) {
            bool is_word_operation = (bytes[i] & 0x01) ? true : false;
            bool reg_holds_dest = (bytes[i] & 0x02) ? true : false;

            // Next byte
            i++;

            uint8_t mod_field = (bytes[i] >> 6);
            uint8_t reg_field = (bytes[i] & 0x38) >> 3;
            uint8_t rm_field = (bytes[i] & 0x07);

            char* eac_operand = eac_table[rm_field];
            char* reg_operand = is_word_operation ? word_registers[reg_field]: byte_registers[reg_field];

            if (mod_field == 0x0) {
                if (reg_holds_dest) {
                    fprintf(output, "add %s, [%s]\n", reg_operand, eac_operand);
                } else {
                    fprintf(output, "add [%s], %s\n", eac_operand, reg_operand);
                }
                i++;
                continue;
            }

            if (mod_field == 0x1) {
                // Read DISP-LO byte
                uint8_t disp_lo_byte = bytes[++i];
                if (reg_holds_dest) {
                    fprintf(output, "add %s, [%s + %u]\n", reg_operand, eac_operand, disp_lo_byte);
                } else {
                    fprintf(output, "add [%s + %u], %s\n", eac_operand, disp_lo_byte, reg_operand);
                }
                i++;
                continue;
            }

            if (mod_field == 0x2) {
                // Read DISP-LO byte and DISP-HI byte
                uint8_t disp_lo_byte = bytes[++i];
                uint8_t disp_hi_byte = bytes[++i];
                uint16_t two_byte_displacement = disp_hi_byte << 8 | disp_lo_byte;
                if (reg_holds_dest) {
                    fprintf(output, "add %s, [%s + %u]\n", reg_operand, eac_operand, disp_lo_byte);
                } else {
                    fprintf(output, "add [%s + %u], %s\n", eac_operand, disp_lo_byte, reg_operand);
                }
                i++;
                continue;
            }

            if (mod_field == 0x03) {
                // TODO: Untested
                char* reg_operand = is_word_operation ? word_registers[reg_field]: byte_registers[reg_field]; 
                char* rm_operand = is_word_operation ? word_registers[rm_field]: byte_registers[rm_field];
                if (reg_holds_dest) {
                    fprintf(output, "add %s, %s\n", reg_operand, rm_operand);
                } else {
                    fprintf(output, "add %s, %s\n", rm_operand, reg_operand);
                }
                i++;
                continue;
            }
        }

        // Add: Reg/memory with register to either
        // TODO: I happen to know it's gonna be an add. But when adding sub and cmp
        // we must check the reg field to determine if it's a add, sub or cmp opcode.
        if ((bytes[i] >> 2) == add_immediate_to_reg_mem) {
            bool is_word_operation = (bytes[i] & 0x01) ? true : false;
            //bool is_sign = (bytes[i] & 0x02) ? true : false;

            // Next byte
            i++;

            uint8_t mod_field = (bytes[i] >> 6);
            //uint8_t reg_field = (bytes[i] & 0x38) >> 3;
            uint8_t rm_field = (bytes[i] & 0x07);

            if (mod_field == 0x03) {
                char* rm_operand = is_word_operation ? word_registers[rm_field]: byte_registers[rm_field];
                i++;
                uint8_t data = bytes[i];
                fprintf(output, "add %s, %u\n", rm_operand, data);
            }
        }

        i++;
    }

    // Clean up and exit
    fclose(output);
    return EXIT_SUCCESS;
}

int read_instructions(char* input_filename, uint8_t* bytes, size_t* bytes_count) {
    uint8_t byte;
    size_t read_single_byte = 1;
    FILE *fp;

    // Open file and handle errors
    fp = fopen(input_filename, "rb");
    if (!fp) {
        perror("fopen() failed");
        return 1;
    }

    // Start reading into bytes array
    size_t i = 0;
    while (1) {
        size_t bytes_read = fread(&byte, sizeof byte, read_single_byte, fp);
        if (bytes_read != read_single_byte) {
            // Error or EOF. We only care for errors.
            // QUESTION: Can we even have error if reading one byte each time?
            if (ferror(fp)) {
                fprintf(stderr, "Error reading %s\n", input_filename);
            }

            // Either way, get out of this loop as we have read
            // our bytes (EOF) or we encountered an error.
            break;
        } else {
            // Success
            bytes[i] = byte;
            i++;
        }
    }

    // Populate bytes_count variable
    *bytes_count = i;

    fclose(fp);
    return 0;
}

void parse_byte_bit_pattern(uint8_t byte, bool result[8]) {
    for (int i = 7, j = 0; i >= 0; i--, j++) {
        int andmask = 1 << i;
        int andmask_result = byte & andmask;
        if (andmask_result == 0) {
            result[j] = false;
        } else {
            result[j] = true;
        }
    }
}

void print_byte_and_bit_pattern(FILE* dest, uint8_t byte, bool* bit_pattern, size_t length) {
    fprintf(dest, "0x%02X: ", byte);
    size_t j = 0;
    for (size_t i = 0; i < length; i++) {
        if (j == 3) {
            fprintf(dest, "%d ", bit_pattern[i]);
            j = 0;
        } else {
            fprintf(dest, "%d", bit_pattern[i]);
            j++;
        }
    }
    fprintf(dest, "\n");
}
