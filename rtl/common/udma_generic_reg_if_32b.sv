// Copyright 2016 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Florian Glaser - glaserf@ethz.ch                           //
//                                                                            //
// Additional contributions by:                                               //
//                                                                            //
//                                                                            //
// Design Name:    ADC Register Programming Interface                         //
// Project Name:   uDMA ADC TS channel                                        //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    simple uDMA interface to sample mutlti-ch timestamps       //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

// register map
`define REG_RX_SADDR     5'b00000 //BASEADDR+0x00
`define REG_RX_SIZE      5'b00001 //BASEADDR+0x04
`define REG_RX_CFG       5'b00010 //BASEADDR+0x08

module udma_generic_reg_if_32b #(
  parameter L2_AWIDTH_NOAL  = 12,
  parameter UDMA_TRANS_SIZE = 16,
  parameter TRANS_SIZE      = 16
) (
  input  logic                       clk_i,
  input  logic                       rst_ni,
  input  logic                       test_mode_i,

  input  logic                [31:0] cfg_data_i,
  input  logic                 [4:0] cfg_addr_i,
  input  logic                       cfg_valid_i,
  input  logic                       cfg_rwn_i,
  output logic                [31:0] cfg_data_o,
  output logic                       cfg_ready_o,

  output logic  [L2_AWIDTH_NOAL-1:0] cfg_rx_startaddr_o,
  output logic [UDMA_TRANS_SIZE-1:0] cfg_rx_size_o,
  output logic                 [1:0] cfg_rx_datasize_o,
  output logic                       cfg_rx_continuous_o,
  output logic                       cfg_rx_en_o,
  output logic                       cfg_rx_clr_o,
  input  logic                       cfg_rx_en_i,
  input  logic                       cfg_rx_pending_i,
  input  logic  [L2_AWIDTH_NOAL-1:0] cfg_rx_curr_addr_i,
  input  logic [UDMA_TRANS_SIZE-1:0] cfg_rx_bytes_left_i
);

  logic [L2_AWIDTH_NOAL-1:0] r_rx_startaddr;
  logic     [TRANS_SIZE-3:0] r_rx_size;
  logic                      r_rx_continuous;
  logic                      r_rx_en;
  logic                      r_rx_clr;

  logic                [4:0] s_wr_addr;
  logic                [4:0] s_rd_addr;

  assign s_wr_addr = (cfg_valid_i & ~cfg_rwn_i) ? cfg_addr_i : 5'h0;
  assign s_rd_addr = (cfg_valid_i &  cfg_rwn_i) ? cfg_addr_i : 5'h0;

  assign cfg_rx_startaddr_o  = r_rx_startaddr;
  assign cfg_rx_datasize_o   = 2'b10;
  assign cfg_rx_continuous_o = r_rx_continuous;
  assign cfg_rx_en_o         = r_rx_en;
  assign cfg_rx_clr_o        = r_rx_clr;

  assign cfg_rx_size_o[TRANS_SIZE-1:2] = r_rx_size;
  assign cfg_rx_size_o           [1:0] = 2'b00;
  
  if (UDMA_TRANS_SIZE > TRANS_SIZE)
    assign cfg_rx_size_o[UDMA_TRANS_SIZE-1:TRANS_SIZE] = '0;

  always_ff @(posedge clk_i, negedge rst_ni)  begin
    if(~rst_ni) begin
      r_rx_startaddr  <=  'h0;
      r_rx_size       <=  'h0;
      r_rx_continuous <=  'h0;
      r_rx_en          =  'h0;
      r_rx_clr         =  'h0;
    end
    else begin
      r_rx_en          =  'h0;
      r_rx_clr         =  'h0;

      if (cfg_valid_i & ~cfg_rwn_i) begin
        case (s_wr_addr)
          `REG_RX_SADDR:
            r_rx_startaddr   <= cfg_data_i[L2_AWIDTH_NOAL-1:0];
          `REG_RX_SIZE:
            r_rx_size        <= cfg_data_i[TRANS_SIZE-1:2];
          `REG_RX_CFG: begin
            r_rx_clr          = cfg_data_i[5];
            r_rx_en           = cfg_data_i[4];
            r_rx_continuous  <= cfg_data_i[0];
          end
        endcase
      end
    end
  end

  always_comb begin
    cfg_data_o = '0;
    
    case (s_rd_addr)
      `REG_RX_SADDR:
        cfg_data_o = cfg_rx_curr_addr_i;
      `REG_RX_SIZE:
        cfg_data_o[UDMA_TRANS_SIZE-1:0] = cfg_rx_bytes_left_i;
      `REG_RX_CFG:
        cfg_data_o = {26'h0,cfg_rx_pending_i,cfg_rx_en_i,1'b0,2'b10,r_rx_continuous};
      default:
        cfg_data_o = '0;
    endcase
  end

  assign cfg_ready_o = 1'b1;

endmodule 
