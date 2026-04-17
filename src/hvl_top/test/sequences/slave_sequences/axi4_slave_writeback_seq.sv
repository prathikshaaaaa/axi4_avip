
`ifndef AXI4_SLAVE_WRITEBACK_SEQ_INCLUDED_
`define  AXI4_SLAVE_WRITEBACK_SEQ_INCLUDED_

class axi4_slave_writeback_seq extends axi4_slave_bk_base_seq;
  `uvm_object_utils(axi4_slave_writeback_seq)
 
  function new(string name="axi4_slave_writeback_seq");
    super.new(name);
  endfunction
 
  task body();
    super.body();
 
    start_item(req);
 
    if(!req.randomize() with {
      // req.tx_type       == WRITE;
      // req.transfer_type == NON_OUTSTANDING_WRITE;
 
      req.awburst == WRITE_INCR;
      req.awsize  == WRITE_4_BYTES;
 
      // full cache line
      req.awlen == WORDS_PER_LINE - 1;
    }) begin
      `uvm_fatal("SLV_WB_SEQ", "Rand failed");
    end
       req.tx_type       = WRITE;
      req.transfer_type = NON_OUTSTANDING_WRITE;
    finish_item(req);
  endtask
 
endclass

`endif
