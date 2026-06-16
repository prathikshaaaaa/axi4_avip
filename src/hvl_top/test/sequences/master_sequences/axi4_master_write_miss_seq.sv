
`ifndef AXI4_MASTER_WRITE_MISS_SEQ_INCLUDED_
`define AXI4_MASTER_WRITE_MISS_SEQ_INCLUDED_

class axi4_master_write_miss_seq extends axi4_master_base_seq;
  `uvm_object_utils(axi4_master_write_miss_seq)
  logic [31:0] txn_addr;
  int          txn_num;

  function new(string name = "axi4_master_write_miss_seq");
    super.new(name);
    txn_addr=32'h0000_0001;
  endfunction

  task body();
    req = axi4_master_tx::type_id::create("req");

    start_item(req);

    // ---------------------------------------------
    // RANDOMIZATION (MATCH YOUR EXISTING STYLE)
    // ---------------------------------------------
    if (!req.randomize() with {

      // WRITE CONFIG
      req.tx_type       == WRITE;
      req.transfer_type == NON_OUTSTANDING_WRITE ; // or your env equivalent

      // BURST CONFIG
      req.awburst == WRITE_INCR;
      req.awsize  == WRITE_4_BYTES;  // 32-bit
      req.awlen   == 3;              // 4 beats
      req.awcache == READ_WRITE_ALLOCATE;
      
     req.awaddr  == txn_addr;   // ← driven by virtual sequence
    }) begin
      `uvm_fatal(get_type_name(),
        $sformatf("Randomization failed: txn_num=%0d addr=0x%0h",
                   txn_num, txn_addr))
    end

    // ---------------------------------------------
    // DATA (4 BEATS)
    // ---------------------------------------------

    foreach (req.wdata[i])
      req.wdata[i] = 32'hA000_0000 + (32'(txn_num) << 16) + 32'(i);

    // ---------------------------------------------
    // WSTRB
    // ---------------------------------------------

    foreach (req.wstrb[i]) begin
      req.wstrb[i] = 4'hF;
    end

    finish_item(req);

    // ---------------------------------------------
    // DEBUG PRINT
    // ---------------------------------------------
    `uvm_info(get_type_name(),
              $sformatf("WRITE MISS: addr=0x%0h len=%0d", req.awaddr, req.awlen),
      UVM_MEDIUM)

  endtask

endclass

`endif
