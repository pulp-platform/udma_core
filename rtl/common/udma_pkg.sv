/* 
 * Alfio Di Mauro <adimauro@iis.ee.ethz.ch>
 *
 * Copyright (C) 2018-2020 ETH Zurich, University of Bologna
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 *
 *                http://solderpad.org/licenses/SHL-0.51. 
 *
 * Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 */

 // this package holds all udma signal bitwidths and define for convenience types used into the udma_core file
package udma_pkg;

	// system related bitwidths
	localparam L2_DATA_WIDTH    = 32;
	localparam L2_ADDR_WIDTH    = 19;   //L2 addr space of 2MB
	localparam CAM_DATA_WIDTH   = 8;
	localparam APB_ADDR_WIDTH   = 12;  //APB slaves are 4KB by default
	localparam TRANS_SIZE       = 20;  //max uDMA transaction size of 1MB
	localparam L2_AWIDTH_NOAL   = L2_ADDR_WIDTH + 2;
	localparam DEST_SIZE        = 2;
	localparam STREAM_ID_WIDTH  = 4;

	//linear channel parametric types tx related
 	typedef logic [    TRANS_SIZE-1 : 0] ch_transize_t;
	typedef logic [L2_AWIDTH_NOAL-1 : 0] ch_addr_t;
	typedef logic [              31 : 0] ch_data_t;
	typedef logic [               1 : 0] ch_datasize_t;
	typedef logic [     DEST_SIZE-1 : 0] ch_dest_t;
	typedef logic [    TRANS_SIZE-1 : 0] ch_bytesleft_t;
	//linear channel parametric types rx related
	typedef logic [               1 : 0] ch_stream_t;
	typedef logic [STREAM_ID_WIDTH-1: 0] ch_streamid_t;

	//udma core types
	typedef logic [               1 : 0] ch_byterel_addr_t;

	// udma peripheral events
	typedef logic  [3:0] udma_evt_t;

	typedef struct packed {
		ch_addr_t     addr;       
		ch_datasize_t datasize;     
		ch_data_t     data;       
		logic         valid;      
	} udma_stream_req_t;

	typedef struct packed {
		logic         ready;
	}udma_stream_rsp_t;

	// cfg request
	typedef struct packed {
		logic [31:0] data;
		logic [31:0] addr;
		logic valid;
		logic rwn;
	} cfg_req_t;
	// cfg response
	typedef struct packed {
		logic ready;
		logic [31:0] data;
	} cfg_rsp_t;

	// tx channel
	// req
	typedef struct packed {
		ch_transize_t bytes_left;
		ch_addr_t curr_addr;
		ch_data_t data;
		logic en;
		logic events;
		logic gnt;
		logic pending;
		ch_stream_t stream;
		ch_streamid_t stream_id;
		logic valid;
	}udma_linch_tx_req_t;
	// rsp
	typedef struct packed {
		logic cen;
		logic clr;
		logic continuous;
		ch_datasize_t datasize;
		ch_dest_t destination;
		logic ready;
		logic req;
		ch_transize_t size;
		ch_addr_t startaddr;
	}udma_linch_tx_rsp_t;

	//  rx channel
	// req
	typedef struct packed {
		logic cen;
		logic clr;
		logic continuous;
		ch_data_t data;
		ch_datasize_t datasize; 
		ch_dest_t destination;
		logic req;
		ch_transize_t size;
		ch_addr_t startaddr;
		ch_stream_t stream;
		ch_streamid_t stream_id;
		logic valid; 
	}udma_linch_rx_req_t;
	// rsp
	typedef struct packed {
		ch_transize_t bytes_left;
		ch_addr_t curr_addr;
		logic en;
		logic events;
		logic gnt; 
		logic pending; 
		logic ready;
	}udma_linch_rx_rsp_t;
	
endpackage