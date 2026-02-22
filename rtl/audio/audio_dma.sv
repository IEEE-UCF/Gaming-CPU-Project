module audio_dma #(
  parameter int unsigned ADDR_W = 32,
  parameter int unsigned DATA_W = 32, //assumming 32 bit axi for right now 
  parameter int unsigned SIZE_W = 16,
  parameter int unsigned SAMPLE_W = 16,
  parameter int unsigned BURST_LEN = 8,
  parameter int unsigned FIFO_DEPTH = 64,
)(
  input logic clk_i, //system clock
  input logic rst_ni, //system reset 
  input logic enable_i, //enable input to begin operation 
  input logic [ADDR_W-1:0] buf_base_i, //base address of audio ring buffer in system memory  
  input logic [SIZE_W-1:0] buf_size_i, //total size of ring buffer 
  input logic [ADDR_W-1:0] rd_offset_i, //byte offset from buf_bas_i oringally named rd_ptr_i


  //AXI4 AR channel master to fabric 
  //when we are taking in data?
  output logic [1:0] arburst_o, //what type of burst we are sending; i beleive there are 3 burst types
  output logic [ADDR_W-1:0] araddr_o, //the starting address of  burst 
  output logic [7:0] arlen_o, //beats - 1
  output logic [2:0] arsize_o, //how many bytes are in each transfer
  input logic arready_i, //this is gonna be asserted when the memory is ready to receive a new burst 
  output logic arvalid_o, //this is gonna be asserted when the user (this module?) is ready to issue a new burst 
  /*When both arready and arvalid are high (reading a value of one) 
  a new burst is starting, and the memory is gonna start serving this burst */

  //AXI R channel fabric to master stuff 
  //aka when we are streaming out chunks of data
  input logic [DATA_W-1:0] rdata_i, //contains the actually data 
  input logic [1:0] rresp_i, //tells use whether the burst was succesfully or not 
  input logic rlast_i, //tells us the last piece of data 
  output logic rready_o, //when the reciever is ready to receive data, this value gets set to high 
  input logic rvalid_i,  //when a chunk of data is ready to be sent out from the memory this value we be set to high
  /*when both rready and rvalid high the chunk of data has been acknowledge and it will service the next chunk of data or finish*/

  output logic [SAMPLE_W-1:0] sample_o,
  output logic sample_valid_o, 
  input logic sample_ready_i,
  
  output logic underrun_o, 
  output logic irq_o
);

localparam int unsigned BYTES_PER_BEAT = DATA_W/8; //4
localparam int unsigned ARSIZE_VAL = $clog2(BYTES_PER_BEAT); //2 
localparam int unsigned ARLEN_VAL = BURST_LEN - 1; 
localparam int unsigned SAMPLES_PER_BEAT = DATA_W / SAMPLE_W; // = 2


always_ff @(posedge clk_i or negedge rst_ni) begin
  if (~rst_ni) begin

    
  end
end


always_ff @(posedge clk_i or negedge rst_ni) begin
  if (~rst_ni) begin

    
    


  end
end
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (~rst_ni) begin

    
    


  end
end
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (~rst_ni) begin

    
    


  end
end



endmodule