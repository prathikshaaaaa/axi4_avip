`ifndef AXI4_VIRTUAL_WRITEBACK_SEQ_INCLUDED_
`define AXI4_VIRTUAL_WRITEBACK_SEQ_INCLUDED_

class axi4_virtual_writeback_seq extends axi4_virtual_base_seq;
  `uvm_object_utils(axi4_virtual_writeback_seq)

  // FIX: removed shared m_wb_seq handle — now automatic local in loop
  axi4_slave_writeback_seq   s_wb_seq    [NO_OF_SLAVES];
  axi4_slave_refill_seq      s_refill_seq[NO_OF_SLAVES]; // FIX: was s_ref_seq

  function new(string name = "axi4_virtual_writeback_seq");
    super.new(name);
  endfunction

  task body();
    `uvm_info(get_type_name(), "STARTING WRITEBACK TEST", UVM_LOW)

    fork

      // ---------------------------------------------------
      // THREAD 1: Slave background sequences
      // ---------------------------------------------------
      begin
        for (int s = 0; s < NO_OF_SLAVES; s++) begin
          automatic int slv_idx = s; // FIX: automatic to capture correct index

          s_wb_seq[s]     = axi4_slave_writeback_seq::type_id::create(
                              $sformatf("s_wb_seq[%0d]", s));
          s_refill_seq[s] = axi4_slave_refill_seq::type_id::create(
                              $sformatf("s_refill_seq[%0d]", s));
          fork
            forever s_wb_seq[slv_idx].start(
                      p_sequencer.axi4_slave_write_seqr_h[slv_idx]);
            forever s_refill_seq[slv_idx].start(
                      p_sequencer.axi4_slave_read_seqr_h[slv_idx]);
          join_none
        end
        // exits immediately, slaves run in background
      end

      // ---------------------------------------------------
      // THREAD 2: Master transactions — strictly sequential
      // T0→way0 dirty, T1→way1, T2→way2, T3→way3 (set full)
      // T4→eviction triggered
      // T0→M0, T1→M1, T2→M2, T3→M0, T4→M1
      // ---------------------------------------------------
      begin
        int master_sel[5] = '{0, 1, 2, 0, 1};

        for (int i = 0; i < 5; i++) begin
          // FIX: automatic so each iteration has its own copies
          automatic axi4_master_writeback_seq local_seq;
          automatic int local_mst = master_sel[i];
          automatic int local_i   = i;

          local_seq          = axi4_master_writeback_seq::type_id::create(
                                 $sformatf("m_wb_seq_%0d", local_i));
          local_seq.txn_addr = (local_i << 10) | 32'h1;
          local_seq.txn_num  = local_i;

          // FIX: fork-join (was join_none) — ensures each txn
          // completes before next starts so set fills in order
          fork
            local_seq.start(
              p_sequencer.axi4_master_write_seqr_h[local_mst]);
          join

          `uvm_info(get_type_name(),
            $sformatf("Done TXN[%0d] M[%0d] addr=0x%0h",
                      local_i, local_mst, local_seq.txn_addr),
            UVM_LOW)
        end
        // FIX: removed wait fork — not needed with fork-join above
      end

    join // Thread1 exits fast, Thread2 blocks till all 5 txns done

    `uvm_info(get_type_name(), "WRITEBACK TEST COMPLETE", UVM_LOW)
  endtask

endclass

`endif
 
