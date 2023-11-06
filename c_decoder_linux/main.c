// clear && nasm instructions.asm && gcc main.c -std=c11 -g3 -Wall -Wextra -pedantic -fsanitize=address,undefined -o decoder && ./decoder

#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>

typedef uint8_t U8;
typedef uint16_t U16;
typedef int8_t S8;
typedef int16_t S16;
typedef size_t USIZE;

#define MAX_INSTRUCTION_FILE_SIZE 1024

USIZE read_instruction_bytes(U8 *bytes);
void debug_print_byte(U8 byte);

char *eac_table[8] = {
 [0] = "bx + si",
 [1] = "bx + di",
 [2] = "bp + si",
 [3] = "bp + di",
 [4] = "si",
 [5] = "di",
 [6] = "bp",
 [7] = "bx",
};

char *word_registers[8] = {"ax", "cx", "dx", "bx", "sp", "bp", "si", "di"};
char *byte_registers[8] = {"al", "cl", "dl", "bl", "ah", "ch", "dh", "bh"};

char *instruction_name[256] = {
 [0] = "add",  
 [5] = "sub",  
 [7] = "cmp",  
};

U8 MOV_REG_MEM_TO_FROM_REG = 0x22; // 0b0010_0010 
U8 MOV_IMMEDIATE_TO_REG = 0x0B; // 0b0000_1011
U8 COMMON_IMMEDIATE_REG_MEM = 0x20; // 0b0010_0000
U8 ADD_REG_MEM_WITH_REGISTER_TO_EITHER = 0x00;
U8 SUB_REG_MEM_WITH_REGISTER_TO_EITHER = 0x0A; // 0b0000_1010
U8 CMP_REG_MEM_WITH_REGISTER_TO_EITHER = 0x0E; // 0b0000_1110
U8 ADD_IMMEDIATE_TO_ACCUMULATOR = 0x02; // 0b0000_0010
U8 SUB_IMMEDIATE_FROM_ACCUMULATOR = 0x16; // 0b0001_0110
U8 CMP_IMMEDIATE_WITH_ACCUMULATOR = 0x1E; // 0b0001_1110
U8 JNE = 0x75; // 0b0111_0101
U8 JE = 0x74; // 0b0111_0100
U8 JL = 0x7C; // 0b0111_1100
U8 JLE = 0x7E; // 0b0111_1110
U8 JB = 0x72; // 0b0111_0010
U8 JBE = 0x76; // 0b0111_0110
U8 JP = 0x7A; // 0b0111_1010
U8 JO = 0x70; // 0b0111_0000
U8 JS = 0x78; // 0b0111_1000
U8 JNL = 0x7D; // 0b0111_1101
U8 JG = 0x7F; // 0b0111_1111
U8 JNB = 0x73; // 0b0111_0011
U8 JA = 0x77; // 0b0111_0111
U8 JNP = 0x7B; // 0b0111_1011
U8 JNO = 0x71; // 0b0111_0001
U8 JNS = 0x79; // 0b0111_1001
U8 LOOP = 0xE2; // 0b1110_0010
U8 LOOPZ = 0xE1; // 0b1110_0001
U8 LOOPNZ = 0xE0; // 0b1110_0000
U8 JCXZ = 0xE3; // 0b1110_0011
                                   
USIZE common_displacement(char *name, U8 *bytes, USIZE pos);
USIZE common_immediate(U8 *bytes, USIZE pos);
USIZE mov_immediate_to_reg(U8 *bytes, USIZE pos);
USIZE immediate_accumulator(char *name, U8 *bytes, USIZE pos);

int main()
{

 U8 bytes[MAX_INSTRUCTION_FILE_SIZE] = {0};
 USIZE bytes_read = read_instruction_bytes(bytes);
 if(bytes_read == 0)
 {
  printf("Zero bytes read\n");
  return 1;
 }

 for(USIZE i = 0; i < bytes_read; i++)
 {
  debug_print_byte(bytes[i]);
 }
 
 USIZE pos = 0;
 while(pos < bytes_read)
 {
  // Instruction decoding
  if((bytes[pos] >> 2) == MOV_REG_MEM_TO_FROM_REG)
  {
   pos = common_displacement("mov", bytes, pos);
   pos++;
   continue;
  }

  if((bytes[pos] >> 4) == MOV_IMMEDIATE_TO_REG)
  {
   pos = mov_immediate_to_reg(bytes, pos);
   pos++;
   continue;
  }

  if((bytes[pos] >> 2) == ADD_REG_MEM_WITH_REGISTER_TO_EITHER)
  {
   pos = common_displacement("add", bytes, pos);
   pos++;
   continue;
  }

  if((bytes[pos] >> 2) == SUB_REG_MEM_WITH_REGISTER_TO_EITHER)
  {
   pos = common_displacement("sub", bytes, pos);
   pos++;
   continue;
  }

  if((bytes[pos] >> 2) == CMP_REG_MEM_WITH_REGISTER_TO_EITHER)
  {
   pos = common_displacement("cmp", bytes, pos);
   pos++;
   continue;
  }

  if((bytes[pos] >> 2) == COMMON_IMMEDIATE_REG_MEM)
  {
   pos = common_immediate(bytes, pos);
   pos++;
   continue;
  }

  if((bytes[pos] >> 1) == ADD_IMMEDIATE_TO_ACCUMULATOR)
  {
   pos = immediate_accumulator("add", bytes, pos);
   pos++;
   continue;
  }

  if((bytes[pos] >> 1) == SUB_IMMEDIATE_FROM_ACCUMULATOR)
  {
   pos = immediate_accumulator("sub", bytes, pos);
   pos++;
   continue;
  }

  if((bytes[pos] >> 1) == CMP_IMMEDIATE_WITH_ACCUMULATOR)
  {
   pos = immediate_accumulator("cmp", bytes, pos);
   pos++;
   continue;
  }

  if(bytes[pos] == JNE)
  {
   S8 value = bytes[++pos];
   printf("jne %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == JE)
  {
   S8 value = bytes[++pos];
   printf("je %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == JL)
  {
   S8 value = bytes[++pos];
   printf("jl %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == JLE)
  {
   S8 value = bytes[++pos];
   printf("jle %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == JB)
  {
   S8 value = bytes[++pos];
   printf("jb %i\n", value);
   pos++;
   continue;
  }
 
  if(bytes[pos] == JBE)
  {
   S8 value = bytes[++pos];
   printf("jbe %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == JP)
  {
   S8 value = bytes[++pos];
   printf("jp %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == JO)
  {
   S8 value = bytes[++pos];
   printf("jo %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == JS)
  {
   S8 value = bytes[++pos];
   printf("js %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == JNL)
  {
   S8 value = bytes[++pos];
   printf("jnl %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == JG)
  {
   S8 value = bytes[++pos];
   printf("jg %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == JNB)
  {
   S8 value = bytes[++pos];
   printf("jnb %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == JA)
  {
   S8 value = bytes[++pos];
   printf("ja %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == JNP)
  {
   S8 value = bytes[++pos];
   printf("jnp %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == JNO)
  {
   S8 value = bytes[++pos];
   printf("jno %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == JNS)
  {
   S8 value = bytes[++pos];
   printf("jns %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == LOOP)
  {
   S8 value = bytes[++pos];
   printf("loop %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == LOOPZ)
  {
   S8 value = bytes[++pos];
   printf("loopz %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == LOOPNZ)
  {
   S8 value = bytes[++pos];
   printf("loopnz %i\n", value);
   pos++;
   continue;
  }

  if(bytes[pos] == JCXZ)
  {
   S8 value = bytes[++pos];
   printf("jcxz %i\n", value);
   pos++;
   continue;
  }
 }
 
 return 0;
}

USIZE common_displacement(char *name, U8 *bytes, USIZE pos)
{
 bool instruction_destination_is_in_reg_field = (bytes[pos] & 0x2); // 0b0000_00010
 bool word_data = (bytes[pos] & 0x1); // 0b0000_0001                                                                  
                                    
 pos++;
 U8 mod_field = (bytes[pos] >> 6);
 U8 reg_field = (bytes[pos] & 0x38) >> 3; // 0b0011_1000 = 0x38
 U8 rm_field = (bytes[pos] & 0x07); // 0b0000_0111

 if(mod_field == 0x00 && rm_field == 0x06)
 {
  // 16-bit displacement. Therefore word register. 
  // And rm_field is direct address so destination must be in reg_field.
  // Example: mov bp, [5]    -> 0x8B 0x2E 0x05 0x00
  // Example: mov bx, [3458] -> 0x8B 0x1E 0x82 0x0D
  U16 disp_low = bytes[++pos];
  U16 disp_high = bytes[++pos];
  U16 displacement = (disp_high << 8) | disp_low;
  printf("%s %s, [%u]\n", name, word_registers[reg_field], displacement);
  return pos;
 } 

 if(mod_field == 0x00) 
 {
  // Example: mov al, [bx + si]
  // Example: mov bx, [bp + di]
 
  char *rm_str = eac_table[rm_field];

  char *reg_str;
  if(word_data)
  {
   reg_str = word_registers[reg_field];
  }  
  else
  {
   reg_str = byte_registers[reg_field];
  }

  if(instruction_destination_is_in_reg_field)
  {
   printf("%s %s, [%s]\n", name, reg_str, rm_str);
   return pos;
  }
  else
  {
   printf("%s [%s], %s\n", name, rm_str, reg_str);
   return pos;
  }
 }

 if(mod_field == 0x01)
 {
  // Example: mov dx, [bp]
  // Example: mov ah, [bx + si + 4]
  char *rm_str = eac_table[rm_field];

  char *reg_str;
  if(word_data)
  {
   reg_str = word_registers[reg_field];
  }  
  else
  {
   reg_str = byte_registers[reg_field];
  }

  U8 displacement = bytes[++pos];

  if(instruction_destination_is_in_reg_field)
  {
   if(displacement)
   {
    printf("%s %s, [%s + %u]\n", name, reg_str, rm_str, displacement);
    return pos;
   }
   else
   {
    printf("%s %s, [%s]\n", name, reg_str, rm_str);
    return pos;
   }
  }
  else
  {
   if(displacement)
   {
    printf("%s [%s + %u], %s\n", name, rm_str, displacement, reg_str);
    return pos;
   }
   else
   {
    printf("%s [%s], %s\n", name, rm_str, reg_str);
    return pos;
   }
  }
 }

 if(mod_field == 0x02)
 {
  // Example: mov al, [bx + si + 4999]

  char *rm_str = eac_table[rm_field];

  char *reg_str;
  if(word_data)
  {
   reg_str = word_registers[reg_field];
  }  
  else
  {
   reg_str = byte_registers[reg_field];
  }

  U8 disp_low = bytes[++pos];
  U8 disp_high = bytes[++pos];
  U16 displacement = (disp_high << 8) | disp_low;

  if(instruction_destination_is_in_reg_field)
  {
   if(displacement)
   {
    printf("%s %s, [%s + %u]\n", name, reg_str, rm_str, displacement);
    return pos;
   }
   else
   {
    printf("%s %s, [%s]\n", name, reg_str, rm_str);
    return pos;
   }
  }
  else
  {
   if (displacement)
   {
    printf("%s %s, [%s + %u]\n", name, rm_str, reg_str, displacement);
    return pos;
   }
   else
   {
    printf("%s %s, [%s]\n", name, rm_str, reg_str);
    return pos;
   }
  }
 }

 if(mod_field == 0x03)
 {
  // Example: mov si, bx
  // Example: mov dh, al

  char *rm_str;
  char *reg_str;
  if(word_data)
  {
   rm_str = word_registers[rm_field];
   reg_str = word_registers[reg_field];
  }  
  else
  {
   rm_str = byte_registers[rm_field];
   reg_str = byte_registers[reg_field];
  }

  if(instruction_destination_is_in_reg_field)
  {
   printf("%s %s, %s\n", name, reg_str, rm_str);
   return pos;
  }
  else
  {
   printf("%s %s, %s\n", name, rm_str, reg_str);
   return pos;
  }
 }

 printf("Error: instruction pattern found but not processed.\n");
 return MAX_INSTRUCTION_FILE_SIZE + 1;
}

USIZE common_immediate(U8 *bytes, USIZE pos)
{
 bool has_sign_extension = bytes[pos] & 0x02;
 bool word_data = bytes[pos] & 0x01;

 pos++;
 U8 mod_field = (bytes[pos] >> 6);
 U8 reg_field = (bytes[pos] & 0x38) >> 3;
 U8 rm_field = (bytes[pos] & 0x07);

 char *name;
 switch(reg_field)
 {
  case 0x00:
   name = "add";
   break;
  case 0x05:
   name = "sub";
   break;
  case 0x07:
   name = "cmp";
   break;
  default:
   printf("Error: Unknown mnemonic for %u\n", reg_field);
   return MAX_INSTRUCTION_FILE_SIZE + 1;
 }

 if(mod_field == 0x00 && rm_field == 0x06)
 {
  // cmp word [4834], 29
  U16 disp_low = bytes[++pos];
  U16 disp_high = bytes[++pos];
  U16 displacement = (disp_high << 8) | disp_low;

  U8 data = bytes[++pos];
  printf("%s [%u], %u\n", name, displacement, data); 
  return pos;
 }

 if(mod_field == 0x00)
 {
  char *rm_str = eac_table[rm_field];
  U8 data_low = bytes[++pos];
  printf("%s [%s], %u\n", name, rm_str, data_low);
  return pos;
 }

 if(mod_field == 0x01)
 {
  char *rm_str = eac_table[rm_field];

  U8 displacement = bytes[++pos];

  U16 data;
  if (word_data)
  {
   U16 data_low = bytes[++pos];
   U16 data_high = bytes[++pos];
   data = (data_high << 8) | data_low;
  }
  else
  {
   data = bytes[++pos];
  }
  
  printf("%s [%s + %u], %u\n", name, rm_str, displacement, data);
  return pos;
 }

 if(mod_field == 0x02)
 {
  char *rm_str = eac_table[rm_field];

  U16 displacement;
  if(word_data)
  {
   U16 disp_low = bytes[++pos];
   U16 disp_high = bytes[++pos];
   displacement = (disp_high << 8) | disp_low;
  }
  else
  {
   displacement = bytes[++pos];
  }
   
  U16 data;
  if(!has_sign_extension && word_data)
  {
   U16 data_low = bytes[++pos];
   U16 data_high = bytes[++pos];
   data = (data_high << 8) | data_low;
  }
  else
  {
   data = bytes[++pos];
  }
 
  printf("%s [%s + %u], %u\n", name, rm_str, displacement, data);
  return pos;
 }

 if(mod_field == 0x03)
 {
  char *rm_str;
  if (word_data)
  {
   rm_str = word_registers[rm_field];
  }
  else
  {
   rm_str = byte_registers[rm_field];
  }

  U16 data;
  if(!has_sign_extension && word_data)
  {
   U16 data_low = bytes[++pos];
   U16 data_high = bytes[++pos];
   data = (data_high << 8) | data_low;
  }
  else
  {
   data = bytes[++pos];
  }

  printf("%s %s, %u\n", name, rm_str, data);
  return pos;
 }

 printf("Error: Common immediate found but could not be processed correctly\n");
 return MAX_INSTRUCTION_FILE_SIZE + 1;
}

USIZE mov_immediate_to_reg(U8 *bytes, USIZE pos)
{
 bool word_data = bytes[pos] & 0x08; // 0b0000_1000
 U8 reg_field = bytes[pos] & 0x07; // 0b0000_0111
 
 if(word_data)
 {
  // Example: mov dx, 3948
  // Example: mov dx, -3948
  S16 data_low = bytes[++pos];
  S16 data_high = bytes[++pos];
  S16 data = (data_high << 8) | data_low;
  printf("mov %s, %d\n", word_registers[reg_field], data);
  return pos;
 }
 else
 {
  // Example: mov cl, 12
  // Example: mov ch, -12
  S8 data = bytes[++pos];
  printf("mov %s, %d\n", byte_registers[reg_field], data);
  return pos;
 }
}

USIZE immediate_accumulator(char *name, U8 *bytes, USIZE pos)
{
 bool word_data = (bytes[pos] & 0x01);
 if(word_data)
 {
  U16 data_low = bytes[++pos];
  U16 data_high = bytes[++pos];
  U16 data = (data_high << 8) | data_low;
  printf("%s ax, %u\n", name, data);
  return pos;
 }
 else
 {
  U8 data = bytes[++pos];
  printf("%s al, %u\n", name, data);
  return pos;
 }
}

USIZE read_instruction_bytes(U8 *bytes)
{
 char *filename = "instructions";
 FILE *fb = fopen(filename, "rb");
 if(!fb)
 {
  fprintf(stderr, "Error: %s: %s\n", strerror(errno), filename);
  return 0;
 }

 U8 byte;
 USIZE element_size = 1;
 USIZE nr_of_elements = 1;
 USIZE bytes_read = 0;
 while(1) 
 {
  USIZE elements_read = fread(&byte, element_size, nr_of_elements, fb);  
  if(elements_read != nr_of_elements)
  {
   break;
  }
  else
  {
   bytes[bytes_read] = byte;
   bytes_read++;
  }
 }
 
 fclose(fb);
 return bytes_read;
}

void debug_print_byte(U8 byte)
{
 S8 bit_str[9] = {0};
 for(U8 i = 0, j = 7; i < 8; i++, j--)
 {
  if((byte >> i) & 0x1)
  {
   bit_str[j] = '1';
  }
  else
  {
   bit_str[j] = '0';
  }
 }
 bit_str[8] = '\0';

 char debug_str[16];
 sprintf(debug_str, "0x%02X: %s\n", byte, bit_str);
}

