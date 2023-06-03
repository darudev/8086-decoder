const std = @import("std");
const print = std.debug.print;

const eac_table: [8][]const u8 = [_][]const u8{
    "bx + si",
    "bx + di",
    "bp + si",
    "bp + di",
    "si",
    "di",
    "bp",
    "bx",
};

const word_registers: [8][]const u8 = [_][]const u8{ "ax", "cx", "dx", "bx", "sp", "bp", "si", "di" };
const byte_registers: [8][]const u8 = [_][]const u8{ "al", "cl", "dl", "bl", "ah", "ch", "dh", "bh" };

// OP-codes
// Example: 100010dw >> 2 gives 0010 0010 (0x22)
const MOV_REG_MEM_TO_FROM_REG: u8 = 0b0010_0010;
const MOV_IMMEDIATE_TO_REG: u8 = 0b0000_1011;
const ADD_REG_MEM_WITH_REG_TO_EITHER: u8 = 0b0000_0000;
const SUB_REG_MEM_WITH_REG_TO_EITHER: u8 = 0b0000_1010;
const CMP_REG_MEM_WITH_REG_TO_EITHER: u8 = 0b0000_1110;
const COMMON_IMMEDIATE_REG_MEM: u8 = 0b0010_0000;
const ADD_IMMEDIATE_TO_ACCUMULATOR: u8 = 0b000_000_10;
const SUB_IMMEDIATE_TO_ACCUMULATOR: u8 = 0b000_101_10;
const CMP_IMMEDIATE_TO_ACCUMULATOR: u8 = 0b000_111_10;
const JNE: u8 = 0b0111_0101;
const JE: u8 = 0b0111_0100;
const JL: u8 = 0b0111_1100;
const JLE: u8 = 0b0111_1110;
const JB: u8 = 0b0111_0010;
const JBE: u8 = 0b0111_0110;
const JP: u8 = 0b0111_1010;
const JO: u8 = 0b0111_0000;
const JS: u8 = 0b0111_1000;
const JNL: u8 = 0b0111_1101;
const JG: u8 = 0b0111_1111;
const JNB: u8 = 0b0111_0011;
const JA: u8 = 0b0111_0111;
const JNP: u8 = 0b0111_1011;
const JNO: u8 = 0b0111_0001;
const JNS: u8 = 0b0111_1001;
const LOOP: u8 = 0b1110_0010;
const LOOPZ: u8 = 0b1110_0001;
const LOOPNZ: u8 = 0b1110_0000;
const JCXZ: u8 = 0b1110_0011;

pub fn main() !void {
    var current_dir = try std.fs.cwd().openDir(".", .{});
    defer current_dir.close();

    var file = try current_dir.openFile("instruction_list", .{});
    defer file.close();

    var input_bytes: [1024]u8 = undefined;

    const bytes_read = try file.readAll(&input_bytes);
    debugPrint(&input_bytes, bytes_read);
    print("Read {d} bytes\n\n", .{bytes_read});

    var i: usize = 0;
    while (i < bytes_read) {
        if ((input_bytes[i] >> 2) == MOV_REG_MEM_TO_FROM_REG) {
            var byte_count: usize = try commonDisplacement("mov", &input_bytes, i);
            i += byte_count;
            i += 1;
            continue;
        }

        if ((input_bytes[i] >> 2) == ADD_REG_MEM_WITH_REG_TO_EITHER) {
            var byte_count: usize = try commonDisplacement("add", &input_bytes, i);
            i += byte_count;
            i += 1;
            continue;
        }

        if ((input_bytes[i] >> 2) == SUB_REG_MEM_WITH_REG_TO_EITHER) {
            var byte_count: usize = try commonDisplacement("sub", &input_bytes, i);
            i += byte_count;
            i += 1;
            continue;
        }

        if ((input_bytes[i] >> 2) == CMP_REG_MEM_WITH_REG_TO_EITHER) {
            var byte_count: usize = try commonDisplacement("cmp", &input_bytes, i);
            i += byte_count;
            i += 1;
            continue;
        }

        if ((input_bytes[i] >> 4) == MOV_IMMEDIATE_TO_REG) {
            var word_data: bool = bitIsSet(input_bytes[i], 0b0000_1000);
            var reg_field: u8 = (input_bytes[i] & 0b0000_0111);
            if (word_data) {
                i += 1;
                var low_data: u16 = input_bytes[i];

                i += 1;
                var high_data: u16 = input_bytes[i];

                var value: u16 = low_data | (high_data << 8);
                print("mov {s}, {d}\n", .{ word_registers[reg_field], value });
            } else {
                i += 1;
                var value: u8 = input_bytes[i];
                print("mov {s}, {d}\n", .{ byte_registers[reg_field], value });
            }
            i += 1;
            continue;
        }

        if ((input_bytes[i] >> 2) == COMMON_IMMEDIATE_REG_MEM) {
            var byte_count: usize = commonImmediate(&input_bytes, i);
            i += byte_count;
            i += 1;
            continue;
        }

        if ((input_bytes[i] >> 1) == ADD_IMMEDIATE_TO_ACCUMULATOR) {
            var byte_count: usize = parseArithmeticImmediateToAccumulator("add", &input_bytes, i);
            i += byte_count;
            i += 1;
            continue;
        }

        if ((input_bytes[i] >> 1) == SUB_IMMEDIATE_TO_ACCUMULATOR) {
            var byte_count: usize = parseArithmeticImmediateToAccumulator("sub", &input_bytes, i);
            i += byte_count;
            i += 1;
            continue;
        }

        if ((input_bytes[i] >> 1) == CMP_IMMEDIATE_TO_ACCUMULATOR) {
            var byte_count: usize = parseArithmeticImmediateToAccumulator("cmp", &input_bytes, i);
            i += byte_count;
            i += 1;
            continue;
        }

        if (input_bytes[i] == JNE) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("jne {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == JE) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("je {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == JL) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("jl {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == JLE) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("jle {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == JB) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("jb {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == JBE) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("jbe {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == JP) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("jp {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == JO) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("jo {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == JS) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("js {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == JNL) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("jnl {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == JG) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("jg {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == JNB) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("jnb {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == JA) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("ja {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == JNP) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("jnp {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == JNO) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("jno {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == JNS) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("jns {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == LOOP) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("loop {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == LOOPZ) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("loopz {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == LOOPNZ) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("loopnz {d}\n", .{value});

            i += 1;
            continue;
        }

        if (input_bytes[i] == JCXZ) {
            i += 1;
            const value: i8 = @bitCast(i8, input_bytes[i]);
            print("jcxz {d}\n", .{value});

            i += 1;
            continue;
        }
    }
}

fn parseArithmeticImmediateToAccumulator(name: []const u8, input_bytes: []u8, pos: usize) usize {
    var i: usize = pos;
    var byte_count: usize = 0;

    const word_data: bool = bitIsSet(input_bytes[i], 0b0000_0001);

    if (word_data) {
        i += 1;
        byte_count += 1;
        const data_one: u16 = input_bytes[i];

        i += 1;
        byte_count += 1;
        const data_two: u16 = input_bytes[i];

        const value: u16 = data_one | (data_two << 8);

        print("{s} ax, {d}\n", .{ name, value });
        return byte_count;
    } else {
        i += 1;
        byte_count += 1;
        const value: u8 = input_bytes[i];
        print("{s} al, {d}\n", .{ name, value });
        return byte_count;
    }
}

fn commonImmediate(input_bytes: []u8, pos: usize) usize {
    var i: usize = pos;
    var byte_count: usize = 0;

    const has_sign_extension: bool = bitIsSet(input_bytes[i], 0b0000_0010);
    const word_data: bool = bitIsSet(input_bytes[i], 0b0000_0001);

    i += 1;
    byte_count += 1;
    const mod_field: u8 = (input_bytes[i] >> 6);
    const reg_field: u8 = (input_bytes[i] & 0b0011_1000) >> 3;
    const rm_field: u8 = (input_bytes[i] & 0b0000_0111);

    const name: []const u8 = switch (reg_field) {
        0b000 => "add",
        0b101 => "sub",
        0b111 => "cmp",
        else => "ERROR",
    };

    if (mod_field == 0b00 and rm_field == 0b110) {
        i += 1;
        byte_count += 1;
        const low_direct_addr: u16 = input_bytes[i];

        i += 1;
        byte_count += 1;
        const high_direct_addr: u16 = input_bytes[i];

        const direct_address: u16 = low_direct_addr | (high_direct_addr << 8);

        i += 1;
        byte_count += 1;
        const data: u8 = input_bytes[i];

        print("{s} [{d}], {d}\n", .{ name, direct_address, data });
        return byte_count;
    }

    if (mod_field == 0b00) {
        const rm_register: []const u8 = eac_table[rm_field];
        i += 1;
        byte_count += 1;
        const value: u8 = input_bytes[i];
        print("{s} [{s}], {d}\n", .{ name, rm_register, value });
        return byte_count;
    }

    if (mod_field == 0b10) {
        const rm_register: []const u8 = eac_table[rm_field];
        var disp_value: u16 = 0;
        if (word_data) {
            i += 1;
            byte_count += 1;
            const disp_low: u16 = input_bytes[i];

            i += 1;
            byte_count += 1;
            const disp_high: u16 = input_bytes[i];

            disp_value = disp_low | (disp_high << 8);
        } else {
            i += 1;
            byte_count += 1;
            disp_value = input_bytes[i];
        }

        i += 1;
        byte_count += 1;
        const data: u8 = input_bytes[i];

        print("{s} [{s} + {d}], {d}\n", .{ name, rm_register, disp_value, data });

        return byte_count;
    }

    if (mod_field == 0b11) {
        const rm_register: []const u8 = if (word_data) word_registers[rm_field] else byte_registers[rm_field];

        if (!has_sign_extension and word_data) {
            i += 1;
            byte_count += 1;
            const low_data: u16 = input_bytes[i];

            i += 1;
            byte_count += 1;
            const high_data: u16 = input_bytes[i];
            const value: u16 = low_data | (high_data << 8);

            print("{s} {s}, {d}\n", .{ name, rm_register, value });

            return byte_count;
        }

        if (has_sign_extension) {
            i += 1;
            byte_count += 1;
            const value: u8 = input_bytes[i];

            print("{s} {s}, {d}\n", .{ name, rm_register, value });

            return byte_count;
        }
    }

    return byte_count;
}

fn commonDisplacement(name: []const u8, input_bytes: []u8, pos: usize) !usize {
    var i: usize = pos;
    var byte_count: usize = 0;

    // OPCODE byte
    var reg_is_dest: bool = bitIsSet(input_bytes[i], 0b0000_0010);
    var word_data: bool = bitIsSet(input_bytes[i], 0b0000_0001);

    // [MOD REG R/M] byte
    i += 1;
    byte_count += 1;
    var mod_field: u8 = (input_bytes[i] >> 6);
    var reg_field: u8 = ((input_bytes[i] & 0b0011_1000) >> 3);
    var rm_field: u8 = (input_bytes[i] & 0b0000_0111);

    if (mod_field == 0b00 and rm_field == 0b110) {
        const reg_register: []const u8 = word_registers[reg_field];

        i += 1;
        byte_count += 1;
        const low_data: u16 = input_bytes[i];

        i += 1;
        byte_count += 1;
        const high_data: u16 = input_bytes[i];

        const direct_address: u16 = low_data | (high_data << 8);

        print("{s} {s}, [{d}]\n", .{ name, reg_register, direct_address });
        return byte_count;
    }

    if (mod_field == 0b00) {
        const reg_register: []const u8 = if (word_data) word_registers[reg_field] else byte_registers[reg_field];
        const rm_register: []const u8 = eac_table[rm_field];
        const value: u16 = 0;

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();

        const dest_src_str = try parseDestSrcDisplacement(allocator, reg_is_dest, reg_register, rm_register, value);
        defer allocator.free(dest_src_str);

        print("{s} {s}\n", .{ name, dest_src_str });
        return byte_count;
    }

    if (mod_field == 0b01) {
        const reg_register: []const u8 = if (word_data) word_registers[reg_field] else byte_registers[reg_field];
        const rm_register: []const u8 = eac_table[rm_field];

        i += 1;
        byte_count += 1;
        const value: u16 = input_bytes[i];

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();

        const dest_src_str = try parseDestSrcDisplacement(allocator, reg_is_dest, reg_register, rm_register, value);
        defer allocator.free(dest_src_str);

        print("{s} {s}\n", .{ name, dest_src_str });
        return byte_count;
    }

    if (mod_field == 0b10) {
        const reg_register: []const u8 = if (word_data) word_registers[reg_field] else byte_registers[reg_field];
        const rm_register: []const u8 = eac_table[rm_field];

        i += 1;
        byte_count += 1;
        const low_data: u16 = input_bytes[i];

        i += 1;
        byte_count += 1;
        const high_data: u16 = input_bytes[i];
        const value: u16 = low_data | (high_data << 8);

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();

        const dest_src_str = try parseDestSrcDisplacement(allocator, reg_is_dest, reg_register, rm_register, value);
        defer allocator.free(dest_src_str);

        print("{s} {s}\n", .{ name, dest_src_str });
        return byte_count;
    }

    if (mod_field == 0b11) {
        const reg_register: []const u8 = if (word_data) word_registers[reg_field] else byte_registers[reg_field];
        const rm_register: []const u8 = if (word_data) word_registers[rm_field] else byte_registers[rm_field];

        if (reg_is_dest) {
            print("{s} {s}, {s}\n", .{ name, reg_register, rm_register });
        } else {
            print("{s} {s}, {s}\n", .{ name, rm_register, reg_register });
        }
        return byte_count;
    }

    return byte_count;
}

fn parseDestSrcDisplacement(allocator: std.mem.Allocator, reg_is_dest: bool, reg_register: []const u8, rm_register: []const u8, value: u16) ![]const u8 {
    var src_buffer: [64]u8 = undefined;
    var dest_buffer: [64]u8 = undefined;

    var src: []const u8 = undefined;
    var dest: []const u8 = undefined;

    if (reg_is_dest) {
        dest = try std.fmt.bufPrint(&dest_buffer, "{s}", .{reg_register});
        if (value > 0) {
            src = try std.fmt.bufPrint(&src_buffer, "[{s} + {d}]", .{ rm_register, value });
        } else {
            src = try std.fmt.bufPrint(&src_buffer, "[{s}]", .{rm_register});
        }
    } else {
        src = try std.fmt.bufPrint(&src_buffer, "{s}", .{reg_register});
        if (value > 0) {
            dest = try std.fmt.bufPrint(&dest_buffer, "[{s} + {d}]", .{ rm_register, value });
        } else {
            dest = try std.fmt.bufPrint(&dest_buffer, "[{s}]", .{rm_register});
        }
    }

    const size = dest.len + src.len + 2;
    var result = try allocator.alloc(u8, size);
    _ = try std.fmt.bufPrint(result, "{s}, {s}", .{ dest, src });

    return result;
}

fn debugPrint(input_bytes: []u8, bytes_read: usize) void {
    var i: u32 = 0;
    while (i < bytes_read) : (i += 1) {
        print("{d:0>2}: 0x{X:0>2} - 0b{b:0>8}\n", .{ i, input_bytes[i], input_bytes[i] });
    }
}

fn bitIsSet(byte: u8, mask: u8) bool {
    if ((byte & mask) > 0) {
        return true;
    } else {
        return false;
    }
}
