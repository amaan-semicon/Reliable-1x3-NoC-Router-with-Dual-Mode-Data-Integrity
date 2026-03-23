`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.03.2026 22:30:56
// Design Name: 
// Module Name: router_fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module router_fifo (
    input  logic       clock,
    input  logic       resetn,
    input  logic       soft_reset,  // From Synchronizer (Timeout)
    input  logic       write_enb,   // From Synchronizer
    input  logic       read_enb,    // From External Receiver
    input  logic       lfd_state,   // From FSM (Indicates Header)
    input  logic [7:0] data_in,     // Comes from Register's `dout`
    
    output logic       empty,       // Goes to Sync and FSM
    output logic       full,        // Goes to Sync
    output logic [7:0] data_out     // Final output to External Receiver
);

    // 16x9 Memory Array (8 bits data + 1 bit for header tracking)
    logic [8:0] mem [0:15];
    
    // Pointers and Counters
    logic [3:0] write_ptr, read_ptr;
    logic [4:0] count; // 5-bit to count up to 16

    // -------------------------------------------------------------------------
    // WRITE LOGIC
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            write_ptr <= 4'd0;
        end
        else if (soft_reset) begin
            write_ptr <= 4'd0;
        end
        else if (write_enb && !full) begin
            // Concatenate lfd_state as the 9th bit, data_in as lower 8 bits
            mem[write_ptr] <= {lfd_state, data_in};
            write_ptr <= write_ptr + 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // READ LOGIC
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            read_ptr <= 4'd0;
            data_out <= 8'h00;
        end
        else if (soft_reset) begin
            read_ptr <= 4'd0;
            data_out <= 8'hzz; // High impedance on soft reset
        end
        else if (read_enb && !empty) begin
            data_out <= mem[read_ptr][7:0]; // Extract only the 8-bit data
            read_ptr <= read_ptr + 1'b1;
        end
        // In some router specs, if count == 0, data_out goes to high-Z
        else if (count == 0) begin
            data_out <= 8'hzz; 
        end
    end

    // -------------------------------------------------------------------------
    // FIFO COUNTER (To manage Empty and Full flags)
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            count <= 5'd0;
        end
        else if (soft_reset) begin
            count <= 5'd0;
        end
        else begin
            case ({write_enb && !full, read_enb && !empty})
                2'b10: count <= count + 1'b1; // Only Writing
                2'b01: count <= count - 1'b1; // Only Reading
                2'b11: count <= count;        // Simultaneous Read & Write
                2'b00: count <= count;        // Neither
            endcase
        end
    end

    // Output assignments
    assign full  = (count == 5'd16);
    assign empty = (count == 5'd0);

endmodule
