/* 
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
 *
 * Alfio Di Mauro <adimauro@iis.ee.ethz.ch>
 *
 */
interface UDMA_LIN_CH (input clk_i);

	import udma_pkg::ch_addr_t;
	import udma_pkg::ch_transize_t;
	import udma_pkg::ch_data_t;
	import udma_pkg::ch_datasize_t;
	import udma_pkg::ch_dest_t;
	import udma_pkg::ch_stream_t;
	import udma_pkg::ch_streamid_t;

	//common signals
	ch_addr_t     startaddr   ;
	ch_transize_t size        ;
	logic         continuous  ;
	logic         en          ;
	logic         clr         ;
	ch_data_t     data        ;
	logic         valid       ;
	logic         ready       ;
	ch_datasize_t datasize    ;
	ch_dest_t     destination ;
	logic         events      ;
	logic         cen         ;
	logic         pending     ;
	ch_addr_t     curr_addr   ;
	ch_transize_t bytes_left  ;
	//tx only signals
	logic         req         ;
	logic         gnt         ;
	//rx only signals
	ch_stream_t   stream      ;
	ch_streamid_t stream_id   ;

	// this is used at the udma core side
	modport rx_in (
		input  valid,    
		input  data,     // data stream  
		input  datasize, // word / half word / byte
		input  destination, 
		output ready, 
		output events, 
		output en,       // transaction enable
		output pending, 
		output curr_addr, 
		output bytes_left, 
		input  startaddr, 
		input  size, 
		input  continuous, 
		input  cen,     // peripheral enable
		input  clr,     // software reset
		input  stream, 
		input  stream_id,
		input  req,     
		output gnt
	);

	// this is used at the peripheral side |periph|(lin_ch.rx_out) ---> (lin_ch.rx_in) |udma_core|
	modport rx_out (
		output valid, 
		output data, 
		output datasize, 
		output destination, 
		input  ready, 
		input  events, 
		input  en, 
		input  pending, 
		input  curr_addr, 
		input  bytes_left, 
		output startaddr, 
		output size, 
		output continuous, 
		output cen, 
		output clr, 
		output stream, 
		output stream_id,
		output req, 
		input  gnt 
	);

	modport tx_out (

		input  req,
		output gnt,
		output valid,
		output data,
		input  ready,
		input  datasize,
		input  destination,
		output events,
		output en,
		output pending,
		output curr_addr,
		output bytes_left,
		input  startaddr,
		input  size,
		input  continuous,
		input  cen,
		input  clr,
		output stream, 
		output stream_id

	);

	modport tx_in (

		output req,
		input  gnt,
		input  valid,
		input  data,
		output ready,
		output datasize,
		output destination,
		input events,
		input  en,
		input  pending,
		input  curr_addr,
		input  bytes_left,
		output startaddr,
		output size,
		output continuous,
		output cen,
		output clr

	);

endinterface

interface UDMA_EXT_CH (input clk_i);

	import udma_pkg::ch_addr_t;
	import udma_pkg::ch_data_t;
	import udma_pkg::ch_datasize_t;
	import udma_pkg::ch_dest_t;
	import udma_pkg::ch_stream_t;
	import udma_pkg::ch_streamid_t;

	ch_addr_t     addr;       
	ch_datasize_t datasize;   
	ch_dest_t     destination;
	ch_stream_t   stream;     
	ch_streamid_t stream_id;
	logic         sot;        
	logic         eot;        
	logic         valid;      
	ch_data_t     data;       
	logic         ready;
	logic         req;
	logic         gnt;     

	modport rx_in (

		input  addr,
		input  datasize,
		input  destination,
		input  stream,
		input  stream_id,
		input  sot,
		input  eot,
		input  valid,
		input  data,
		output ready

	);

	modport rx_out (

		output addr,
		output datasize,
		output destination,
		output stream,
		output stream_id,
		output sot,
		output eot,
		output valid,
		output data,
		input  ready

	);

	modport tx_out(

		input  req,
		input  addr,
		input  datasize,
		input  destination,
		output gnt,
		output valid,
		output data,
		input  stream,
		input  stream_id,
		input  ready

	);

	modport tx_in	(

		output  req,
		output  addr,
		output  datasize,
		output  destination,
		input   gnt,
		input   valid,
		input   data,
		output  stream,
		output  stream_id,
		output  ready

	);



endinterface