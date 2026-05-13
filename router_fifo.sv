`timescale 1ns / 1ps

module router_fifo (
    input  logic       clock,
    input  logic       resetn,
    input  logic       write_enb,
    input  logic       soft_reset,
    input  logic       read_enb,
    input  logic       lfd_state,
    input  logic [7:0] data_in,

    output logic       empty,
    output logic       full,
    output logic [7:0] data_out
);

    // 16x8 Memory Array
    logic [7:0] mem [0:15];
    
    // 5-bit pointers to distinguish between full and empty 
    // (MSB is wrap-around bit, lower 4 bits are actual address)
    logic [4:0] write_ptr, read_ptr;
    
    // Internal counter to track packet length (optional but standard for Router)
    logic [6:0] payload_count;
    logic       read_header;

    // -------------------------------------------------------------------------
    // WRITE LOGIC
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            write_ptr <= 5'b0;
        end
        else if (soft_reset) begin
            write_ptr <= 5'b0;
        end
        else if (write_enb && !full) begin
            mem[write_ptr[3:0]] <= data_in;
            write_ptr <= write_ptr + 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // READ & DATA OUT LOGIC
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            read_ptr <= 5'b0;
            data_out <= 8'h00;
        end
        else if (soft_reset) begin
            read_ptr <= 5'b0;
            data_out <= 8'bz; // High impedance when reset
        end
        else if (read_enb && !empty) begin
            data_out <= mem[read_ptr[3:0]];
            read_ptr <= read_ptr + 1'b1;
        end
        else if (payload_count == 0 && data_out != 8'bz) begin
            // Put bus to high-Z state when no data is being read
            data_out <= 8'bz; 
        end
    end

    // -------------------------------------------------------------------------
    // PAYLOAD COUNTER (To keep track of packet completion)
    // -------------------------------------------------------------------------
    always_ff @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            payload_count <= 7'd0;
            read_header   <= 1'b0;
        end 
        else if (soft_reset) begin
            payload_count <= 7'd0;
            read_header   <= 1'b0;
        end
        else if (read_enb && !empty) begin
            if (!read_header) begin
                // The first byte read is the header, extract length (bits 7:2)
                // Add 1 because we still need to read the parity byte at the end
                payload_count <= mem[read_ptr[3:0]][7:2] + 1'b1;
                read_header   <= 1'b1;
            end
            else if (payload_count != 0) begin
                payload_count <= payload_count - 1'b1;
            end
            
            if (payload_count == 7'd1) begin
                read_header <= 1'b0; // Reset for next packet
            end
        end
    end

    // -------------------------------------------------------------------------
    // FULL & EMPTY CONDITIONS
    // -------------------------------------------------------------------------
    assign empty = (write_ptr == read_ptr);
    
    // Full when lower 4 bits match, but the 5th (wrap-around) bit is different
    assign full  = (write_ptr[4] != read_ptr[4]) && (write_ptr[3:0] == read_ptr[3:0]);

endmodule