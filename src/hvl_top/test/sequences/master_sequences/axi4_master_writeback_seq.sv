`ifndef AXI4_MASTER_WRITEBACK_SEQ_INCLUDED_
`define AXI4_MASTER_WRITEBACK_SEQ_INCLUDED_

class axi4_master_writeback_seq extends axi4_master_base_seq;
  `uvm_object_utils(axi4_master_writeback_seq)

  // Set by virtual sequence before start()
  logic [31:0] txn_addr;
  int          txn_num;

  function new(string name = "axi4_master_writeback_seq");
    super.new(name);
  endfunction

  task body();
    req = axi4_master_tx::type_id::create("req");
    start_item(req);

    if (!req.randomize() with {
      req.tx_type       == WRITE;
      req.transfer_type == NON_OUTSTANDING_WRITE;
      req.awburst       == WRITE_INCR;
      req.awsize        == WRITE_4_BYTES;
      req.awlen         == 3;
      req.awcache       == READ_WRITE_ALLOCATE;
      req.awaddr        == txn_addr;
    }) begin
      `uvm_fatal(get_type_name(),
        $sformatf("Randomization failed addr=0x%0h", txn_addr))
    end

    // FIX: cast to 32-bit to avoid signed int overflow
    foreach (req.wdata[beat])
      req.wdata[beat] = 32'hA000_0000 +
                        (32'(txn_num) << 16) +
                        32'(beat);

    foreach (req.wstrb[beat])
      req.wstrb[beat] = 4'hF;

    finish_item(req);

    `uvm_info(get_type_name(),
      $sformatf("TXN[%0d] addr=0x%0h data0=0x%0h [%0s]",
                txn_num, req.awaddr, req.wdata[0],
                (txn_num < 4) ? "FILL" : "EVICTION"),
      UVM_LOW)
  endtask

endclass

`endif
 
