

module PF_DPSRAM_SPECIAL(
    // Inputs
    A_ADDR,
    A_BLK_EN,
    A_DIN,
    A_WEN,
    B_ADDR,
    B_BLK_EN,
    B_DIN,
    B_WEN,
    CLK,
    // Outputs
    A_DOUT,
    B_DOUT
);

//--------------------------------------------------------------------
// Input
//--------------------------------------------------------------------
input  [5:0]  A_ADDR;
input         A_BLK_EN;
input  [19:0] A_DIN;
input         A_WEN;
input  [5:0]  B_ADDR;
input         B_BLK_EN;
input  [19:0] B_DIN;
input         B_WEN;
input         CLK;
//--------------------------------------------------------------------
// Output
//--------------------------------------------------------------------
output [19:0] A_DOUT;
output [19:0] B_DOUT;
//--------------------------------------------------------------------
// Nets
//--------------------------------------------------------------------
wire   [5:0]  A_ADDR;
wire          A_BLK_EN;
wire   [19:0] A_DIN;
wire   [19:0] A_DOUT_net_0;
wire          A_WEN;
wire   [5:0]  B_ADDR;
wire          B_BLK_EN;
wire   [19:0] B_DIN;
wire   [19:0] B_DOUT_net_0;
wire          B_WEN;
wire          CLK;
wire   [19:0] A_DOUT_net_1;
wire   [19:0] B_DOUT_net_1;
//--------------------------------------------------------------------
// TiedOff Nets
//--------------------------------------------------------------------
wire   [1:0]  A_WBYTE_EN_const_net_0;
wire   [1:0]  B_WBYTE_EN_const_net_0;
wire          GND_net;
//--------------------------------------------------------------------
// Constant assignments
//--------------------------------------------------------------------
assign A_WBYTE_EN_const_net_0 = 2'h0;
assign B_WBYTE_EN_const_net_0 = 2'h0;
assign GND_net                = 1'b0;
//--------------------------------------------------------------------
// Top level output port assignments
//--------------------------------------------------------------------
assign A_DOUT_net_1 = A_DOUT_net_0;
assign A_DOUT[19:0] = A_DOUT_net_1;
assign B_DOUT_net_1 = B_DOUT_net_0;
assign B_DOUT[19:0] = B_DOUT_net_1;
//--------------------------------------------------------------------
// Component instances
//--------------------------------------------------------------------
//--------PF_DPSRAM_SPECIAL_PF_DPSRAM_SPECIAL_0_PF_DPSRAM   -   Actel:SgCore:PF_DPSRAM:1.1.110


endmodule


